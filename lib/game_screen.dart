import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Ludo — the classic race: roll, capture, and bring all 4 tokens home.
/// 2-4 players pass-and-play, plus bots that love a good capture.
class LudoScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const LudoScreen({super.key, required this.players, required this.callbacks});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

// ---------------------------------------------------------------------------
// Board geometry: canonical 15x15 Ludo, clockwise track starting at seat 0.
// ---------------------------------------------------------------------------
const _track = <List<int>>[
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
const _safeIdx = {0, 8, 13, 21, 26, 34, 39, 47};
const _startIdx = [0, 13, 26, 39]; // track index where each seat enters
const _homeCols = <List<List<int>>>[
  [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
  [[1, 7], [2, 7], [3, 7], [4, 7], [5, 7]],
  [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
  [[13, 7], [12, 7], [11, 7], [10, 7], [9, 7]],
];
const _baseOrigins = <List<int>>[[0, 0], [0, 9], [9, 9], [9, 0]];
const _diceFaces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];

/// Token position in fractional cell units: Offset(col, row).
Offset _tokenUnits(List<int> seats, List<List<int>> steps, int pi, int ti) {
  final seat = seats[pi];
  final s = steps[pi][ti];
  if (s == -1) {
    final o = _baseOrigins[seat];
    return Offset(o[1] + (ti % 2 == 0 ? 1.7 : 4.3), o[0] + (ti < 2 ? 1.7 : 4.3));
  } else if (s <= 50) {
    final t = _track[(_startIdx[seat] + s) % 52];
    return Offset(t[1] + 0.5, t[0] + 0.5);
  } else if (s <= 55) {
    final h = _homeCols[seat][s - 51];
    return Offset(h[1] + 0.5, h[0] + 0.5);
  }
  return Offset(7.5 + (ti % 2 == 0 ? -0.45 : 0.45), 7.5 + (ti < 2 ? -0.45 : 0.45));
}

/// Integer board cell of a token (for tap hit-testing).
List<int> _tokenCell(List<int> seats, List<List<int>> steps, int pi, int ti) {
  final seat = seats[pi];
  final s = steps[pi][ti];
  if (s == -1) {
    final o = _baseOrigins[seat];
    return [o[0] + (ti < 2 ? 1 : 4), o[1] + (ti % 2 == 0 ? 1 : 4)];
  } else if (s <= 50) {
    return _track[(_startIdx[seat] + s) % 52];
  } else if (s <= 55) {
    return _homeCols[seat][s - 51];
  }
  return [7, 7];
}

/// WORKAROUND (core bug): shell solo setup yields a single bot seat instead of
/// human+bot. Synthesize the missing bot locally so solo mode stays playable.
List<Player> _effectivePlayers(List<Player> src) {
  if (src.length > 1) return src;
  final h = src.first;
  return [
    Player(name: h.name, color: h.color, emoji: h.emoji, isBot: false),
    PlayerPresets.make(1, isBot: true),
  ];
}

class _LudoScreenState extends State<LudoScreen> with SingleTickerProviderStateMixin {
  late final List<Player> _ps;
  late final List<int> _seats;
  late List<List<int>> _steps; // -1 base, 0..50 track, 51..55 home col, 56 done
  int _turn = 0;
  int _dice = 0; // 0 = awaiting roll
  bool _rolling = false;
  List<int> _movable = [];
  String _banner = ' • tap the dice to roll! 🎲';
  bool _over = false;
  Timer? _diceTimer;
  late final AnimationController _pulse;
  final _rand = Random();

  int get _n => _ps.length;
  Player get _me => _ps[_turn];
  bool get _solo => _ps.length != widget.players.length;

  @override
  void initState() {
    super.initState();
    _ps = _effectivePlayers(widget.players);
    _seats = switch (_n) {
      2 => [0, 2],
      3 => [0, 1, 2],
      _ => [0, 1, 2, 3],
    };
    _steps = List.generate(_n, (_) => List.filled(4, -1));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    widget.callbacks.setActivePlayer(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _diceTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- turn logic
  void _maybeBot() {
    if (_over || !_me.isBot) return;
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _over || _rolling || _dice != 0 || !_me.isBot) return;
      _roll();
    });
  }

  void _roll() {
    if (_over || _rolling || _dice != 0) return;
    setState(() => _rolling = true);
    Sfx.click();
    int ticks = 0;
    _diceTimer?.cancel();
    _diceTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      ticks++;
      setState(() => _dice = _rand.nextInt(6) + 1);
      if (ticks >= 9) {
        t.cancel();
        setState(() => _rolling = false);
        _afterRoll();
      }
    });
  }

  List<int> _movableTokens() {
    final out = <int>[];
    for (int k = 0; k < 4; k++) {
      final s = _steps[_turn][k];
      if (s == -1) {
        if (_dice == 6) out.add(k);
      } else if (s + _dice <= 56) {
        out.add(k);
      }
    }
    return out;
  }

  void _afterRoll() {
    if (_over) return;
    _movable = _movableTokens();
    if (_movable.isEmpty) {
      setState(() => _banner = ' • no moves possible — ouch! 😅');
      Sfx.tap();
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted || _over) return;
        _nextTurn();
      });
      return;
    }
    if (_me.isBot) {
      setState(() => _banner = ' • ${_me.name} is plotting… 😈');
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted || _over || _dice == 0) return;
        _moveToken(_turn, _botPick(_movable));
      });
    } else {
      setState(() => _banner = _movable.length == 1
          ? ' • only one move — sending it! 🚀'
          : ' • tap a glowing token! ✨');
      if (_movable.length == 1) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted || _over || _dice == 0 || _movable.isEmpty) return;
          _moveToken(_turn, _movable.first);
        });
      }
    }
  }

  /// Bot brain: captures first, then leaving base, safe squares, then progress.
  int _botPick(List<int> options) {
    int scoreOf(int ti) {
      final s = _steps[_turn][ti];
      final dest = s == -1 ? 0 : s + _dice;
      int sc = dest;
      if (dest <= 50) {
        final idx = (_startIdx[_seats[_turn]] + dest) % 52;
        if (!_safeIdx.contains(idx)) {
          for (int p = 0; p < _n; p++) {
            if (p == _turn) continue;
            for (int k = 0; k < 4; k++) {
              final os = _steps[p][k];
              if (os >= 0 &&
                  os <= 50 &&
                  (_startIdx[_seats[p]] + os) % 52 == idx) {
                sc += 60;
              }
            }
          }
        } else {
          sc += 15;
        }
      }
      if (s == -1) sc += 25;
      if (dest == 56) sc += 40;
      return sc;
    }

    final ranked = [...options]..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    // tiny bit of chaos so it doesn't feel robotic
    if (ranked.length > 1 && _rand.nextDouble() < 0.12) return ranked[1];
    return ranked.first;
  }

  void _moveToken(int pi, int ti) {
    if (_over) return;
    final was6 = _dice == 6;
    final seat = _seats[pi];
    final from = _steps[pi][ti];
    final dest = from == -1 ? 0 : from + _dice;
    bool captured = false;
    if (dest <= 50) {
      final idx = (_startIdx[seat] + dest) % 52;
      if (!_safeIdx.contains(idx)) {
        for (int p = 0; p < _n; p++) {
          if (p == pi) continue;
          for (int k = 0; k < 4; k++) {
            final os = _steps[p][k];
            if (os >= 0 && os <= 50 && (_startIdx[_seats[p]] + os) % 52 == idx) {
              _steps[p][k] = -1;
              captured = true;
            }
          }
        }
      }
    }
    final homed = dest == 56;
    setState(() {
      _steps[pi][ti] = dest;
      _dice = 0;
      _movable = [];
      if (captured) {
        _banner = ' • 💥 CAPTURE! ${_ps[pi].name} sends a rival home!';
        Sfx.click();
      } else if (homed) {
        _banner = ' • 🏠 token home! Roll again, champ!';
      } else if (was6) {
        _banner = ' • 🎲 SIX! Roll again!';
      }
    });
    Sfx.move();
    _syncScores();
    if (_steps[pi].every((s) => s == 56)) {
      _finish(pi);
      return;
    }
    if (was6 || captured || homed) {
      _maybeBot(); // same player goes again
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (_over) return;
    setState(() {
      _turn = (_turn + 1) % _n;
      _banner = ' • tap the dice, ${_ps[_turn].name}! 🎲';
    });
    widget.callbacks.setActivePlayer(min(_turn, widget.players.length - 1));
    _maybeBot();
  }

  void _syncScores() {
    for (int i = 0; i < _n; i++) {
      final done = _steps[i].where((s) => s == 56).length;
      _ps[i].score = done;
      if (i < widget.players.length) widget.players[i].score = done;
    }
    widget.callbacks.refreshHud();
  }

  void _finish(int pi) {
    if (_over) return;
    _over = true;
    _diceTimer?.cancel();
    final w = _ps[pi];
    widget.callbacks.finish(
      winner: w,
      headline: '🏆 ${w.name} wins Ludo!',
      subline: 'All 4 tokens raced home. Certified board royalty! 👑',
    );
  }

  void _onBoardTap(Offset local, double size) {
    if (_over || _rolling || _dice == 0 || _me.isBot || _movable.isEmpty) return;
    final cell = size / 15;
    final r = (local.dy / cell).floor();
    final c = (local.dx / cell).floor();
    for (final ti in _movable) {
      final pos = _tokenCell(_seats, _steps, _turn, ti);
      if (pos[0] == r && pos[1] == c) {
        Sfx.tap();
        _moveToken(_turn, ti);
        return;
      }
    }
  }

  String get _diceHint {
    if (_over) return '';
    if (_me.isBot) return '${_me.name} is on the move…';
    if (_rolling) return 'Rolling… 🌀';
    if (_dice == 0) return 'Your turn — tap the dice!';
    if (_movable.isEmpty) return '';
    return 'Tap a glowing token ✨';
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final canRoll = _dice == 0 && !_rolling && !_over && !_me.isBot;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            const SizedBox(height: 4),
            TurnBanner(player: _me, action: _banner),
            if (_solo) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _n; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${_ps[i].emoji} ${_steps[i].where((s) => s == 56).length}/4 🏠',
                        style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1,
              child: Builder(
                builder: (bctx) => GestureDetector(
                  onTapDown: (d) {
                    final box = bctx.findRenderObject()! as RenderBox;
                    _onBoardTap(d.localPosition, box.size.width);
                  },
                  child: CustomPaint(
                    painter: _LudoBoardPainter(
                      ps: _ps,
                      seats: _seats,
                      steps: _steps,
                      movableKeys: {for (final ti in _movable) '$_turn-$ti'},
                      theme: t,
                      pulse: _pulse,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: canRoll ? _roll : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: t.radius,
                      border: Border.all(
                        color: canRoll ? t.primary : t.muted.withValues(alpha: 0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.primary.withValues(alpha: canRoll ? 0.35 : 0.1),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dice == 0 ? '🎲' : _diceFaces[_dice - 1],
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _diceHint,
                    style: TextStyle(color: t.muted, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Board painter
// ---------------------------------------------------------------------------
void _drawText(Canvas canvas, String text, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

class _LudoBoardPainter extends CustomPainter {
  final List<Player> ps;
  final List<int> seats;
  final List<List<int>> steps;
  final Set<String> movableKeys;
  final GameTheme theme;
  final Animation<double> pulse;

  _LudoBoardPainter({
    required this.ps,
    required this.seats,
    required this.steps,
    required this.movableKeys,
    required this.theme,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final cell = size.width / 15;
    Offset pt(double cu, double ru) => Offset(cu * cell, ru * cell);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = t.surface,
    );

    // bases
    for (int i = 0; i < ps.length; i++) {
      final o = _baseOrigins[seats[i]];
      final rect =
          Rect.fromLTWH(o[1] * cell, o[0] * cell, 6 * cell, 6 * cell).deflate(cell * 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.6)),
        Paint()..color = ps[i].color.withValues(alpha: 0.16),
      );
      for (int k = 0; k < 4; k++) {
        final ctr = pt(o[1] + (k % 2 == 0 ? 1.7 : 4.3), o[0] + (k < 2 ? 1.7 : 4.3));
        canvas.drawCircle(ctr, cell * 0.52,
            Paint()..color = Colors.white.withValues(alpha: t.dark ? 0.14 : 0.75));
        canvas.drawCircle(
            ctr,
            cell * 0.52,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = ps[i].color);
      }
    }

    // main track cells
    for (int i = 0; i < 52; i++) {
      final rc = _track[i];
      final rect = Rect.fromLTWH(rc[1] * cell, rc[0] * cell, cell, cell).deflate(0.6);
      int owner = -1;
      for (int sgi = 0; sgi < seats.length; sgi++) {
        if (_startIdx[seats[sgi]] == i) owner = sgi;
      }
      Color fill = t.background.withValues(alpha: 0.4);
      if (owner >= 0) {
        fill = ps[owner].color;
      } else if (_safeIdx.contains(i)) {
        fill = t.accent.withValues(alpha: 0.32);
      }
      canvas.drawRect(rect, Paint()..color = fill);
      if (_safeIdx.contains(i)) {
        _drawText(canvas, '★', pt(rc[1] + 0.5, rc[0] + 0.5), cell * 0.48,
            owner >= 0 ? Colors.white : t.accent);
      }
    }

    // home columns
    for (int i = 0; i < ps.length; i++) {
      for (final h in _homeCols[seats[i]]) {
        final rect = Rect.fromLTWH(h[1] * cell, h[0] * cell, cell, cell).deflate(0.6);
        canvas.drawRect(rect, Paint()..color = ps[i].color.withValues(alpha: 0.45));
      }
    }

    // center home triangles
    final seatToPlayer = {for (int i = 0; i < ps.length; i++) seats[i]: i};
    final c = pt(7.5, 7.5);
    final corners = [pt(6, 6), pt(6, 9), pt(9, 9), pt(9, 6)];
    for (int s = 0; s < 4; s++) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(corners[s].dx, corners[s].dy)
        ..lineTo(corners[(s + 1) % 4].dx, corners[(s + 1) % 4].dy)
        ..close();
      final pi = seatToPlayer[s];
      canvas.drawPath(
        path,
        Paint()
          ..color = pi == null
              ? t.background.withValues(alpha: 0.5)
              : ps[pi].color.withValues(alpha: 0.8),
      );
    }
    _drawText(canvas, '🏆', c, cell * 1.05, Colors.white);

    // tokens (with stacking offsets when sharing a cell)
    final stacked = <String, int>{};
    for (int i = 0; i < ps.length; i++) {
      for (int k = 0; k < 4; k++) {
        var off = _tokenUnits(seats, steps, i, k);
        final key = '${off.dx.floor()}_${off.dy.floor()}';
        final n = stacked[key] ?? 0;
        stacked[key] = n + 1;
        if (n > 0) {
          off = off + Offset((n % 2) * 0.4 - 0.2, (n ~/ 2) * 0.4 - 0.2);
        }
        final ctr = pt(off.dx, off.dy);
        final finished = steps[i][k] == 56;
        final rad = cell * (finished ? 0.22 : 0.35);
        if (movableKeys.contains('$i-$k')) {
          canvas.drawCircle(
            ctr,
            rad + cell * 0.16,
            Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.4 * pulse.value),
          );
        }
        canvas.drawCircle(ctr, rad + 2, Paint()..color = Colors.white);
        canvas.drawCircle(ctr, rad, Paint()..color = ps[i].color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter old) => true;
}
