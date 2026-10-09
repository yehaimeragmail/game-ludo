import 'package:flutter/material.dart';
import '../engine/ludo_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// Main menu — the parlor entrance: carved plaque, wooden play token,
/// player setup carved into brass-rimmed selectors.
class MenuScreen extends StatefulWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late int _players;
  late int _bots;

  @override
  void initState() {
    super.initState();
    _players = widget.settings.playerCount;
    _bots = widget.settings.botCount.clamp(0, _players - 1);
    widget.audio.startMenuMusic();
  }

  void _clampBots() {
    if (_bots > _players - 1) _bots = _players - 1;
  }

  Future<void> _play() async {
    await widget.audio.gameStart();
    await widget.settings.setSetup(players: _players, bots: _bots);
    final players = <LudoPlayer>[];
    const botNames = ['Baron', 'Duchess', 'Earl', 'Countess'];
    for (int i = 0; i < _players; i++) {
      final isBot = i >= _players - _bots;
      players.add(LudoPlayer(
        name: isBot ? '${botNames[i % botNames.length]} (Bot)' : 'Player ${i + 1}',
        color: Parlor.playerColors[i],
        isBot: isBot,
      ));
    }
    await widget.audio.stopMusic();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: LudoEngine(players: players),
        audio: widget.audio,
        settings: widget.settings,
      ),
    ));
    if (mounted) widget.audio.startMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    return WoodBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Carved title plaque.
                  const BrassPlaque(
                    title: 'LUDO',
                    subtitle: 'The classic race, in heirloom walnut & brass',
                  ),
                  const SizedBox(height: 26),
                  // Player count selector.
                  Text('PLAYERS', style: Parlor.label(13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [2, 3, 4].map((n) {
                      final sel = _players == n;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            setState(() {
                              _players = n;
                              _clampBots();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: sel
                                    ? const [
                                        Parlor.brassLight,
                                        Parlor.brass,
                                        Parlor.brassDark
                                      ]
                                    : const [
                                        Parlor.walnutMid,
                                        Parlor.walnutDeep
                                      ],
                              ),
                              border: Border.all(
                                color: sel
                                    ? Parlor.ivory
                                    : Parlor.brass.withValues(alpha: 0.5),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Parlor.shadow.withValues(alpha: 0.7),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text('$n',
                                style: Parlor.display(24,
                                    color: sel
                                        ? Parlor.walnutDeep
                                        : Parlor.ivory)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  // Bot count selector.
                  Text('BOT OPPONENTS', style: Parlor.label(13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_players, (n) {
                      final sel = _bots == n;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            setState(() => _bots = n);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: sel
                                  ? Parlor.brassDark
                                  : Parlor.walnutDeep.withValues(alpha: 0.7),
                              border: Border.all(
                                color: sel
                                    ? Parlor.brassLight
                                    : Parlor.brass.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text('$n',
                                style: Parlor.body(17,
                                    color: sel
                                        ? Parlor.ivory
                                        : Parlor.ivoryDim)),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  WoodButton(label: 'PLAY', onTap: _play, fontSize: 22),
                  const SizedBox(height: 14),
                  WoodButton(
                    label: 'How to Play',
                    width: 240,
                    fontSize: 16,
                    onTap: () {
                      widget.audio.click();
                      _showHowTo(context);
                    },
                  ),
                  const SizedBox(height: 14),
                  WoodButton(
                    label: 'Settings',
                    width: 240,
                    fontSize: 16,
                    onTap: () async {
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
                  const SizedBox(height: 24),
                  if (widget.settings.gamesPlayed > 0)
                    Text(
                      '${widget.settings.wins} victories in ${widget.settings.gamesPlayed} games'
                      '${widget.settings.bestTurns > 0 ? '  •  best ${widget.settings.bestTurns} turns' : ''}',
                      style: Parlor.label(12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Parlor.walnutMid,
            border: Border.all(color: Parlor.brass, width: 2.5),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to Play', style: Parlor.display(22)),
                const SizedBox(height: 12),
                ...[
                  'Tap the ivory dice, then tap a glowing token to move it.',
                  'Roll a 6 to march a token out of your base.',
                  'Land on a rival\'s token to capture it back to base — unless it rests on a ★ safe square.',
                  'Two of your tokens on one square form a block rivals cannot pass.',
                  'Three sixes in a row forfeits your turn!',
                  'You need the EXACT roll to enter the home triangle.',
                  'Bonus roll on a 6, a capture, or bringing a token home.',
                  'First to bring all 4 tokens home wins the parlor crown.',
                ].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('◆  ',
                              style: TextStyle(color: Parlor.brass)),
                          Expanded(
                              child: Text(t, style: Parlor.body(14))),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Center(
                  child: WoodButton(
                    label: 'Got it',
                    width: 180,
                    fontSize: 16,
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
