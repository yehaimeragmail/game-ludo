import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/artisan_parlor.dart';
import '../theme/parlor_themes.dart';
import 'menu_screen.dart';

/// Launch splash: WAJIHA company moment → game splash with logo,
/// animated loading line, and credits.
class SplashScreen extends StatefulWidget {
  final ParlorAudio audio;
  final ParlorSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the company splash shows.
    widget.audio.prewarm();
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _companyDone = true);
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ParlorThemes.byId(widget.settings.themeId);
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B08),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _companyDone
            ? _GameSplash(
                key: const ValueKey('game'),
                theme: theme,
                loader: _loader,
              )
            : _CompanySplash(key: const ValueKey('company')),
      ),
    );
  }
}

/// Brief company splash moment with the official WAJIHA logo.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('company'),
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/wajiha_logo.png',
            width: 190,
            height: 190,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          const Text(
            'WAJIHA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
              color: Color(0xFFE8ECF5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final ParlorThemeDef theme;
  final AnimationController loader;
  const _GameSplash({super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return WoodBackdrop(
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/ludo_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Ludo', style: Parlor.display(52, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'THE ARTISAN PARLOR EDITION',
              style: Parlor.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Polishing the board…' : 'Ready!',
                      style: Parlor.body(13,
                          theme: theme,
                          color: theme.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Parlor.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
