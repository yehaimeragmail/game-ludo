import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Ludo — all sounds synthesized in code as WAV bytes.
/// No asset files. Warm, physical, parlor-appropriate sounds.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicBusy] guard serializes play/stop so rapid calls (menu in/out,
///   pause/resume, toggles) can never leave the player in a half-started state.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class ParlorAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine.
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  ParlorAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _knock() {
    // Wooden knock: low thump + short click.
    final n = (_rate * 0.14).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005) *
          (0.9 * sin(2 * pi * 170 * t) * exp(-t * 30) +
              0.5 * sin(2 * pi * 340 * t) * exp(-t * 55) +
              0.25 * (_rand.nextDouble() * 2 - 1) * exp(-t * 120));
    }
    return out;
  }

  List<double> _diceRattle() {
    final n = (_rate * 0.35).round();
    final out = List<double>.filled(n, 0);
    for (int burst = 0; burst < 5; burst++) {
      final start = (n * burst / 6).round();
      final len = (_rate * 0.05).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += (_rand.nextDouble() * 2 - 1) *
            exp(-t * 90) *
            (0.5 + 0.5 * sin(2 * pi * 900 * t));
      }
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0)); // slow swell in/out
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Warm Am – F – C – G parlor pad, 16s loop.
        final seq = [
          [220.0, 261.63, 329.63], // Am
          [174.61, 220.0, 261.63], // F
          [261.63, 329.63, 392.0], // C
          [196.0, 246.94, 293.66], // G
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Gentle pentatonic plucks over a soft drone, 12s loop.
        final drone = _padChord([130.81, 196.0], 12.0);
        final plucks = [
          392.0,
          440.0,
          523.25,
          587.33,
          523.25,
          440.0,
          392.0,
          329.63
        ];
        final n = (_rate * 12).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.5, harmonics: 0.35);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.35;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> dice() => _play(_clip('dice', _diceRattle));
  Future<void> move() => _play(_clip('move', _knock));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> capture() =>
      _play(_clip('capture', () => _tone(620, 0.28, freqEnd: 150)));
  Future<void> tokenHome() =>
      _play(_clip('home', () => _tone(520, 0.2, freqEnd: 780)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Serialized: overlapping calls collapse
  /// into one, and re-requesting the current track is a no-op.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (!musicOn || _disposed) return;
    if (_musicBusy) return;
    if (_currentTrack == track) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    _musicBusy = true;
    try {
      await _music.stop();
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    if (_disposed) return;
    // Wait for any in-flight start to finish first, then stop.
    for (int i = 0; i < 20 && _musicBusy; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
