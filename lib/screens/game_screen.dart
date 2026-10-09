import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/ludo_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import '../theme/parlor_themes.dart';
import 'settings_screen.dart';

/// Ludo game screen — Artisan Parlor exemplar edition.
///
/// - Every player side has its OWN dice: it activates and rolls with a
///   real-time animation on the current player's card (human or bot).
/// - Token moves animate step-by-step; bot turns are fully visible.
/// - The engine owns the turn state machine, so the UI can never desync.
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
  late final AnimationController _moveCtrl;
  MoveAnim? _shownAnim;
  bool _paused = false;

  LudoEngine get _e => widget.engine;
  ParlorThemeDef get _t => ParlorThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moveCtrl = AnimationController(vsync: this);
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _moveCtrl.dispose();
    _e.removeListener(_onEngineChanged);
    _e.onEvent = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_e.over && mounted) {
        setState(() {
          _paused = true;
          _e.setPaused(true);
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // Drive the move-animation controller from the engine's MoveAnim.
    final anim = _e.moveAnim;
    if (anim != null && !identical(anim, _shownAnim)) {
      _shownAnim = anim;
      _moveCtrl.duration = Duration(milliseconds: anim.totalMs);
      _moveCtrl.forward(from: 0);
    } else if (anim == null) {
      _shownAnim = null;
    }
    setState(() {});
    if (_e.over) _onGameOver();
  }

  Future<void> _onEngineEvent(LudoEvent event) async {
    final a = widget.audio;
    switch (event) {
      case LudoEvent.diceRolling:
        await a.dice();
        break;
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
        theme: _t,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _e.restart();
      widget.audio.startGameMusic();
    } else {
      // App-scoped music: keep playing; menu switches back to menu track.
      Navigator.of(context).pop();
    }
  }

  void _onDiceTap(int pi) {
    if (_paused || _e.over) return;
    if (_e.awaitingRoll && _e.turn == pi && !_e.current.isBot) {
      widget.audio.click();
      _e.roll();
    }
  }

  void _onBoardTap(Offset local, double size) {
    if (_paused || _e.over || !_e.awaitingHumanMove) return;
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
    setState(() {
      _paused = !_paused;
      _e.setPaused(_paused);
      if (_paused) {
        widget.audio.onAppPaused();
      } else {
        widget.audio.onAppResumed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WoodBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                color: t.accentLight),
            onPressed: _togglePause,
          ),
          title: Text('Ludo', style: Parlor.display(22, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: t.accentLight),
              onPressed: () async {
                widget.audio.click();
                final wasPaused = _paused;
                if (!wasPaused) {
                  setState(() {
                    _paused = true;
                    _e.setPaused(true);
                  });
                }
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
                if (mounted && !wasPaused) {
                  setState(() {
                    _paused = false;
                    _e.setPaused(false);
                  });
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    _TurnPlaque(engine: _e, theme: t),
                    const SizedBox(height: 8),
                    _PlayerStrip(
                      engine: _e,
                      theme: t,
                      diceStyle: widget.settings.diceStyle,
                      onDiceTap: _onDiceTap,
                      paused: _paused,
                    ),
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Builder(
                        builder: (bctx) => GestureDetector(
                          onTapDown: (d) {
                            final box =
                                bctx.findRenderObject()! as RenderBox;
                            _onBoardTap(d.localPosition, box.size.width);
                          },
                          child: AnimatedBuilder(
                            animation: _moveCtrl,
                            builder: (_, _) => CustomPaint(
                              painter: _ParlorBoardPainter(
                                engine: _e,
                                theme: t,
                                tokenShape: widget.settings.tokenShape,
                                animProgress: _moveCtrl.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _hintText(),
                      style: Parlor.body(14,
                          theme: t,
                          color: t.ivory.withValues(alpha: 0.8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_paused && !_e.over)
              _PauseOverlay(
                theme: t,
                onResume: _togglePause,
                onRestart: () {
                  setState(() => _paused = false);
                  _e.restart();
                },
                onQuit: () {
                  // App-scoped music keeps playing across screens.
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
    if (_paused) return 'Paused';
    final me = _e.current;
    switch (_e.phase) {
      case Phase.rolling:
        return '${me.name} is rolling…';
      case Phase.awaitingRoll:
        return me.isBot ? '${me.name} is up…' : 'Your turn — tap your dice!';
      case Phase.awaitingMove:
        if (me.isBot) return '${me.name} is thinking…';
        return _e.movable.length == 1
            ? 'Only one move — go!'
            : 'Tap a glowing token!';
      case Phase.animating:
        return '';
      case Phase.settling:
        return _e.banner;
      case Phase.over:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Turn plaque: current player + banner.
// ---------------------------------------------------------------------------
class _TurnPlaque extends StatelessWidget {
  final LudoEngine engine;
  final ParlorThemeDef theme;
  const _TurnPlaque({required this.engine, required this.theme});

  @override
  Widget build(BuildContext context) {
    final player = engine.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.woodDeep.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 8),
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
              border: Border.all(color: theme.accentLight, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
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
                  style: Parlor.label(13, theme: theme),
                ),
                Text(
                  engine.banner,
                  style: Parlor.body(14, theme: theme),
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
// Player strip: EVERY side gets its own dice. The current player's dice
// activates, rolls with a real-time animation, and is tappable for humans.
// ---------------------------------------------------------------------------
class _PlayerStrip extends StatelessWidget {
  final LudoEngine engine;
  final ParlorThemeDef theme;
  final int diceStyle;
  final void Function(int pi) onDiceTap;
  final bool paused;
  const _PlayerStrip({
    required this.engine,
    required this.theme,
    required this.diceStyle,
    required this.onDiceTap,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < engine.n; i++)
          Expanded(
            child: _PlayerCard(
              engine: engine,
              theme: theme,
              pi: i,
              diceStyle: diceStyle,
              onDiceTap: onDiceTap,
              paused: paused,
            ),
          ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final LudoEngine engine;
  final ParlorThemeDef theme;
  final int pi;
  final int diceStyle;
  final void Function(int pi) onDiceTap;
  final bool paused;
  const _PlayerCard({
    required this.engine,
    required this.theme,
    required this.pi,
    required this.diceStyle,
    required this.onDiceTap,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    final p = engine.players[pi];
    final isCurrent = engine.turn == pi && !engine.over;
    final canRoll = isCurrent &&
        engine.awaitingRoll &&
        !p.isBot &&
        !paused &&
        !engine.over;
    final rolling = isCurrent && engine.rolling;
    // Show this player's last settled value while it is fresh.
    final showValue = engine.lastRollBy == pi && engine.dice != 0
        ? engine.dice
        : (isCurrent && engine.dice != 0 ? engine.dice : 0);
    return GestureDetector(
      onTap: canRoll ? () => onDiceTap(pi) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCurrent
              ? p.color.withValues(alpha: 0.30)
              : theme.woodDeep.withValues(alpha: 0.6),
          border: Border.all(
            color: isCurrent ? theme.accentLight : theme.accent.withValues(alpha: 0.3),
            width: isCurrent ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isCurrent)
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.color,
                    border:
                        Border.all(color: theme.accentLight, width: 1.2),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    p.name,
                    style: Parlor.label(11, theme: theme),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (p.isBot)
              Text('BOT',
                  style: Parlor.label(9,
                      theme: theme,
                      color: theme.ivory.withValues(alpha: 0.6))),
            const SizedBox(height: 6),
            _RollingDice(
              rolling: rolling,
              value: rolling ? 0 : showValue,
              diceStyle: diceStyle,
              theme: theme,
              active: isCurrent,
              tappable: canRoll,
            ),
            const SizedBox(height: 4),
            Text('${p.homeCount}/4 home',
                style: Parlor.label(10, theme: theme)),
          ],
        ),
      ),
    );
  }
}

/// A die that plays a real-time rolling animation while [rolling] is true,
/// then rests on [value].
class _RollingDice extends StatefulWidget {
  final bool rolling;
  final int value; // 0 = idle glyph
  final int diceStyle;
  final ParlorThemeDef theme;
  final bool active;
  final bool tappable;
  const _RollingDice({
    required this.rolling,
    required this.value,
    required this.diceStyle,
    required this.theme,
    required this.active,
    required this.tappable,
  });

  @override
  State<_RollingDice> createState() => _RollingDiceState();
}

class _RollingDiceState extends State<_RollingDice> {
  Timer? _timer;
  int _face = 1;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _RollingDice old) {
    super.didUpdateWidget(old);
    if (old.rolling != widget.rolling) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (widget.rolling) {
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (!mounted) return;
        setState(() => _face = _rand.nextInt(6) + 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final shown = widget.rolling ? _face : widget.value;
    // Dice visual per style.
    late final Color bg0, bg1, pip, edge;
    switch (widget.diceStyle) {
      case 1: // Brass Noble
        bg0 = const Color(0xFF4A3418);
        bg1 = const Color(0xFF2A1E10);
        pip = t.accentLight;
        edge = t.accent;
        break;
      case 2: // Oak
        bg0 = const Color(0xFF9A6530);
        bg1 = const Color(0xFF6E4520);
        pip = const Color(0xFF2E1A0C);
        edge = const Color(0xFF4A2E14);
        break;
      case 3: // Marble Vein
        bg0 = const Color(0xFFF4F6F8);
        bg1 = const Color(0xFFC9D2DA);
        pip = const Color(0xFF3A4A5A);
        edge = const Color(0xFF8A9AAC);
        break;
      case 4: // Obsidian
        bg0 = const Color(0xFF2A2A32);
        bg1 = const Color(0xFF0E0E12);
        pip = const Color(0xFFE8ECF5);
        edge = const Color(0xFF5A5A6A);
        break;
      case 5: // Copper Rose
        bg0 = const Color(0xFFB8735A);
        bg1 = const Color(0xFF7E4A38);
        pip = const Color(0xFF2E1A14);
        edge = const Color(0xFF5E3428);
        break;
      default: // Ivory Classic
        bg0 = const Color(0xFFFFFBF0);
        bg1 = const Color(0xFFD9CDAE);
        pip = const Color(0xFF4A2E1B);
        edge = t.accent;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg0, bg1],
        ),
        border: Border.all(
          color: widget.tappable
              ? t.accentLight
              : widget.active
                  ? t.accent
                  : edge.withValues(alpha: 0.6),
          width: widget.tappable ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 4),
            blurRadius: 6,
          ),
          if (widget.tappable)
            BoxShadow(
              color: t.accent.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
        ],
      ),
      child: CustomPaint(
        painter: _DicePipsPainter(value: shown, pip: pip, idleColor: edge),
      ),
    );
  }
}

class _DicePipsPainter extends CustomPainter {
  final int value;
  final Color pip;
  final Color idleColor;
  _DicePipsPainter(
      {required this.value, required this.pip, required this.idleColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (value < 1) {
      final tp = TextPainter(
        text: TextSpan(
            text: '❖',
            style: TextStyle(
                fontSize: 24, color: idleColor.withValues(alpha: 0.7))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final r = size.width * 0.075;
    void dot(double fx, double fy) {
      final c = Offset(size.width * fx, size.height * fy);
      canvas.drawCircle(c + const Offset(0, 1.0), r,
          Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawCircle(c, r, Paint()..color = pip);
      canvas.drawCircle(
          c + Offset(-r * 0.25, -r * 0.25),
          r * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.20));
    }

    switch (value) {
      case 1:
        dot(0.5, 0.5);
        break;
      case 2:
        dot(0.3, 0.3);
        dot(0.7, 0.7);
        break;
      case 3:
        dot(0.28, 0.28);
        dot(0.5, 0.5);
        dot(0.72, 0.72);
        break;
      case 4:
        dot(0.32, 0.32);
        dot(0.68, 0.32);
        dot(0.32, 0.68);
        dot(0.68, 0.68);
        break;
      case 5:
        dot(0.3, 0.3);
        dot(0.7, 0.3);
        dot(0.5, 0.5);
        dot(0.3, 0.7);
        dot(0.7, 0.7);
        break;
      case 6:
        dot(0.32, 0.28);
        dot(0.68, 0.28);
        dot(0.32, 0.5);
        dot(0.68, 0.5);
        dot(0.32, 0.72);
        dot(0.68, 0.72);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DicePipsPainter old) =>
      old.value != value || old.pip != pip;
}

// ---------------------------------------------------------------------------
// Pause overlay
// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final ParlorThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  final ParlorAudio audio;
  const _PauseOverlay({
    required this.theme,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDeep],
          ),
          border: Border.all(color: t.accent, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 10),
                blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: Parlor.display(28, theme: t)),
            const SizedBox(height: 20),
            WoodButton(
                label: 'Resume',
                width: 220,
                theme: t,
                onTap: () {
                  audio.click();
                  onResume();
                }),
            const SizedBox(height: 12),
            WoodButton(
                label: 'Restart',
                width: 220,
                theme: t,
                onTap: () {
                  audio.click();
                  onRestart();
                }),
            const SizedBox(height: 12),
            WoodButton(
                label: 'Quit to Menu',
                width: 220,
                theme: t,
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
  final ParlorThemeDef theme;
  const _GameOverDialog({
    required this.winnerName,
    required this.winnerColor,
    required this.humanWon,
    required this.audio,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDeep],
          ),
          border: Border.all(color: t.accent, width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 10),
                blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _PodiumPainter(color: winnerColor, theme: t),
              ),
            ),
            const SizedBox(height: 8),
            Text(humanWon ? 'Victory!' : 'Game Over',
                style: Parlor.display(30, theme: t)),
            const SizedBox(height: 6),
            Text(
              humanWon
                  ? '$winnerName brings all four tokens home. The parlor applauds!'
                  : '$winnerName takes the crown this time.',
              style: Parlor.body(15,
                  theme: t, color: t.ivory.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            WoodButton(
              label: 'Play Again',
              width: 220,
              theme: t,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 12),
            WoodButton(
              label: 'Main Menu',
              width: 220,
              theme: t,
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
  final ParlorThemeDef theme;
  _PodiumPainter({required this.color, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final cx = size.width / 2;
    final podium = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 88), width: 150, height: 34),
      const Radius.circular(8),
    );
    canvas.drawRRect(
        podium,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(podium.outerRect));
    canvas.drawRRect(
        podium,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 74), width: 52, height: 12),
        Paint()..color = Colors.black.withValues(alpha: 0.55));
    final tokenRect = Rect.fromCircle(center: Offset(cx, 52), radius: 24);
    canvas.drawCircle(Offset(cx, 52), 24, Paint()..color = color);
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
          ..color = Colors.black.withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// The parlor board painter — theme-aware, token shapes, move animation.
// ---------------------------------------------------------------------------
class _ParlorBoardPainter extends CustomPainter {
  final LudoEngine engine;
  final ParlorThemeDef theme;
  final int tokenShape;
  final double animProgress;
  _ParlorBoardPainter({
    required this.engine,
    required this.theme,
    required this.tokenShape,
    required this.animProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final cell = size.width / 15;
    Offset pt(double cu, double ru) => Offset(cu * cell, ru * cell);

    // Board base: wood slab with metal trim and drop shadow.
    final baseRect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(
      baseRect.shift(const Offset(0, 7)),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.woodMid, t.woodDark, t.woodDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.accentDark,
    );

    final board =
        Rect.fromLTWH(cell * 0.35, cell * 0.35, cell * 14.3, cell * 14.3);

    // Bases (quadrant panels).
    for (int i = 0; i < engine.n; i++) {
      final o = baseOrigins[engine.seats[i]];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(o[1] * cell, o[0] * cell, 6 * cell, 6 * cell)
            .deflate(cell * 0.28),
        Radius.circular(cell * 0.5),
      );
      canvas.drawRRect(
          rect.shift(const Offset(0, 3)),
          Paint()..color = Colors.black.withValues(alpha: 0.5));
      // Current player's base gets a highlight wash.
      canvas.drawRRect(
        rect,
        Paint()
          ..color = (engine.turn == i && !engine.over
                  ? engine.players[i].color.withValues(alpha: 0.38)
                  : engine.players[i].color.withValues(alpha: 0.20)),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = engine.turn == i && !engine.over ? 3 : 2
          ..color = (engine.turn == i && !engine.over
              ? t.accentLight
              : engine.players[i].color.withValues(alpha: 0.75)),
      );
      for (int k = 0; k < 4; k++) {
        final ctr =
            pt(o[1] + (k % 2 == 0 ? 1.7 : 4.3), o[0] + (k < 2 ? 1.7 : 4.3));
        canvas.drawCircle(ctr + const Offset(0, 2), cell * 0.5,
            Paint()..color = Colors.black.withValues(alpha: 0.5));
        canvas.drawCircle(ctr, cell * 0.5, Paint()..color = t.woodDeep);
        canvas.drawCircle(
            ctr,
            cell * 0.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = engine.players[i].color.withValues(alpha: 0.6));
      }
    }

    // Track cells with beveled edges.
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
        fill = t.trackDark;
      } else {
        fill = t.trackLight;
      }
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
            ..color = Colors.black.withValues(alpha: 0.28)
            ..strokeWidth = 1.2);
      if (isSafe) {
        _drawGlyph(
            canvas,
            '★',
            pt(rc[1] + 0.5, rc[0] + 0.5),
            cell * 0.44,
            owner >= 0
                ? Colors.white.withValues(alpha: 0.85)
                : t.accentDark);
      }
    }

    // Home columns.
    for (int i = 0; i < engine.n; i++) {
      for (final h in homeCols[engine.seats[i]]) {
        final r = Rect.fromLTWH(h[1] * cell, h[0] * cell, cell, cell);
        canvas.drawRect(r.deflate(0.5),
            Paint()..color = engine.players[i].color.withValues(alpha: 0.55));
        canvas.drawLine(
            r.topLeft + const Offset(1, 1), r.topRight + const Offset(-1, 1),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35)
              ..strokeWidth = 1.2);
      }
    }

    // Center home: four triangles + metal medallion.
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
              ? t.trackLight
              : engine.players[pi].color,
      );
    }
    canvas.drawCircle(c, cell * 0.72,
        Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawCircle(
        c,
        cell * 0.68,
        Paint()
          ..shader = RadialGradient(
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: c, radius: cell * 0.68)));
    _drawGlyph(canvas, '♛', c, cell * 0.62, t.woodDeep);

    // Tokens.
    final stacked = <String, int>{};
    final anim = engine.moveAnim;
    for (int i = 0; i < engine.n; i++) {
      for (int k = 0; k < 4; k++) {
        Offset off;
        double lift = 0;
        if (anim != null && anim.pi == i && anim.ti == k) {
          // Square-by-square WALK: the piece hops onto each square in turn.
          final step = anim.currentStep;
          off = tokenUnitsAt(engine.seats, i, k, step);
          // Per-square parabolic hop — highly visible landing on every box.
          lift = sin(anim.squareFrac * pi) * 0.5;
          if (anim.fromStep < 0) {
            // Base exit: slide from well to start square.
            final a = tokenUnitsAt(engine.seats, i, k, -1);
            final b = tokenUnitsAt(engine.seats, i, k, 0);
            final e = animProgress.clamp(0.0, 1.0);
            off = Offset(a.dx + (b.dx - a.dx) * e,
                a.dy + (b.dy - a.dy) * e - sin(e * pi) * 0.8);
          }
        } else {
          off = tokenUnits(engine.seats, engine.steps, i, k);
        }
        final key = '${off.dx.toStringAsFixed(1)}_${off.dy.toStringAsFixed(1)}';
        final nst = stacked[key] ?? 0;
        stacked[key] = nst + 1;
        if (nst > 0) {
          off = off + Offset((nst % 2) * 0.42 - 0.21, (nst ~/ 2) * 0.42 - 0.21);
        }
        var ctr = pt(off.dx, off.dy);
        ctr = ctr + Offset(0, -lift * cell);
        final finished = engine.steps[i][k] == 56;
        final rad = cell * (finished ? 0.20 : 0.34);
        canvas.drawOval(
          Rect.fromCenter(
              center: ctr + Offset(0, rad * 0.45),
              width: rad * 1.9,
              height: rad * 0.7),
          Paint()..color = Colors.black.withValues(alpha: 0.5),
        );
        if (engine.movable.contains(k) &&
            engine.turn == i &&
            engine.phase == Phase.awaitingMove) {
          canvas.drawCircle(
            ctr,
            rad + cell * 0.15,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = t.accentLight.withValues(alpha: 0.85),
          );
        }
        _drawToken(canvas, ctr, rad, engine.players[i].color, t);
      }
    }

    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.accent.withValues(alpha: 0.55),
    );
  }

  /// Token body per selected shape.
  void _drawToken(
      Canvas canvas, Offset ctr, double rad, Color color, ParlorThemeDef t) {
    switch (tokenShape) {
      case 1: // Facet Gem — cut diamond.
        final path = Path()
          ..moveTo(ctr.dx, ctr.dy - rad * 1.25)
          ..lineTo(ctr.dx + rad * 0.95, ctr.dy)
          ..lineTo(ctr.dx, ctr.dy + rad * 1.25)
          ..lineTo(ctr.dx - rad * 0.95, ctr.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
        // facet lines
        final facet = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.55);
        canvas.drawLine(Offset(ctr.dx, ctr.dy - rad * 1.25),
            Offset(ctr.dx, ctr.dy + rad * 1.25), facet);
        canvas.drawLine(Offset(ctr.dx - rad * 0.95, ctr.dy),
            Offset(ctr.dx + rad * 0.95, ctr.dy), facet);
        canvas.drawLine(
            Offset(ctr.dx, ctr.dy - rad * 1.25),
            Offset(ctr.dx + rad * 0.48, ctr.dy),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = Colors.white.withValues(alpha: 0.7));
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.45));
        break;
      case 2: // Wood Disc — turned wooden cylinder.
        final bodyRect = Rect.fromCircle(center: ctr, radius: rad);
        canvas.drawCircle(ctr, rad, Paint()..color = const Color(0xFF8A5A2E));
        // growth rings
        for (final rr in [0.75, 0.5, 0.28]) {
          canvas.drawCircle(
              ctr,
              rad * rr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3
                ..color = const Color(0xFF5A3A1A).withValues(alpha: 0.7));
        }
        // colored inlay dot
        canvas.drawCircle(ctr, rad * 0.30, Paint()..color = color);
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = t.accentDark);
        // top sheen
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.4, -0.5),
                radius: 1.1,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ).createShader(bodyRect));
        break;
      case 3: // Marble — swirled glass.
        final bodyRect = Rect.fromCircle(center: ctr, radius: rad);
        canvas.drawCircle(ctr, rad, Paint()..color = color);
        // swirl
        canvas.drawArc(
            Rect.fromCircle(center: ctr, radius: rad * 0.62),
            -0.6,
            3.6,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rad * 0.22
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.45));
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.45, -0.55),
                radius: 1.15,
                colors: [
                  Colors.white.withValues(alpha: 0.65),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.30),
                ],
                stops: const [0.0, 0.45, 1.0],
              ).createShader(bodyRect));
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = Colors.black.withValues(alpha: 0.4));
        break;
      case 4: // Star — five-point parlor star.
        final starPath = Path();
        for (int i = 0; i < 10; i++) {
          final rr = (i % 2 == 0) ? rad * 1.12 : rad * 0.48;
          final a = -pi / 2 + i * pi / 5;
          final px = ctr.dx + rr * cos(a);
          final py = ctr.dy + rr * sin(a);
          if (i == 0) {
            starPath.moveTo(px, py);
          } else {
            starPath.lineTo(px, py);
          }
        }
        starPath.close();
        canvas.drawPath(starPath, Paint()..color = color);
        canvas.drawPath(
            starPath,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.45));
        canvas.drawCircle(
            ctr + Offset(-rad * 0.15, -rad * 0.18),
            rad * 0.16,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
        break;
      case 5: // Crown — jeweled crown token.
        final crown = Path()
          ..moveTo(ctr.dx - rad * 0.95, ctr.dy + rad * 0.75)
          ..lineTo(ctr.dx - rad * 0.95, ctr.dy - rad * 0.25)
          ..lineTo(ctr.dx - rad * 0.48, ctr.dy + rad * 0.12)
          ..lineTo(ctr.dx, ctr.dy - rad * 0.72)
          ..lineTo(ctr.dx + rad * 0.48, ctr.dy + rad * 0.12)
          ..lineTo(ctr.dx + rad * 0.95, ctr.dy - rad * 0.25)
          ..lineTo(ctr.dx + rad * 0.95, ctr.dy + rad * 0.75)
          ..close();
        canvas.drawPath(crown, Paint()..color = color);
        // base band
        canvas.drawRect(
            Rect.fromLTWH(ctr.dx - rad * 0.95, ctr.dy + rad * 0.45,
                rad * 1.9, rad * 0.3),
            Paint()..color = t.accentDark);
        // jewels
        for (final jx in [-0.48, 0.0, 0.48]) {
          canvas.drawCircle(
              Offset(ctr.dx + rad * jx, ctr.dy + rad * 0.1),
              rad * 0.14,
              Paint()..color = Colors.white.withValues(alpha: 0.85));
        }
        canvas.drawPath(
            crown,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.45));
        break;
      case 6: // Shield — heraldic enamel shield.
        final shield = Path()
          ..moveTo(ctr.dx - rad * 0.85, ctr.dy - rad * 0.72)
          ..lineTo(ctr.dx + rad * 0.85, ctr.dy - rad * 0.72)
          ..lineTo(ctr.dx + rad * 0.85, ctr.dy + rad * 0.08)
          ..quadraticBezierTo(ctr.dx + rad * 0.85, ctr.dy + rad * 0.72,
              ctr.dx, ctr.dy + rad * 1.02)
          ..quadraticBezierTo(ctr.dx - rad * 0.85, ctr.dy + rad * 0.72,
              ctr.dx - rad * 0.85, ctr.dy + rad * 0.08)
          ..close();
        canvas.drawPath(shield, Paint()..color = color);
        // pale center stripe
        final stripe = Path()
          ..moveTo(ctr.dx - rad * 0.22, ctr.dy - rad * 0.72)
          ..lineTo(ctr.dx + rad * 0.22, ctr.dy - rad * 0.72)
          ..lineTo(ctr.dx + rad * 0.22, ctr.dy + rad * 0.35)
          ..lineTo(ctr.dx, ctr.dy + rad * 0.62)
          ..lineTo(ctr.dx - rad * 0.22, ctr.dy + rad * 0.35)
          ..close();
        canvas.drawPath(
            stripe, Paint()..color = Colors.white.withValues(alpha: 0.35));
        canvas.drawPath(
            shield,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = t.accentDark);
        break;
      case 7: // Dice Cube — mini die in your color.
        final cube = RRect.fromRectAndRadius(
            Rect.fromCircle(center: ctr, radius: rad * 0.95),
            Radius.circular(rad * 0.28));
        canvas.drawRRect(
            cube,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, t.woodDeep],
              ).createShader(cube.outerRect));
        // fixed five-pip face
        for (final pp in [
          [-0.4, -0.4],
          [0.4, -0.4],
          [0.0, 0.0],
          [-0.4, 0.4],
          [0.4, 0.4]
        ]) {
          canvas.drawCircle(
              Offset(ctr.dx + rad * pp[0], ctr.dy + rad * pp[1]),
              rad * 0.13,
              Paint()..color = Colors.white.withValues(alpha: 0.92));
        }
        canvas.drawRRect(
            cube,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.5));
        break;
      case 8: // Flower — six wooden petals.
        for (int i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawCircle(
              Offset(ctr.dx + rad * 0.52 * cos(a),
                  ctr.dy + rad * 0.52 * sin(a)),
              rad * 0.42,
              Paint()..color = color);
        }
        canvas.drawCircle(
            ctr, rad * 0.4, Paint()..color = t.accentLight);
        canvas.drawCircle(
            ctr,
            rad * 0.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = t.accentDark);
        canvas.drawCircle(
            ctr + Offset(-rad * 0.12, -rad * 0.14),
            rad * 0.12,
            Paint()..color = Colors.white.withValues(alpha: 0.8));
        break;
      case 9: // Shell — scallop carving.
        final shell = Path()
          ..moveTo(ctr.dx, ctr.dy + rad * 0.9)
          ..quadraticBezierTo(ctr.dx - rad * 1.05, ctr.dy + rad * 0.25,
              ctr.dx - rad * 0.8, ctr.dy - rad * 0.55)
          ..quadraticBezierTo(ctr.dx - rad * 0.4, ctr.dy - rad * 0.95,
              ctr.dx, ctr.dy - rad * 0.95)
          ..quadraticBezierTo(ctr.dx + rad * 0.4, ctr.dy - rad * 0.95,
              ctr.dx + rad * 0.8, ctr.dy - rad * 0.55)
          ..quadraticBezierTo(ctr.dx + rad * 1.05, ctr.dy + rad * 0.25,
              ctr.dx, ctr.dy + rad * 0.9)
          ..close();
        canvas.drawPath(shell, Paint()..color = color);
        // ridges fanning from the hinge
        for (final ra in [-0.5, -0.25, 0.0, 0.25, 0.5]) {
          canvas.drawLine(
              Offset(ctr.dx, ctr.dy + rad * 0.9),
              Offset(ctr.dx + rad * 1.6 * sin(ra),
                  ctr.dy + rad * 0.9 - rad * 1.7 * cos(ra)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = Colors.white.withValues(alpha: 0.4));
        }
        canvas.drawPath(
            shell,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.45));
        break;
      case 10: // Coin — minted brass coin.
        canvas.drawCircle(ctr, rad, Paint()..color = t.accent);
        canvas.drawCircle(
            ctr, rad * 0.78, Paint()..color = t.accentDark);
        canvas.drawCircle(
            ctr,
            rad * 0.78,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = t.accentLight.withValues(alpha: 0.8));
        // embossed star
        final cstar = Path();
        for (int i = 0; i < 10; i++) {
          final rr = (i % 2 == 0) ? rad * 0.42 : rad * 0.18;
          final a = -pi / 2 + i * pi / 5;
          final px = ctr.dx + rr * cos(a);
          final py = ctr.dy + rr * sin(a);
          if (i == 0) {
            cstar.moveTo(px, py);
          } else {
            cstar.lineTo(px, py);
          }
        }
        cstar.close();
        canvas.drawPath(
            cstar, Paint()..color = t.accentLight.withValues(alpha: 0.9));
        // player color dot at the rim
        canvas.drawCircle(
            Offset(ctr.dx, ctr.dy - rad * 0.62),
            rad * 0.16,
            Paint()..color = color);
        break;
      case 11: // Pawn — classic silhouette.
        // head
        canvas.drawCircle(
            Offset(ctr.dx, ctr.dy - rad * 0.55),
            rad * 0.42,
            Paint()..color = color);
        // collar
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(ctr.dx, ctr.dy - rad * 0.05),
                    width: rad * 1.0,
                    height: rad * 0.28),
                Radius.circular(rad * 0.14)),
            Paint()..color = color);
        // body
        final body = Path()
          ..moveTo(ctr.dx - rad * 0.42, ctr.dy + rad * 0.08)
          ..quadraticBezierTo(ctr.dx - rad * 0.5, ctr.dy + rad * 0.7,
              ctr.dx - rad * 0.72, ctr.dy + rad * 0.85)
          ..lineTo(ctr.dx + rad * 0.72, ctr.dy + rad * 0.85)
          ..quadraticBezierTo(ctr.dx + rad * 0.5, ctr.dy + rad * 0.7,
              ctr.dx + rad * 0.42, ctr.dy + rad * 0.08)
          ..close();
        canvas.drawPath(body, Paint()..color = color);
        // sheen
        canvas.drawCircle(
            Offset(ctr.dx - rad * 0.18, ctr.dy - rad * 0.68),
            rad * 0.12,
            Paint()..color = Colors.white.withValues(alpha: 0.7));
        // outline
        final outline = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.black.withValues(alpha: 0.5);
        canvas.drawCircle(
            Offset(ctr.dx, ctr.dy - rad * 0.55), rad * 0.42, outline);
        canvas.drawPath(body, outline);
        break;
      default: // Royal Orb — glossy lacquered pawn orb.
        final bodyRect = Rect.fromCircle(center: ctr, radius: rad);
        canvas.drawCircle(ctr, rad, Paint()..color = color);
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
                  Colors.black.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.45, 1.0],
              ).createShader(bodyRect));
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black.withValues(alpha: 0.5));
        canvas.drawCircle(
            ctr + Offset(-rad * 0.25, -rad * 0.25),
            rad * 0.22,
            Paint()..color = Colors.white.withValues(alpha: 0.75));
    }
  }

  void _drawGlyph(
      Canvas canvas, String glyph, Offset center, double size, Color color) {
    final tp = TextPainter(
      text:
          TextSpan(text: glyph, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ParlorBoardPainter old) => true;
}
