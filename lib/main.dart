import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/artisan_parlor.dart';
import 'theme/parlor_themes.dart';

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
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Ludo',
        debugShowCheckedModeBanner: false,
        theme:
            Parlor.theme(ParlorThemes.byId(widget.settings.themeId)),
        home:
            SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
