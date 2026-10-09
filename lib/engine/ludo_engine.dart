import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Board geometry: canonical 15x15 Ludo, clockwise track starting at seat 0.
// ---------------------------------------------------------------------------
const trackCells = <List<int>>[
  [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], // 0-4
  [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6], // 5-10
  [0, 7], [0, 8], // 11-12
  [1, 8], [2, 8], [3, 8], [4, 8], [5, 8], // 13-17
  [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14], // 18-23
  [7, 14], [8, 14], // 24-25
  [8, 13], [8, 12], [8, 11], [8, 10], [8, 9], // 26-30
  [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8], // 31-36
  [14, 7], [14, 6], // 37-38
  [13, 6], [12, 6], [11, 6], [10, 6], [9, 6], // 39-43
  [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0], // 44-49
  [7, 0], [6, 0], // 50-51
];
const safeIdx = {0, 8, 13, 21, 26, 34, 39, 47};
const startIdx = [0, 13, 26, 39]; // track index where each seat enters
const homeCols = <List<List<int>>>[
  [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
  [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
  [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
  [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
];
const baseOrigins = <List<int>>[[0, 0], [0, 9], [9, 9], [9, 0]];

/// Token position in fractional cell units: Offset(col, row).
/// step: -1 base, 0..50 track, 51..55 home column, 56 done.
Offset tokenUnits(List<int> seats, List<List<int>> steps, int pi, int ti) {
  final seat = seats[pi];
  final s = steps[pi][ti];
  if (s == -1) {
    final o = baseOrigins[seat];
    return Offset(o[1] + (ti % 2 == 0 ? 1.7 : 4.3), o[0] + (ti < 2 ? 1.7 : 4.3));
  } else if (s <= 50) {
    final t = trackCells[(startIdx[seat] + s) % 52];
    return Offset(t[1] + 0.5, t[0] + 0.5);
  } else if (s <= 55) {
    final h = homeCols[seat][s - 51];
    return Offset(h[1] + 0.5, h[0] + 0.5);
  }
  return Offset(7.5 + (ti % 2 == 0 ? -0.45 : 0.45), 7.5 + (ti < 2 ? -0.45 : 0.45));
}

/// Integer board cell of a token (for tap hit-testing).
List<int> tokenCell(List<int> seats, List<List<int>> steps, int pi, int ti) {
  final seat = seats[pi];
  final s = steps[pi][ti];
  if (s == -1) {
    final o = baseOrigins[seat];
    return [o[0] + (ti < 2 ? 1 : 4), o[1] + (ti % 2 == 0 ? 1 : 4)];
  } else if (s <= 50) {
    return trackCells[(startIdx[seat] + s) % 52];
  } else if (s <= 55) {
    return homeCols[seat][s - 51];
  }
  return [7, 7];
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------
class LudoPlayer {
  final String name;
  final Color color;
  final bool isBot;
  int homeCount = 0;

  LudoPlayer({required this.name, required this.color, required this.isBot});
}

// ---------------------------------------------------------------------------
// Engine: deterministic rules, state, bot AI. UI-agnostic.
// ---------------------------------------------------------------------------
class LudoEngine extends ChangeNotifier {
  final List<LudoPlayer> players;
  late final List<int> seats;
  late List<List<int>> steps; // -1 base, 0..50 track, 51..55 home col, 56 done

  int turn = 0;
  int dice = 0; // 0 = awaiting roll
  bool rolling = false;
  List<int> movable = [];
  bool over = false;
  int? winner;
  int sixStreak = 0;
  int turnCount = 0;
  String banner = '';

  final _rand = Random();
  Timer? _botTimer;

  LudoEngine({required this.players}) {
    seats = switch (players.length) {
      2 => [0, 2],
      3 => [0, 1, 2],
      _ => [0, 1, 2, 3],
    };
    steps = List.generate(players.length, (_) => List.filled(4, -1));
    banner = 'Tap the dice, ${players[0].name}!';
  }

  int get n => players.length;
  LudoPlayer get current => players[turn];
  bool get awaitingRoll => dice == 0 && !rolling && !over;

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  /// Track square index (0..51) for a player's token step, or -1 if not on track.
  int _trackIndex(int pi, int step) {
    if (step < 0 || step > 50) return -1;
    return (startIdx[seats[pi]] + step) % 52;
  }

  /// Returns the player index owning a block on [trackIdx], or -1.
  /// A block = 2+ tokens of one player on the same track square.
  int _blockOwnerAt(int trackIdx, int forPi) {
    for (int p = 0; p < n; p++) {
      if (p == forPi) continue;
      int count = 0;
      for (int k = 0; k < 4; k++) {
        if (_trackIndex(p, steps[p][k]) == trackIdx) count++;
      }
      if (count >= 2) return p;
    }
    return -1;
  }

  bool canMove(int pi, int ti) {
    if (dice == 0 || over) return false;
    final s = steps[pi][ti];
    if (s == -1) {
      if (dice != 6) return false;
      final idx = _trackIndex(pi, 0);
      return _blockOwnerAt(idx, pi) == -1;
    }
    if (s + dice > 56) return false; // exact roll required
    final dest = s + dice;
    if (dest <= 50) {
      for (int step = s + 1; step <= dest; step++) {
        if (_blockOwnerAt(_trackIndex(pi, step), pi) != -1) return false;
      }
    }
    return true;
  }

  List<int> _movableTokens() {
    final out = <int>[];
    for (int k = 0; k < 4; k++) {
      if (canMove(turn, k)) out.add(k);
    }
    return out;
  }

  // ------------------------------------------------------------- turn flow
  void roll() {
    if (!awaitingRoll || current.isBot) return;
    _doRoll();
  }

  void _doRoll() {
    rolling = true;
    dice = 0;
    notifyListeners();
  }

  /// Called by the UI's dice animation when the final value is chosen.
  void settleRoll(int value) {
    if (over) return;
    rolling = false;
    dice = value;
    if (dice == 6) {
      sixStreak++;
      if (sixStreak >= 3) {
        // RULES.md §7: three consecutive sixes forfeits the turn.
        banner = 'Three sixes! Turn forfeited.';
        dice = 0;
        movable = [];
        notifyListeners();
        onEvent?.call(LudoEvent.turnForfeited);
        Future.delayed(const Duration(milliseconds: 1200), _nextTurn);
        return;
      }
    } else {
      sixStreak = 0;
    }
    movable = _movableTokens();
    if (movable.isEmpty) {
      banner = 'No moves possible.';
      notifyListeners();
      onEvent?.call(LudoEvent.noMoves);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!over) _nextTurn();
      });
      return;
    }
    if (current.isBot) {
      banner = '${current.name} is thinking…';
      notifyListeners();
      _botTimer?.cancel();
      _botTimer = Timer(const Duration(milliseconds: 600), () {
        if (over || dice == 0) return;
        moveToken(_botPick(movable));
      });
    } else {
      banner = movable.length == 1 ? 'Only one move!' : 'Tap a glowing token!';
      notifyListeners();
      if (movable.length == 1) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!over && dice != 0 && movable.isNotEmpty) {
            moveToken(movable.first);
          }
        });
      }
    }
  }

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(LudoEvent event)? onEvent;

  void moveToken(int ti) {
    if (over || dice == 0 || !movable.contains(ti)) {
      onEvent?.call(LudoEvent.invalid);
      return;
    }
    final pi = turn;
    final was6 = dice == 6;
    final from = steps[pi][ti];
    final dest = from == -1 ? 0 : from + dice;

    bool captured = false;
    if (dest <= 50) {
      final idx = _trackIndex(pi, dest);
      if (!safeIdx.contains(idx)) {
        for (int p = 0; p < n; p++) {
          if (p == pi) continue;
          for (int k = 0; k < 4; k++) {
            if (_trackIndex(p, steps[p][k]) == idx) {
              steps[p][k] = -1; // captured back to base
              captured = true;
            }
          }
        }
      }
    }
    final homed = dest == 56;
    steps[pi][ti] = dest;
    dice = 0;
    movable = [];
    players[pi].homeCount = steps[pi].where((s) => s == 56).length;

    if (captured) {
      banner = 'Capture! ${players[pi].name} sends a rival home!';
      onEvent?.call(LudoEvent.capture);
    } else if (homed) {
      banner = 'Token home! Roll again!';
      onEvent?.call(LudoEvent.tokenHome);
    } else if (was6) {
      banner = 'Six! Roll again!';
      onEvent?.call(LudoEvent.move);
    } else {
      onEvent?.call(LudoEvent.move);
    }
    notifyListeners();

    if (steps[pi].every((s) => s == 56)) {
      _finish(pi);
      return;
    }
    if (was6 || captured || homed) {
      _botCheck(); // same player rolls again
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (over) return;
    turn = (turn + 1) % n;
    sixStreak = 0;
    turnCount++;
    banner = '${players[turn].name}, tap the dice!';
    notifyListeners();
    _botCheck();
  }

  void _botCheck() {
    if (over || !current.isBot) return;
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 700), () {
      if (over || !current.isBot || !awaitingRoll) return;
      _doRoll();
      onEvent?.call(LudoEvent.botRolling);
    });
  }

  /// Call after the UI finishes the bot's dice animation.
  void botSettle(int value) => settleRoll(value);

  void _finish(int pi) {
    over = true;
    winner = pi;
    banner = '${players[pi].name} wins!';
    notifyListeners();
    onEvent?.call(
        players[pi].isBot ? LudoEvent.botWon : LudoEvent.humanWon);
  }

  void restart() {
    _botTimer?.cancel();
    steps = List.generate(n, (_) => List.filled(4, -1));
    for (final p in players) {
      p.homeCount = 0;
    }
    turn = 0;
    dice = 0;
    rolling = false;
    movable = [];
    over = false;
    winner = null;
    sixStreak = 0;
    turnCount = 0;
    banner = 'Tap the dice, ${players[0].name}!';
    notifyListeners();
    _botCheck();
  }

  // ---------------------------------------------------------------- bot AI
  /// Heuristic per RULES.md §11 priority order.
  int _scoreMove(int pi, int ti) {
    final s = steps[pi][ti];
    final dest = s == -1 ? 0 : s + dice;
    int score = 0;
    // 1. Finish a token.
    if (dest == 56) score += 1000;
    if (dest <= 50) {
      final idx = _trackIndex(pi, dest);
      if (!safeIdx.contains(idx)) {
        // 2. Capture, preferring victims closest to home.
        for (int p = 0; p < n; p++) {
          if (p == pi) continue;
          for (int k = 0; k < 4; k++) {
            final os = steps[p][k];
            if (os >= 0 && os <= 50 && _trackIndex(p, os) == idx) {
              score += 500 + os;
            }
          }
        }
        // 6. Danger: landing on an unsafe square within 6 ahead of a rival.
        for (int p = 0; p < n; p++) {
          if (p == pi) continue;
          for (int k = 0; k < 4; k++) {
            final os = steps[p][k];
            if (os < 0 || os > 50) continue;
            final oIdx = _trackIndex(p, os);
            final behind = (idx - oIdx) % 52;
            if (behind >= 1 && behind <= 6) score -= 90;
          }
        }
      } else {
        // 3. Safe square.
        score += 120;
      }
    }
    // 4. Leave base.
    if (s == -1) score += 200;
    // 5. Progress: token closest to home.
    score += dest;
    return score;
  }

  int _botPick(List<int> options) {
    final ranked = [...options]
      ..sort((a, b) => _scoreMove(turn, b).compareTo(_scoreMove(turn, a)));
    if (ranked.length > 1 && _rand.nextDouble() < 0.12) return ranked[1];
    return ranked.first;
  }
}

enum LudoEvent {
  move,
  capture,
  tokenHome,
  invalid,
  noMoves,
  turnForfeited,
  botRolling,
  humanWon,
  botWon,
}
