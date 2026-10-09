import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/parlor_themes.dart';

/// Persisted settings + stats for Ludo. Survives app restarts.
///
/// Stores: audio toggles, player names (4 slots), theme/appearance choices
/// (incl. custom theme colors), game-mode setup (players, bots, difficulty),
/// Pro unlock state, and lifetime stats.
class ParlorSettings extends ChangeNotifier {
  static const _kMusic = 'ludo_music_on';
  static const _kSfx = 'ludo_sfx_on';
  static const _kVolume = 'ludo_volume';
  static const _kPlayers = 'ludo_player_count';
  static const _kBots = 'ludo_bot_count';
  static const _kDifficulty = 'ludo_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNames = 'ludo_player_names'; // StringList, 4 entries
  static const _kTheme = 'ludo_theme_id';
  static const _kTokenShape = 'ludo_token_shape';
  static const _kDiceStyle = 'ludo_dice_style';
  static const _kWins = 'ludo_wins';
  static const _kGames = 'ludo_games_played';
  static const _kBestTurns = 'ludo_best_turns';
  static const _kIsPro = 'ludo_is_pro';
  static const _kCustomPrefix = 'ludo_custom_';

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
  bool isPro = false;

  /// Custom theme colors (ARGB ints). Defaults mirror the Classic Parlor.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'woodDark': 0xFF3B2416,
    'woodMid': 0xFF5C3A21,
    'woodDeep': 0xFF241309,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'accentDark': 0xFF8A6D1A,
    'ivory': 0xFFF5EFE0,
    'felt': 0xFF1E4D3B,
    'trackLight': 0xFFEFE3C8,
    'trackDark': 0xFFE4D3A8,
    'pc0': 0xFFA31621,
    'pc1': 0xFF1D4E9E,
    'pc2': 0xFF1B7A4D,
    'pc3': 0xFFD99A2B,
  };

  /// Builds the user-designed custom theme from stored colors.
  ParlorThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return ParlorThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      woodDeep: c('woodDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      felt: c('felt'),
      trackLight: c('trackLight'),
      trackDark: c('trackDark'),
      playerColors: [c('pc0'), c('pc1'), c('pc2'), c('pc3')],
      playerColorNames: const ['One', 'Two', 'Three', 'Four'],
    );
  }

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
    tokenShape = (p.getInt(_kTokenShape) ?? 0).clamp(0, 11);
    diceStyle = (p.getInt(_kDiceStyle) ?? 0).clamp(0, 5);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestTurns = p.getInt(_kBestTurns) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
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
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  /// Called after load and whenever Pro status could have changed.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (ParlorThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (TokenShapes.isPro(tokenShape)) {
      tokenShape = 0;
      changed = true;
    }
    if (DiceStyles.isPro(diceStyle)) {
      diceStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
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
    // Hard mode is a Pro feature.
    if (!isPro && this.difficulty > 1) this.difficulty = 1;
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
    // Pro-only themes require Pro; silently ignore otherwise (UI shows lock).
    if (!isPro && ParlorThemes.isProTheme(id)) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setTokenShape(int v) async {
    v = v.clamp(0, TokenShapes.names.length - 1);
    if (!isPro && TokenShapes.isPro(v)) return;
    tokenShape = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDiceStyle(int v) async {
    v = v.clamp(0, DiceStyles.names.length - 1);
    if (!isPro && DiceStyles.isPro(v)) return;
    diceStyle = v;
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
