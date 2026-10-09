import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/menu_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/artisan_parlor.dart';

// Old lib/game_screen.dart (GameShell edition) is retired by this rebuild.
// Game logic lives on in lib/engine/ludo_engine.dart.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = ParlorSettings();
  await settings.load();
  final audio = ParlorAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(LudoApp(settings: settings, audio: audio));
}

class LudoApp extends StatefulWidget {
  final ParlorSettings settings;
  final ParlorAudio audio;
  const LudoApp({super.key, required this.settings, required this.audio});

  @override
  State<LudoApp> createState() => _LudoAppState();
}

class _LudoAppState extends State<LudoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Duck music when backgrounded; game screens auto-pause themselves.
    if (state == AppLifecycleState.paused) {
      widget.audio.stopMusic();
    } else if (state == AppLifecycleState.resumed &&
        widget.settings.musicOn) {
      widget.audio.startMenuMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo',
      debugShowCheckedModeBanner: false,
      theme: Parlor.theme(),
      home: MenuScreen(audio: widget.audio, settings: widget.settings),
    );
  }
}
