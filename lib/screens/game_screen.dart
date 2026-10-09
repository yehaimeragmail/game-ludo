import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ludo_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import 'settings_screen.dart';

/// Ludo game screen — Artisan Parlor edition.
/// Renders the [LudoEngine] state with a physical walnut-and-brass board.
class GameScreen extends StatefulWidget {
  final LudoEngine engine;
  final ParlorAudio audio;
  final ParlorSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  Timer? _diceTimer;
  int _shownDice = 0;
  bool _paused = false;
  final _rand = Random();

  LudoEngine get _e => widget.engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _diceTimer?.cancel();
    _e.removeListener(_onEngineChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_e.over && !_paused) {
      setState(() => _paused = true); // auto-pause in background
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
    if (_e.over) _onGameOver();
  }

  Future<void> _onEngineEvent(LudoEvent event) async {
    final a = widget.audio;
    switch (event) {
      case LudoEvent.move:
        await a.move();
        break;
      case LudoEvent.capture:
        await a.capture();
        break;
      case LudoEvent.tokenHome:
        await a.tokenHome();
        break;
      case LudoEvent.invalid:
        await a.invalid();
        break;
      case LudoEvent.noMoves:
      case LudoEvent.turnForfeited:
        await a.invalid();
        break;
      case LudoEvent.botRolling:
        _animateDice(isBot: true);
        break;
      case LudoEvent.humanWon:
        await a.win();
        break;
      case LudoEvent.botWon:
        await a.lose();
        break;
    }
  }

  Future<void> _onGameOver() async {
    final w = _e.players[_e.winner!];
    final humanWon = !w.isBot;
    await widget.settings.recordGame(humanWon: humanWon, turns: _e.turnCount);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        winnerName: w.name,
        winnerColor: w.color,
        humanWon: humanWon,
        audio: widget.audio,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _e.restart();
      widget.audio.startGameMusic();
    } else {
      widget.audio.stopMusic();
      Navigator.of(context).pop();
    }
  }

  void _animateDice({required bool isBot}) {
    _diceTimer?.cancel();
    widget.audio.dice();
    int ticks = 0;
    _diceTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      ticks++;
      setState(() => _shownDice = _rand.nextInt(6) + 1);
      if (ticks >= 9) {
        t.cancel();
        final value = _rand.nextInt(6) + 1;
        setState(() => _shownDice = value);
        if (isBot) {
          _e.botSettle(value);
        } else {
          _e.settleRoll(value);
        }
      }
    });
  }

  void _onDiceTap() {
    if (!_e.awaitingRoll || _e.current.isBot || _paused) return;
    widget.audio.click();
    _e.roll(); // sets rolling=true
    _animateDice(isBot: false);
  }

  void _onBoardTap(Offset local, double size) {
    if (_e.over || _e.dice == 0 || _e.current.isBot || _paused) return;
    final cell = size / 15;
    final r = (local.dy / cell).floor().clamp(0, 14);
    final c = (local.dx / cell).floor().clamp(0, 14);
    for (final ti in _e.movable) {
      final pos = tokenCell(_e.seats, _e.steps, _e.turn, ti);
      if (pos[0] == r && pos[1] == c) {
        widget.audio.click();
        _e.moveToken(ti);
        return;
      }
    }
  }

  void _togglePause() {
    widget.audio.click();
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    final me = _e.current;
    final canRoll =
        _e.awaitingRoll && !me.isBot && !_paused && !_e.over;
    return WoodBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.pause, color: Parlor.brassLight),
            onPressed: _togglePause,
          ),
          title: Text('Ludo', style: Parlor.display(22)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Parlor.brassLight),
              onPressed: () async {
                widget.audio.click();
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    audio: widget.audio,
                    settings: widget.settings,
                  ),
                ));
                widget.audio.configure(
                  musicOn: widget.settings.musicOn,
                  sfxOn: widget.settings.sfxOn,
                  volume: widget.settings.volume,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _TurnPlaque(player: me, banner: _e.banner),
                    const SizedBox(height: 8),
                    _ScoreStrip(engine: _e),
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
                            painter: _ParlorBoardPainter(
                              engine: _e,
                              pulse: _pulse,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DiceTray(
                          value: _shownDice,
                          rolling: _e.rolling,
                          canRoll: canRoll,
                          onTap: _onDiceTap,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _hintText(),
                            style: Parlor.body(15,
                                color: Parlor.ivoryDim),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_paused && !_e.over)
              _PauseOverlay(
                onResume: _togglePause,
                onRestart: () {
                  setState(() => _paused = false);
                  _e.restart();
                },
                onQuit: () {
                  widget.audio.stopMusic();
                  Navigator.of(context).pop();
                },
                audio: widget.audio,
              ),
          ],
        ),
      ),
    );
  }

  String _hintText() {
    if (_e.over) return '';
    final me = _e.current;
    if (me.isBot) return '${me.name} is playing…';
    if (_e.rolling) return 'Rolling…';
    if (_e.dice == 0) return 'Your turn — tap the dice!';
    if (_e.movable.isEmpty) return '';
    return 'Tap a glowing token!';
  }
}

// ---------------------------------------------------------------------------
// Turn plaque
// ---------------------------------------------------------------------------
class _TurnPlaque extends StatelessWidget {
  final LudoPlayer player;
  final String banner;
  const _TurnPlaque({required this.player, required this.banner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Parlor.walnutDeep.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Parlor.brass.withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Parlor.shadow, offset: Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player.color,
              border: Border.all(color: Parlor.brassLight, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Parlor.shadow,
                    offset: Offset(0, 2),
                    blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.name}${player.isBot ? '  •  BOT' : ''}',
                  style: Parlor.label(13, color: Parlor.brassLight),
                ),
                Text(
                  banner,
                  style: Parlor.body(14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score strip: home counts per player
// ---------------------------------------------------------------------------
class _ScoreStrip extends StatelessWidget {
  final LudoEngine engine;
  const _ScoreStrip({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < engine.n; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: engine.turn == i
                  ? engine.players[i].color.withValues(alpha: 0.35)
                  : Parlor.walnutDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: engine.turn == i
                    ? Parlor.brassLight
                    : Parlor.brass.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              '${engine.players[i].name.split(' ').first}  ${engine.players[i].homeCount}/4',
              style: Parlor.label(12),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dice tray: ivory die with engraved pips
// ---------------------------------------------------------------------------
class _DiceTray extends StatelessWidget {
  final int value;
  final bool rolling;
  final bool canRoll;
  final VoidCallback onTap;
  const _DiceTray({
    required this.value,
    required this.rolling,
    required this.canRoll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canRoll ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF0), Parlor.ivory, Color(0xFFD9CDAE)],
          ),
          border: Border.all(
            color: canRoll ? Parlor.brassLight : Parlor.brassDark,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Parlor.shadow.withValues(alpha: 0.7),
              offset: const Offset(0, 6),
              blurRadius: 10,
            ),
            if (canRoll)
              BoxShadow(
                color: Parlor.brass.withValues(alpha: 0.45),
                offset: const Offset(0, 0),
                blurRadius: 16,
              ),
          ],
        ),
        child: CustomPaint(painter: _DicePipsPainter(value: value)),
      ),
    );
  }
}

class _DicePipsPainter extends CustomPainter {
  final int value;
  _DicePipsPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    if (value < 1) {
      // idle: draw a small brass die glyph
      final tp = TextPainter(
        text: TextSpan(
            text: '❖',
            style: TextStyle(
                fontSize: 34, color: Parlor.brassDark.withValues(alpha: 0.7))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset((size.width - tp.width) / 2,
              (size.height - tp.height) / 2));
      return;
    }
    final r = size.width * 0.075;
    void pip(double fx, double fy) {
      final c = Offset(size.width * fx, size.height * fy);
      // engraved pip: dark inset with subtle top highlight
      canvas.drawCircle(c + const Offset(0, 1.2),
          r, Paint()..color = const Color(0xFF3B2416).withValues(alpha: 0.25));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF4A2E1B));
      canvas.drawCircle(
          c + Offset(-r * 0.25, -r * 0.25),
          r * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.18));
    }

    switch (value) {
      case 1:
        pip(0.5, 0.5);
        break;
      case 2:
        pip(0.3, 0.3);
        pip(0.7, 0.7);
        break;
      case 3:
        pip(0.28, 0.28);
        pip(0.5, 0.5);
        pip(0.72, 0.72);
        break;
      case 4:
        pip(0.32, 0.32);
        pip(0.68, 0.32);
        pip(0.32, 0.68);
        pip(0.68, 0.68);
        break;
      case 5:
        pip(0.3, 0.3);
        pip(0.7, 0.3);
        pip(0.5, 0.5);
        pip(0.3, 0.7);
        pip(0.7, 0.7);
        break;
      case 6:
        pip(0.32, 0.28);
        pip(0.68, 0.28);
        pip(0.32, 0.5);
        pip(0.68, 0.5);
        pip(0.32, 0.72);
        pip(0.68, 0.72);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DicePipsPainter old) =>
      old.value != value;
}

// ---------------------------------------------------------------------------
// Pause overlay
// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  final ParlorAudio audio;
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Parlor.shadow.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Parlor.walnutMid, Parlor.walnutDeep],
          ),
          border: Border.all(color: Parlor.brass, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Parlor.shadow, offset: Offset(0, 10), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: Parlor.display(28)),
            const SizedBox(height: 20),
            WoodButton(
                label: 'Resume',
                width: 220,
                onTap: () {
                  audio.click();
                  onResume();
                }),
            const SizedBox(height: 12),
            WoodButton(
                label: 'Restart',
                width: 220,
                onTap: () {
                  audio.click();
                  onRestart();
                }),
            const SizedBox(height: 12),
            WoodButton(
                label: 'Quit to Menu',
                width: 220,
                onTap: () {
                  audio.click();
                  onQuit();
                }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game over dialog
// ---------------------------------------------------------------------------
class _GameOverDialog extends StatelessWidget {
  final String winnerName;
  final Color winnerColor;
  final bool humanWon;
  final ParlorAudio audio;
  const _GameOverDialog({
    required this.winnerName,
    required this.winnerColor,
    required this.humanWon,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Parlor.walnutMid, Parlor.walnutDeep],
          ),
          border: Border.all(color: Parlor.brass, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Parlor.shadow, offset: Offset(0, 10), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Winner podium: brass disc with winner token on top
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _PodiumPainter(color: winnerColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(humanWon ? 'Victory!' : 'Game Over',
                style: Parlor.display(30)),
            const SizedBox(height: 6),
            Text(
              humanWon
                  ? '$winnerName brings all four tokens home. The parlor applauds!'
                  : '$winnerName takes the crown this time.',
              style: Parlor.body(15, color: Parlor.ivoryDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            WoodButton(
              label: 'Play Again',
              width: 220,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 12),
            WoodButton(
              label: 'Main Menu',
              width: 220,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumPainter extends CustomPainter {
  final Color color;
  _PodiumPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // brass podium
    final podium = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 88), width: 150, height: 34),
      const Radius.circular(8),
    );
    canvas.drawRRect(
        podium,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Parlor.brassLight, Parlor.brass, Parlor.brassDark],
          ).createShader(podium.outerRect));
    canvas.drawRRect(
        podium,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Parlor.shadow.withValues(alpha: 0.5));
    // glossy winner token with contact shadow
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 74), width: 52, height: 12),
        Paint()..color = Parlor.shadow.withValues(alpha: 0.55));
    final tokenRect =
        Rect.fromCircle(center: Offset(cx, 52), radius: 24);
    canvas.drawCircle(
        Offset(cx, 52), 24, Paint()..color = color);
    canvas.drawCircle(
        Offset(cx, 52),
        24,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.55),
            radius: 1.1,
            colors: [
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(tokenRect));
    canvas.drawCircle(
        Offset(cx, 52),
        24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Parlor.shadow.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// The parlor board painter — physical walnut, brass, glossy tokens.
// ---------------------------------------------------------------------------
class _ParlorBoardPainter extends CustomPainter {
  final LudoEngine engine;
  final Animation<double> pulse;
  _ParlorBoardPainter({required this.engine, required this.pulse})
      : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    Offset pt(double cu, double ru) => Offset(cu * cell, ru * cell);

    // Board base: dark walnut slab with brass trim and drop shadow.
    final baseRect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(
      baseRect.shift(const Offset(0, 7)),
      Paint()..color = Parlor.shadow.withValues(alpha: 0.65),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A2E1B), Parlor.walnutDark, Color(0xFF2A1708)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Parlor.brassDark,
    );

    final board = Rect.fromLTWH(
        cell * 0.35, cell * 0.35, cell * 14.3, cell * 14.3);

    // Bases (quadrant panels).
    for (int i = 0; i < engine.n; i++) {
      final o = baseOrigins[engine.seats[i]];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(o[1] * cell, o[0] * cell, 6 * cell, 6 * cell)
            .deflate(cell * 0.28),
        Radius.circular(cell * 0.5),
      );
      // inset panel
      canvas.drawRRect(
          rect.shift(const Offset(0, 3)),
          Paint()..color = Parlor.shadow.withValues(alpha: 0.5));
      canvas.drawRRect(
        rect,
        Paint()..color = engine.players[i].color.withValues(alpha: 0.22),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = engine.players[i].color.withValues(alpha: 0.75),
      );
      // token wells
      for (int k = 0; k < 4; k++) {
        final ctr =
            pt(o[1] + (k % 2 == 0 ? 1.7 : 4.3), o[0] + (k < 2 ? 1.7 : 4.3));
        canvas.drawCircle(ctr + const Offset(0, 2), cell * 0.5,
            Paint()..color = Parlor.shadow.withValues(alpha: 0.5));
        canvas.drawCircle(
            ctr, cell * 0.5, Paint()..color = Parlor.walnutDeep);
        canvas.drawCircle(
            ctr,
            cell * 0.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = engine.players[i].color.withValues(alpha: 0.6));
      }
    }

    // Track cells: parchment with beveled edges.
    for (int i = 0; i < 52; i++) {
      final rc = trackCells[i];
      final r = Rect.fromLTWH(rc[1] * cell, rc[0] * cell, cell, cell);
      int owner = -1;
      for (int sgi = 0; sgi < engine.seats.length; sgi++) {
        if (startIdx[engine.seats[sgi]] == i) owner = sgi;
      }
      final isSafe = safeIdx.contains(i);
      Color fill;
      if (owner >= 0) {
        fill = engine.players[owner].color;
      } else if (isSafe) {
        fill = const Color(0xFFE4D3A8);
      } else {
        fill = const Color(0xFFEFE3C8);
      }
      // bevel: light top-left, dark bottom-right
      canvas.drawRect(r.deflate(0.5), Paint()..color = fill);
      canvas.drawLine(
          r.topLeft + const Offset(1, 1), r.topRight + const Offset(-1, 1),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 1.2);
      canvas.drawLine(
          r.bottomLeft + const Offset(1, -1),
          r.bottomRight + const Offset(-1, -1),
          Paint()
            ..color = Parlor.shadow.withValues(alpha: 0.28)
            ..strokeWidth = 1.2);
      if (isSafe && owner < 0) {
        _drawGlyph(canvas, '★', pt(rc[1] + 0.5, rc[0] + 0.5),
            cell * 0.46, Parlor.brassDark);
      }
      if (owner >= 0) {
        _drawGlyph(canvas, '★', pt(rc[1] + 0.5, rc[0] + 0.5),
            cell * 0.42, Colors.white.withValues(alpha: 0.85));
      }
    }

    // Home columns.
    for (int i = 0; i < engine.n; i++) {
      for (final h in homeCols[engine.seats[i]]) {
        final r = Rect.fromLTWH(h[1] * cell, h[0] * cell, cell, cell);
        canvas.drawRect(
            r.deflate(0.5),
            Paint()
              ..color =
                  engine.players[i].color.withValues(alpha: 0.55));
        canvas.drawLine(
            r.topLeft + const Offset(1, 1), r.topRight + const Offset(-1, 1),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35)
              ..strokeWidth = 1.2);
      }
    }

    // Center home: four triangles + brass trophy medallion.
    final seatToPlayer = {
      for (int i = 0; i < engine.n; i++) engine.seats[i]: i
    };
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
              ? const Color(0xFFEFE3C8)
              : engine.players[pi].color,
      );
    }
    canvas.drawCircle(c, cell * 0.72,
        Paint()..color = Parlor.shadow.withValues(alpha: 0.4));
    canvas.drawCircle(
        c,
        cell * 0.68,
        Paint()
          ..shader = const RadialGradient(
            colors: [Parlor.brassLight, Parlor.brass, Parlor.brassDark],
          ).createShader(Rect.fromCircle(center: c, radius: cell * 0.68)));
    _drawGlyph(canvas, '♛', c, cell * 0.62, Parlor.walnutDeep);

    // Tokens: contact shadow + glossy lacquered pawn.
    final stacked = <String, int>{};
    for (int i = 0; i < engine.n; i++) {
      for (int k = 0; k < 4; k++) {
        var off = tokenUnits(engine.seats, engine.steps, i, k);
        final key = '${off.dx.toStringAsFixed(1)}_${off.dy.toStringAsFixed(1)}';
        final nst = stacked[key] ?? 0;
        stacked[key] = nst + 1;
        if (nst > 0) {
          off = off + Offset((nst % 2) * 0.42 - 0.21, (nst ~/ 2) * 0.42 - 0.21);
        }
        final ctr = pt(off.dx, off.dy);
        final finished = engine.steps[i][k] == 56;
        final rad = cell * (finished ? 0.20 : 0.34);
        // contact shadow
        canvas.drawOval(
          Rect.fromCenter(
              center: ctr + Offset(0, rad * 0.45),
              width: rad * 1.9,
              height: rad * 0.7),
          Paint()..color = Parlor.shadow.withValues(alpha: 0.5),
        );
        // movable highlight ring
        if (engine.movable.contains(k) && engine.turn == i) {
          canvas.drawCircle(
            ctr,
            rad + cell * 0.15,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Parlor.brassLight
                  .withValues(alpha: 0.55 + 0.45 * pulse.value),
          );
        }
        // lacquered body
        final bodyRect = Rect.fromCircle(center: ctr, radius: rad);
        canvas.drawCircle(ctr, rad,
            Paint()..color = engine.players[i].color);
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.45, -0.55),
                radius: 1.15,
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.0),
                  Parlor.shadow.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.45, 1.0],
              ).createShader(bodyRect));
        // rim
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Parlor.shadow.withValues(alpha: 0.5));
        // pip dot for readability
        canvas.drawCircle(
            ctr + Offset(-rad * 0.25, -rad * 0.25),
            rad * 0.22,
            Paint()..color = Colors.white.withValues(alpha: 0.75));
      }
    }

    // Inner brass frame line.
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Parlor.brass.withValues(alpha: 0.55),
    );
  }

  void _drawGlyph(
      Canvas canvas, String glyph, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: glyph, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ParlorBoardPainter old) => true;
}
