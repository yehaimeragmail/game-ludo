import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + stats for Ludo. Survives app restarts.
class ParlorSettings extends ChangeNotifier {
  static const _kMusic = 'ludo_music_on';
  static const _kSfx = 'ludo_sfx_on';
  static const _kVolume = 'ludo_volume';
  static const _kPlayers = 'ludo_player_count';
  static const _kBots = 'ludo_bot_count';
  static const _kWins = 'ludo_wins';
  static const _kGames = 'ludo_games_played';
  static const _kBestTurns = 'ludo_best_turns';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int playerCount = 2;
  int botCount = 1;
  int wins = 0;
  int gamesPlayed = 0;
  int bestTurns = 0; // fewest turns to win (0 = none yet)

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    playerCount = p.getInt(_kPlayers) ?? 2;
    botCount = p.getInt(_kBots) ?? 1;
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestTurns = p.getInt(_kBestTurns) ?? 0;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kPlayers, playerCount);
    await p.setInt(_kBots, botCount);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestTurns, bestTurns);
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setSetup({required int players, required int bots}) async {
    playerCount = players.clamp(2, 4);
    botCount = bots.clamp(0, playerCount - 1);
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won.
  Future<void> recordGame(
      {required bool humanWon, required int turns}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestTurns == 0 || turns < bestTurns) bestTurns = turns;
    }
    notifyListeners();
    await _save();
  }
}
