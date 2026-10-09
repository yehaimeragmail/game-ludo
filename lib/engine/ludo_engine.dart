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

/// Fractional token position for move animations: [step] may be fractional.
/// -1 = base well, 0..50 track, 51..55 home column, 56 = home triangle.
Offset tokenUnitsAt(List<int> seats, int pi, int ti, double step) {
  final seat = seats[pi];
  if (step < 0) {
    final o = baseOrigins[seat];
    return Offset(o[1] + (ti % 2 == 0 ? 1.7 : 4.3), o[0] + (ti < 2 ? 1.7 : 4.3));
  }
  Offset wp(int s) {
    if (s <= 50) {
      final t = trackCells[(startIdx[seat] + s) % 52];
      return Offset(t[1] + 0.5, t[0] + 0.5);
    } else if (s <= 55) {
      final h = homeCols[seat][s - 51];
      return Offset(h[1] + 0.5, h[0] + 0.5);
    }
    return Offset(
        7.5 + (ti % 2 == 0 ? -0.45 : 0.45), 7.5 + (ti < 2 ? -0.45 : 0.45));
  }

  final i = step.floor().clamp(0, 56);
  final f = (step - step.floor()).clamp(0.0, 1.0);
  if (f == 0 || i >= 56) return wp(i);
  final a = wp(i);
  final b = wp(i + 1);
  return Offset(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
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
// Player / difficulty
// ---------------------------------------------------------------------------
class LudoPlayer {
  String name;
  final Color color;
  final bool isBot;
  int homeCount = 0;

  LudoPlayer({required this.name, required this.color, required this.isBot});
}

/// 0 = easy, 1 = medium, 2 = hard (RULES.md §11).
enum BotDifficulty { easy, medium, hard }

/// Turn phases owned entirely by the engine. The UI only renders.
/// [settling] = turn is ending (no moves / forfeit): input locked, the turn
/// will pass shortly. This is what makes tap-to-reroll impossible.
enum Phase { awaitingRoll, rolling, awaitingMove, animating, settling, over }

/// A token move in flight (visual). The logical move is applied at once;
/// the UI interpolates the token from [fromStep] to [toStep].
class MoveAnim {
  final int pi;
  final int ti;
  final int fromStep;
  final int toStep;
  final int totalMs;
  final DateTime startedAt = DateTime.now();

  MoveAnim({
    required this.pi,
    required this.ti,
    required this.fromStep,
    required this.toStep,
    required this.totalMs,
  });

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }

  /// Interpolated step (fractional) for the UI to render.
  ///
  /// Square-by-square WALK: the piece hops onto each intermediate square in
  /// turn (150–200ms per square) with an ease-out landing, so the user SEES
  /// every step instead of one smooth glide.
  double get currentStep {
    final p = progress;
    if (fromStep < 0) return toStep.toDouble(); // base exit: pop, no slide
    final total = (toStep - fromStep).abs();
    if (total == 0) return toStep.toDouble();
    final exact = (p * total).clamp(0.0, total.toDouble());
    final idx = exact.floor().clamp(0, total - 1);
    final frac = (exact - idx).clamp(0.0, 1.0);
    // Per-square hop: fast lift, crisp ease-out landing on each square.
    final eased = 1 - (1 - frac) * (1 - frac);
    final dir = toStep >= fromStep ? 1 : -1;
    return fromStep + dir * (idx + eased);
  }

  /// Fractional progress WITHIN the current square (0..1), for the UI's
  /// per-square hop arc.
  double get squareFrac {
    if (fromStep < 0) return 0.0;
    final total = (toStep - fromStep).abs();
    if (total == 0) return 0.0;
    final exact = (progress * total).clamp(0.0, total.toDouble());
    final idx = exact.floor().clamp(0, total - 1);
    return (exact - idx).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Engine: deterministic rules, state, bot AI. UI-agnostic.
// ---------------------------------------------------------------------------
class LudoEngine extends ChangeNotifier {
  final List<LudoPlayer> players;
  final BotDifficulty botDifficulty;
  late final List<int> seats;
  late List<List<int>> steps; // -1 base, 0..50 track, 51..55 home col, 56 done

  int turn = 0;
  int dice = 0; // 0 = not rolled / consumed
  Phase phase = Phase.awaitingRoll;
  List<int> movable = [];
  MoveAnim? moveAnim;
  bool over = false;
  int? winner;
  int sixStreak = 0;
  int turnCount = 0;
  String banner = '';
  int lastRollBy = -1; // player index whose dice is showing the value

  /// Strict one-roll-per-turn enforcement (RULES.md §3): a roll is GRANTED
  /// when entering awaitingRoll and CONSUMED by _beginRoll. Any extra tap
  /// while a roll is consumed (or while settling) is ignored — tap-to-reroll
  /// is impossible by construction.
  bool _rollConsumed = false;

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  static const rollDurationMs = 1100;
  static const perStepMs = 170;

  /// Test hook: when set, the next roll settles to this value instead of
  /// a random one. Consumed after one use.
  @visibleForTesting
  int? forcedRoll;

  LudoEngine({required this.players, this.botDifficulty = BotDifficulty.medium}) {
    seats = switch (players.length) {
      2 => [0, 2], // RULES §12: opposite corners
      3 => [0, 1, 2],
      _ => [0, 1, 2, 3],
    };
    steps = List.generate(players.length, (_) => List.filled(4, -1));
    banner = 'Tap the dice, ${players[0].name}!';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    // If the first player is a bot, kick off their turn.
    _afterPhase();
  }

  int get n => players.length;
  LudoPlayer get current => players[turn];
  bool get rolling => phase == Phase.rolling;
  bool get awaitingRoll => phase == Phase.awaitingRoll && !over;
  bool get awaitingHumanMove =>
      phase == Phase.awaitingMove && !current.isBot && !over;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// This makes stuck states impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    if (phase == Phase.rolling) {
      _settleRoll(); // rolling with no timer: settle immediately
    } else if (phase == Phase.awaitingRoll && current.isBot) {
      _botRoll();
    } else if (phase == Phase.awaitingMove &&
        current.isBot &&
        movable.isNotEmpty) {
      _botMove();
    } else if (phase == Phase.animating && moveAnim != null) {
      // Resume the interrupted move animation with remaining time.
      final anim = moveAnim!;
      final elapsed =
          DateTime.now().difference(anim.startedAt).inMilliseconds;
      final remain = (anim.totalMs - elapsed).clamp(50, anim.totalMs);
      _arm(Duration(milliseconds: remain), _afterMoveAnim);
    } else if (phase == Phase.animating && moveAnim == null) {
      _afterMoveAnim();
    } else if (phase == Phase.settling) {
      // Settling with no timer (e.g. after backgrounding): pass the turn.
      _nextTurn();
    }
  }

  /// Track square index (0..51) for a player's token step, or -1 if not on track.
  int _trackIndex(int pi, int step) {
    if (step < 0 || step > 50) return -1;
    return (startIdx[seats[pi]] + step) % 52;
  }

  /// Returns the player index owning a block on [trackIdx], or -1.
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
    if (s + dice > 56) return false; // exact roll required (RULES §4)
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
  /// Human taps their dice. Strict: exactly one roll per grant.
  void roll() {
    if (!awaitingRoll || current.isBot || _rollConsumed) return;
    _beginRoll();
  }

  void _botRoll() {
    if (!awaitingRoll || !current.isBot || over || _rollConsumed) return;
    _beginRoll();
  }

  void _beginRoll() {
    if (_rollConsumed) return; // belt-and-suspenders: never double-roll
    _rollConsumed = true;
    phase = Phase.rolling;
    dice = 0;
    movable = [];
    lastRollBy = turn;
    onEvent?.call(LudoEvent.diceRolling);
    notifyListeners();
    _arm(const Duration(milliseconds: rollDurationMs), _settleRoll);
  }

  /// Grant the current player a fresh roll (turn start or earned extra roll).
  void _grantRoll() {
    _rollConsumed = false;
    phase = Phase.awaitingRoll;
    notifyListeners();
    _afterPhase();
  }

  /// Engine-owned settle — the UI never calls this. No desync possible.
  void _settleRoll() {
    if (over || phase != Phase.rolling) return;
    phase = Phase.awaitingMove;
    dice = forcedRoll ?? (1 + _rand.nextInt(6));
    forcedRoll = null;
    if (dice == 6) {
      sixStreak++;
      if (sixStreak >= 3) {
        // RULES.md §7: three consecutive sixes forfeits the turn.
        banner = 'Three sixes! Turn forfeited.';
        dice = 0;
        movable = [];
        // settling (NOT awaitingRoll): input locked, no tap-to-reroll.
        phase = Phase.settling;
        notifyListeners();
        onEvent?.call(LudoEvent.turnForfeited);
        _arm(const Duration(milliseconds: 1200), _nextTurn);
        return;
      }
    } else {
      sixStreak = 0;
    }
    movable = _movableTokens();
    if (movable.isEmpty) {
      // RULES §12: no legal moves → turn passes automatically.
      // settling (NOT awaitingRoll): input locked during the pause.
      banner = 'No moves possible.';
      phase = Phase.settling;
      notifyListeners();
      onEvent?.call(LudoEvent.noMoves);
      _arm(const Duration(milliseconds: 1100), _nextTurn);
      return;
    }
    if (current.isBot) {
      banner = '${current.name} is thinking…';
      notifyListeners();
      _arm(const Duration(milliseconds: 850), _botMove);
    } else {
      banner =
          movable.length == 1 ? 'Only one move — go!' : 'Tap a glowing token!';
      notifyListeners();
      if (movable.length == 1) {
        // Convenience auto-move; tapping first cancels it via moveToken guard.
        _arm(const Duration(milliseconds: 700), () {
          if (phase == Phase.awaitingMove &&
              !current.isBot &&
              movable.isNotEmpty) {
            moveToken(movable.first);
          }
        });
      }
    }
  }

  void _botMove() {
    if (over || phase != Phase.awaitingMove || !current.isBot) return;
    if (movable.isEmpty) {
      _nextTurn();
      return;
    }
    _botMoving = true;
    try {
      moveToken(_botPick(movable));
    } finally {
      _botMoving = false;
    }
  }

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(LudoEvent event)? onEvent;

  /// Token tap (human) or bot move. Guarded: correct phase, movable token,
  /// and bots may only move through [_botMove].
  void moveToken(int ti) {
    final botOk = !current.isBot || _botMoving;
    if (over || phase != Phase.awaitingMove || !botOk || !movable.contains(ti)) {
      onEvent?.call(LudoEvent.invalid);
      return;
    }
    _applyMove(ti);
  }

  bool _botMoving = false;

  void _applyMove(int ti) {
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
              steps[p][k] = -1; // captured back to base (RULES §6)
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
    // RULES §3: extra roll on 6, capture, or bringing a token home.
    _lastWasExtra = was6 || captured || homed;

    // Visible step-by-step animation state for the UI.
    final stepCount = from < 0 ? 1 : (dest - from).clamp(1, 12);
    moveAnim = MoveAnim(
      pi: pi,
      ti: ti,
      fromStep: from,
      toStep: dest,
      totalMs: (stepCount * perStepMs + 250).clamp(400, 1800),
    );
    phase = Phase.animating;

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
    _arm(Duration(milliseconds: moveAnim!.totalMs), _afterMoveAnim);
  }

  // Stashed across the animation so _afterMoveAnim knows the context.
  bool _lastWasExtra = false;

  void _afterMoveAnim() {
    if (over) return;
    moveAnim = null;
    final pi = turn;
    if (steps[pi].every((s) => s == 56)) {
      _finish(pi);
      return;
    }
    if (_lastWasExtra) {
      // Extra roll (6 / capture / token home): same player rolls again.
      // Exactly ONE bonus roll is granted here — never more.
      banner = '${players[turn].name}, roll again!';
      _grantRoll();
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (over) return;
    turn = (turn + 1) % n;
    sixStreak = 0;
    turnCount++;
    banner = current.isBot
        ? '${current.name} is up…'
        : '${current.name}, tap the dice!';
    // Fresh turn = fresh single roll grant.
    _grantRoll();
  }

  /// Called whenever we enter awaitingRoll: bots roll themselves.
  void _afterPhase() {
    if (over || phase != Phase.awaitingRoll) return;
    if (current.isBot) {
      _arm(const Duration(milliseconds: 750), _botRoll);
    }
  }

  void _finish(int pi) {
    over = true;
    phase = Phase.over;
    winner = pi;
    moveAnim = null;
    banner = '${players[pi].name} wins!';
    notifyListeners();
    onEvent?.call(players[pi].isBot ? LudoEvent.botWon : LudoEvent.humanWon);
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    steps = List.generate(n, (_) => List.filled(4, -1));
    for (final p in players) {
      p.homeCount = 0;
    }
    turn = 0;
    dice = 0;
    phase = Phase.awaitingRoll;
    movable = [];
    moveAnim = null;
    over = false;
    winner = null;
    sixStreak = 0;
    turnCount = 0;
    lastRollBy = -1;
    _lastWasExtra = false;
    _botMoving = false;
    _rollConsumed = false; // fresh grant for the opening roll
    banner = current.isBot ? '${current.name} is up…' : 'Tap the dice, ${players[0].name}!';
    notifyListeners();
    _afterPhase();
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
        // 6. Danger: landing unsafe within 6 ahead of a rival.
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

  /// RULES.md §11 difficulty scaling.
  int _botPick(List<int> options) {
    switch (botDifficulty) {
      case BotDifficulty.easy:
        // Easy: fully random — playful, beatable.
        return options[_rand.nextInt(options.length)];
      case BotDifficulty.medium:
        // Medium: best move with 25% noise.
        final ranked = [...options]
          ..sort((a, b) => _scoreMove(turn, b).compareTo(_scoreMove(turn, a)));
        if (ranked.length > 1 && _rand.nextDouble() < 0.25) {
          return ranked[1 + _rand.nextInt(ranked.length - 1)];
        }
        return ranked.first;
      case BotDifficulty.hard:
        // Hard: best move, deterministic.
        final ranked = [...options]
          ..sort((a, b) => _scoreMove(turn, b).compareTo(_scoreMove(turn, a)));
        return ranked.first;
    }
  }
}

enum LudoEvent {
  diceRolling,
  move,
  capture,
  tokenHome,
  invalid,
  noMoves,
  turnForfeited,
  humanWon,
  botWon,
}
