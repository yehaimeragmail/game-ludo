import 'package:flutter/material.dart';
import '../engine/ludo_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import '../theme/parlor_themes.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// Main menu — Artisan Parlor edition.
/// Logo, PLAY, mode setup (players / bots / difficulty), theme picker,
/// player renaming, tip jar, settings.
class MenuScreen extends StatefulWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TipJar _tipJar = TipJar();

  ParlorSettings get _s => widget.settings;
  ParlorThemeDef get _t => ParlorThemes.byId(_s.themeId);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _tipJar.init().then((_) {
      if (mounted) setState(() {});
    });
    _tipJar.lastThanks.addListener(_onThanks);
  }

  void _onThanks() {
    final msg = _tipJar.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Parlor.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _tipJar.lastThanks.value = null;
  }

  @override
  void dispose() {
    _tipJar.lastThanks.removeListener(_onThanks);
    _tipJar.dispose();
    super.dispose();
  }

  void _play() {
    widget.audio.gameStart();
    final colors = _t.playerColors;
    final players = [
      for (int i = 0; i < _s.playerCount; i++)
        LudoPlayer(
          name: _s.playerNames[i],
          color: colors[i],
          isBot: _s.botSeats.contains(i),
        ),
    ];
    final engine = LudoEngine(
      players: players,
      botDifficulty: BotDifficulty.values[_s.difficulty],
    );
    widget.audio.stopMusic();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WoodBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        Image.asset('assets/ludo_logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Ludo', style: Parlor.display(46, theme: t)),
                  Text(
                    'THE ARTISAN PARLOR EDITION',
                    style: Parlor.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  WoodButton(
                      label: '▶  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _ThemeCard(theme: t),
                  const SizedBox(height: 14),
                  _NamesCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, tipJar: _tipJar),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Wins: ${_s.wins}   •   Games: ${_s.gamesPlayed}${_s.bestTurns > 0 ? '   •   Best: ${_s.bestTurns} turns' : ''}',
                      style: Parlor.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Parlor.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, ParlorThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Parlor.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Roll a 6 to bring a token out of your base.',
                  '• Move tokens clockwise around the board.',
                  '• Land on a rival (off safe ★ squares) to capture it.',
                  '• Rolling 6, capturing, or homing a token = roll again.',
                  '• Three 6s in a row forfeits the turn.',
                  '• Exact roll needed to enter the home triangle.',
                  '• First to bring all 4 tokens home wins!',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Parlor.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: WoodButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final ParlorThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.woodMid, theme.woodDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Parlor.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Mode setup: player count, per-seat human/bot, bot difficulty.
class _ModeCard extends StatelessWidget {
  final ParlorThemeDef theme;
  const _ModeCard({required this.theme});

  static const difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Game Mode',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Players:', style: Parlor.body(15, theme: theme)),
              const SizedBox(width: 12),
              for (final c in [2, 3, 4])
                _Chip(
                  theme: theme,
                  label: '$c',
                  selected: s.playerCount == c,
                  onTap: () {
                    audio.click();
                    final bots = s.botSeats.where((b) => b < c).toList();
                    if (bots.length >= c) bots.removeLast();
                    s.setSetup(
                        players: c, botSeats: bots, difficulty: s.difficulty);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < s.playerCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.playerColors[i],
                      border:
                          Border.all(color: theme.accentLight, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.playerNames[i],
                      style: Parlor.body(15, theme: theme),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Chip(
                    theme: theme,
                    label: 'Human',
                    selected: !s.botSeats.contains(i),
                    onTap: () {
                      audio.click();
                      final bots = [...s.botSeats]..remove(i);
                      s.setSetup(
                          players: s.playerCount,
                          botSeats: bots,
                          difficulty: s.difficulty);
                    },
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    theme: theme,
                    label: 'Bot',
                    selected: s.botSeats.contains(i),
                    onTap: () {
                      audio.click();
                      final bots = {...s.botSeats, i}.toList();
                      s.setSetup(
                          players: s.playerCount,
                          botSeats: bots,
                          difficulty: s.difficulty);
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Bot skill:', style: Parlor.body(15, theme: theme)),
              const SizedBox(width: 12),
              for (int d = 0; d < 3; d++)
                _Chip(
                  theme: theme,
                  label: difficulties[d],
                  selected: s.difficulty == d,
                  onTap: () {
                    audio.click();
                    s.setSetup(
                        players: s.playerCount,
                        botSeats: s.botSeats,
                        difficulty: d);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Theme / appearance picker.
class _ThemeCard extends StatelessWidget {
  final ParlorThemeDef theme;
  const _ThemeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Parlor Style',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in ParlorThemes.all)
                GestureDetector(
                  onTap: () {
                    audio.click();
                    s.setTheme(th.id);
                  },
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: th.woodDeep.withValues(alpha: 0.7),
                      border: Border.all(
                        color: s.themeId == th.id
                            ? th.accentLight
                            : th.accent.withValues(alpha: 0.35),
                        width: s.themeId == th.id ? 3 : 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final c in th.playerColors)
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                      color: th.accentLight, width: 1),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          th.name,
                          style: Parlor.label(10, theme: th),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text('Token style:', style: Parlor.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < TokenShapes.names.length; i++)
                _Chip(
                  theme: theme,
                  label: TokenShapes.names[i],
                  selected: s.tokenShape == i,
                  onTap: () {
                    audio.click();
                    s.setTokenShape(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Dice style:', style: Parlor.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < DiceStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label: DiceStyles.names[i],
                  selected: s.diceStyle == i,
                  onTap: () {
                    audio.click();
                    s.setDiceStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the four player slots.
class _NamesCard extends StatelessWidget {
  final ParlorThemeDef theme;
  const _NamesCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return _Card(
      theme: theme,
      title: 'Player Names',
      child: Column(
        children: [
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.playerColors[i],
                      border:
                          Border.all(color: theme.accentLight, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NameField(
                      theme: theme,
                      index: i,
                      initial: s.playerNames[i],
                      onDone: (v) => s.setPlayerName(i, v),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Names show on dice trays, turn plaques and the winner podium.',
            style: Parlor.body(12,
                theme: theme, color: theme.ivory.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final ParlorThemeDef theme;
  final int index;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme,
      required this.index,
      required this.initial,
      required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        style: Parlor.body(15, theme: widget.theme),
        maxLength: 14,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Player ${widget.index + 1}',
          hintStyle: Parlor.body(14,
              theme: widget.theme,
              color: widget.theme.ivory.withValues(alpha: 0.4)),
        ),
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final ParlorThemeDef theme;
  final TipJar tipJar;
  const _SupportCard({required this.theme, required this.tipJar});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Ludo is 100% free. If it made you smile, a small tip keeps the parlor open!',
            style: Parlor.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (tipJar.products.isEmpty)
            Text(
              tipJar.error ?? 'Loading…',
              style: Parlor.body(13,
                  theme: theme,
                  color: theme.ivory.withValues(alpha: 0.6)),
            )
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tipJar.products)
                  _Chip(
                    theme: theme,
                    label: p.id == TipJar.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      tipJar.buy(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final ParlorThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.woodMid.withValues(alpha: 0.85),
            theme.woodDeep.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Parlor.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final ParlorThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Parlor.label(13,
              theme: theme, color: selected ? theme.woodDeep : theme.ivory),
        ),
      ),
    );
  }
}
