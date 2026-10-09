import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + stats for Ludo. Survives app restarts.
///
/// Stores: audio toggles, player names (4 slots), theme/appearance choices,
/// game-mode setup (players, bots, difficulty), and lifetime stats.
class ParlorSettings extends ChangeNotifier {
  static const _kMusic = 'ludo_music_on';
  static const _kSfx = 'ludo_sfx_on';
  static const _kVolume = 'ludo_volume';
  static const _kPlayers = 'ludo_player_count';
  static const _kBots = 'ludo_bot_count';
  static const _kDifficulty = 'ludo_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNames = 'ludo_player_names'; // StringList, 4 entries
  static const _kTheme = 'ludo_theme_id';
  static const _kTokenShape = 'ludo_token_shape'; // 0 orb, 1 gem, 2 wood, 3 marble
  static const _kDiceStyle = 'ludo_dice_style'; // 0 ivory, 1 brass, 2 wood
  static const _kWins = 'ludo_wins';
  static const _kGames = 'ludo_games_played';
  static const _kBestTurns = 'ludo_best_turns';

  static const defaultNames = ['Ruby', 'Sapphire', 'Emerald', 'Amber'];

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int playerCount = 2;
  int botCount = 1;
  int difficulty = 1; // medium default
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int tokenShape = 0;
  int diceStyle = 0;
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
    playerCount = (p.getInt(_kPlayers) ?? 2).clamp(2, 4);
    botCount = (p.getInt(_kBots) ?? 1).clamp(0, 3);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    final names = p.getStringList(_kNames);
    if (names != null && names.length == 4) {
      playerNames = [
        for (int i = 0; i < 4; i++)
          names[i].trim().isEmpty ? defaultNames[i] : names[i].trim()
      ];
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    tokenShape = (p.getInt(_kTokenShape) ?? 0).clamp(0, 3);
    diceStyle = (p.getInt(_kDiceStyle) ?? 0).clamp(0, 2);
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
    await p.setInt(_kDifficulty, difficulty);
    await p.setStringList(_kNames, playerNames);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kTokenShape, tokenShape);
    await p.setInt(_kDiceStyle, diceStyle);
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

  /// Full mode setup: [players] 2..4 humans+bots, [bots] 0..players-1,
  /// [difficulty] 0 easy / 1 medium / 2 hard, plus which seats are bots.
  /// [botSeats] lists player indices that are bots (length == bots).
  List<int> botSeats = [1];

  Future<void> setSetup({
    required int players,
    required List<int> botSeats,
    required int difficulty,
  }) async {
    playerCount = players.clamp(2, 4);
    this.botSeats = [
      for (final s in botSeats)
        if (s >= 0 && s < playerCount) s
    ];
    botCount = this.botSeats.length.clamp(0, playerCount - 1);
    // Never allow all seats to be bots — at least one human must play.
    if (botCount >= playerCount) {
      this.botSeats = this.botSeats.sublist(0, playerCount - 1);
      botCount = this.botSeats.length;
    }
    this.difficulty = difficulty.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 3) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setTokenShape(int v) async {
    tokenShape = v.clamp(0, 3);
    notifyListeners();
    await _save();
  }

  Future<void> setDiceStyle(int v) async {
    diceStyle = v.clamp(0, 2);
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won.
  Future<void> recordGame({required bool humanWon, required int turns}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestTurns == 0 || turns < bestTurns) bestTurns = turns;
    }
    notifyListeners();
    await _save();
  }
}
