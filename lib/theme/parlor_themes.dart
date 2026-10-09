import 'package:flutter/material.dart';

/// Theme, token-shape and dice-style catalog for Ludo.
///
/// Every theme stays inside the Artisan Parlor material world (real wood,
/// brass/copper/silver, ivory, felt) — the variety comes from different
/// woods, metal accents, felt linings and player-color jewel tones.
class ParlorThemeDef {
  final String id;
  final String name;
  final Color woodDark;
  final Color woodMid;
  final Color woodDeep;
  final Color accent; // brass / copper / silver …
  final Color accentLight;
  final Color accentDark;
  final Color ivory;
  final Color felt;
  final Color trackLight;
  final Color trackDark;
  final List<Color> playerColors;
  final List<String> playerColorNames;

  const ParlorThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.trackLight,
    required this.trackDark,
    required this.playerColors,
    required this.playerColorNames,
  });
}

class ParlorThemes {
  static const List<ParlorThemeDef> all = [
    ParlorThemeDef(
      id: 'classic',
      name: 'Classic Parlor',
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF241309),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1E4D3B),
      trackLight: Color(0xFFEFE3C8),
      trackDark: Color(0xFFE4D3A8),
      playerColors: [
        Color(0xFFA31621),
        Color(0xFF1D4E9E),
        Color(0xFF1B7A4D),
        Color(0xFFD99A2B),
      ],
      playerColorNames: ['Ruby', 'Sapphire', 'Emerald', 'Amber'],
    ),
    ParlorThemeDef(
      id: 'mahogany',
      name: 'Royal Mahogany',
      woodDark: Color(0xFF4A1F14),
      woodMid: Color(0xFF6E2F1C),
      woodDeep: Color(0xFF2B1009),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF3D1F2E),
      trackLight: Color(0xFFF2E6CC),
      trackDark: Color(0xFFE6D2A6),
      playerColors: [
        Color(0xFFC0392B),
        Color(0xFF7D3C98),
        Color(0xFF1E8449),
        Color(0xFFB7950B),
      ],
      playerColorNames: ['Garnet', 'Amethyst', 'Jade', 'Topaz'],
    ),
    ParlorThemeDef(
      id: 'midnight',
      name: 'Midnight Library',
      woodDark: Color(0xFF1C2438),
      woodMid: Color(0xFF2C3A55),
      woodDeep: Color(0xFF101624),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF1B2A4A),
      trackLight: Color(0xFFE9E4D2),
      trackDark: Color(0xFFD5CDAE),
      playerColors: [
        Color(0xFFD64545),
        Color(0xFF4A90D9),
        Color(0xFF3FB97F),
        Color(0xFFE0A83C),
      ],
      playerColorNames: ['Candle', 'Moonstone', 'Fern', 'Lantern'],
    ),
    ParlorThemeDef(
      id: 'emerald',
      name: 'Emerald Club',
      woodDark: Color(0xFF2E3B22),
      woodMid: Color(0xFF4A5A34),
      woodDeep: Color(0xFF1A2312),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF0F3D2E),
      trackLight: Color(0xFFEFE8D2),
      trackDark: Color(0xFFDCD0A8),
      playerColors: [
        Color(0xFFB03A2E),
        Color(0xFF2E86C1),
        Color(0xFFD4AC0D),
        Color(0xFF8E44AD),
      ],
      playerColorNames: ['Claret', 'Steel', 'Ochre', 'Plum'],
    ),
    ParlorThemeDef(
      id: 'ivory',
      name: 'Ivory & Gold',
      woodDark: Color(0xFFEFE3C8),
      woodMid: Color(0xFFE2D0A6),
      woodDeep: Color(0xFFC9B586),
      accent: Color(0xFF9A7B1E),
      accentLight: Color(0xFFD4AF37),
      accentDark: Color(0xFF6E5514),
      ivory: Color(0xFF2E2118),
      felt: Color(0xFF2E5A44),
      trackLight: Color(0xFFFBF6E9),
      trackDark: Color(0xFFEFE0BC),
      playerColors: [
        Color(0xFFA31621),
        Color(0xFF1D4E9E),
        Color(0xFF1B7A4D),
        Color(0xFFB26A00),
      ],
      playerColorNames: ['Ruby', 'Sapphire', 'Emerald', 'Honey'],
    ),
    ParlorThemeDef(
      id: 'cherry',
      name: 'Cherry Wood',
      woodDark: Color(0xFF5A2A1A),
      woodMid: Color(0xFF7C3F24),
      woodDeep: Color(0xFF381408),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFDFC084),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFFF7EFE0),
      felt: Color(0xFF4A2E3F),
      trackLight: Color(0xFFF0E4C8),
      trackDark: Color(0xFFE3CCA0),
      playerColors: [
        Color(0xFFC0392B),
        Color(0xFF2471A3),
        Color(0xFF229954),
        Color(0xFFD4AC0D),
      ],
      playerColorNames: ['Poppy', 'Teal', 'Moss', 'Wheat'],
    ),
    ParlorThemeDef(
      id: 'copper',
      name: 'Walnut & Copper',
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      woodDeep: Color(0xFF241309),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3F2B1F),
      trackLight: Color(0xFFEFE3C8),
      trackDark: Color(0xFFE4D3A8),
      playerColors: [
        Color(0xFFA31621),
        Color(0xFF1F618D),
        Color(0xFF1E8449),
        Color(0xFFCA8A2B),
      ],
      playerColorNames: ['Ruby', 'Denim', 'Leaf', 'Bronze'],
    ),
    ParlorThemeDef(
      id: 'lodge',
      name: 'Forest Lodge',
      woodDark: Color(0xFF3E3226),
      woodMid: Color(0xFF5D4C36),
      woodDeep: Color(0xFF26201A),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      felt: Color(0xFF2F4A2A),
      trackLight: Color(0xFFEDE2C6),
      trackDark: Color(0xFFDCC99E),
      playerColors: [
        Color(0xFFB03A2E),
        Color(0xFF2E86C1),
        Color(0xFFE67E22),
        Color(0xFF7D6608),
      ],
      playerColorNames: ['Brick', 'River', 'Ember', 'Hay'],
    ),
  ];

  static ParlorThemeDef byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}

/// Token piece styles. 0 = Royal Orb, 1 = Facet Gem, 2 = Wood Disc, 3 = Marble.
class TokenShapes {
  static const names = ['Royal Orb', 'Facet Gem', 'Wood Disc', 'Marble'];
  static const descriptions = [
    'Glossy lacquered pawn orb',
    'Cut-gemstone token',
    'Turned wooden disc',
    'Swirled glass marble',
  ];
}

/// Dice styles. 0 = Ivory Classic, 1 = Brass Noble, 2 = Oak.
class DiceStyles {
  static const names = ['Ivory Classic', 'Brass Noble', 'Oak'];
  static const descriptions = [
    'Cold-cast ivory, engraved pips',
    'Dark bronze die, brass pips',
    'Oiled oak die, burned pips',
  ];
}
