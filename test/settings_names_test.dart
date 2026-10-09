import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/engine/ludo_engine.dart';
import 'package:ludo/services/settings_service.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// four names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the prefs round-trip plus the engine reload path, without needing
/// platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Zara', 'Ali', 'Bot Bob'];
    final decoded = ParlorSettings.decodePlayerNames(
      ParlorSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same player.
    for (int i = 0; i < 4; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      ParlorSettings.decodePlayerNames(null),
      ParlorSettings.defaultNames,
    );
    expect(
      ParlorSettings.decodePlayerNames('definitely not json'),
      ParlorSettings.defaultNames,
    );
    expect(
      ParlorSettings.decodePlayerNames('["only","two"]'),
      ParlorSettings.defaultNames,
    );
    expect(
      ParlorSettings.decodePlayerNames('{"a":1}'),
      ParlorSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded =
        ParlorSettings.decodePlayerNames('["Wajiha","","  ","Amber"]');
    expect(decoded, ['Wajiha', 'Sapphire', 'Emerald', 'Amber']);
  });

  test('engine rebuilt after "restart" shows the persisted names', () {
    // Simulate: user renamed slot 0, app restarted, setup screen + engine
    // rebuilt from the persisted value.
    const renamed = ['Wajiha', 'Sapphire', 'Emerald', 'Amber'];
    final persisted = ParlorSettings.decodePlayerNames(
      ParlorSettings.encodePlayerNames(renamed),
    );
    final engine = LudoEngine(
      players: [
        for (int i = 0; i < persisted.length; i++)
          LudoPlayer(
            name: persisted[i],
            color: [Colors.red, Colors.blue, Colors.green, Colors.yellow][i],
            isBot: i == 3,
          ),
      ],
    );
    addTearDown(engine.dispose);
    expect(engine.players[0].name, 'Wajiha');
    expect(engine.players[1].name, 'Sapphire');
    expect(engine.players[2].name, 'Emerald');
    expect(engine.players[3].name, 'Amber');
    // The rename also reaches turn narration (engine banner).
    expect(engine.banner, contains('Wajiha'));
  });
}
