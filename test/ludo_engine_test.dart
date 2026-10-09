import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/engine/ludo_engine.dart';

/// RULES.md §13 test cases + regression tests for the exemplar fixes.
///
/// The engine owns its turn timers; tests drive the public API and wait out
/// the (short) phase durations. `forcedRoll` makes rolls deterministic.
LudoEngine makeEngine({int players = 2, bool bots = false}) {
  return LudoEngine(
    players: [
      for (int i = 0; i < players; i++)
        LudoPlayer(
          name: 'P$i',
          color: [Colors.red, Colors.blue, Colors.green, Colors.yellow][i],
          isBot: bots,
        ),
    ],
  );
}

/// Roll with a forced value and wait for the settle.
Future<void> rollForced(LudoEngine e, int value) async {
  e.forcedRoll = value;
  e.roll();
  await Future.delayed(const Duration(milliseconds: 1350));
}

/// Wait for a move animation to finish (max single-move duration).
Future<void> waitAnim(LudoEngine e) async {
  await Future.delayed(const Duration(milliseconds: 2100));
}

void main() {
  test('1. Roll 6 with all tokens in base → token enters, extra roll', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    await rollForced(e, 6);
    expect(e.dice, 6);
    expect(e.movable.length, 4);
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 0); // on start square
    expect(e.turn, 0); // extra roll: same player
    expect(e.phase, Phase.awaitingRoll);
  });

  test('2. Roll 3 with token on start → moves exactly 3', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    e.steps[0][0] = 0;
    await rollForced(e, 3);
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 3);
    expect(e.turn, 1); // no extra: turn passes
  });

  test('3. Capture on non-safe square → rival to base + extra roll', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    // P0 token at step 4 → track idx 4. P1 (seat 2) token at step 31 → idx 5.
    e.steps[0][0] = 4;
    e.steps[1][0] = 31;
    await rollForced(e, 1);
    expect(e.movable, contains(0));
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 5);
    expect(e.steps[1][0], -1); // captured back to base
    expect(e.turn, 0); // capture grants extra roll
  });

  test('4. Landing on star square → no capture, coexist', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    // idx 8 is a star. P0 at step 7 → idx 7; P1 (seat 2) at step 34 → idx 8.
    e.steps[0][0] = 7;
    e.steps[1][0] = 34;
    await rollForced(e, 1);
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 8);
    expect(e.steps[1][0], 34); // not captured
    expect(e.turn, 1); // no extra roll
  });

  test('5. Three consecutive sixes → turn forfeited', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    for (int r = 0; r < 2; r++) {
      await rollForced(e, 6);
      e.moveToken(e.movable.first);
      await waitAnim(e);
      expect(e.turn, 0); // extra rolls keep the turn
    }
    await rollForced(e, 6);
    // Forfeit: no move allowed, turn passes after a beat.
    expect(e.dice, 0);
    expect(e.movable, isEmpty);
    await Future.delayed(const Duration(milliseconds: 1500));
    expect(e.turn, 1);
    expect(e.sixStreak, 0);
  });

  test('6. Overshoot home → that token cannot move', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    e.steps[0][0] = 54; // 2 away; needs exact roll
    await rollForced(e, 3);
    expect(e.movable, isEmpty); // no legal moves at all
    await Future.delayed(const Duration(milliseconds: 1400));
    expect(e.turn, 1); // turn passes automatically
  });

  test('7. Exact roll into home → token home + extra roll', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    e.steps[0][0] = 55;
    await rollForced(e, 1);
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 56);
    expect(e.players[0].homeCount, 1);
    expect(e.turn, 0); // homing grants extra roll
  });

  test('8. Two same-color tokens block opponents', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    // P0 block at idx 10 (steps 10,10). P1 (seat 2) at step 35 → dest idx 10.
    e.steps[0][0] = 10;
    e.steps[0][1] = 10;
    e.steps[1][0] = 35;
    // Switch to P1's turn manually via two passes is slow; instead verify
    // the block directly: it is P0's turn, so check canMove-style logic by
    // simulating P1: temporarily set turn.
    e.turn = 1;
    e.phase = Phase.awaitingRoll;
    await rollForced(e, 1);
    expect(e.movable, isEmpty); // blocked: cannot land on the block
  });

  test('9. All 4 tokens home → win immediately', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    e.steps[0] = [56, 56, 56, 55];
    await rollForced(e, 1);
    e.moveToken(3);
    await waitAnim(e);
    expect(e.over, isTrue);
    expect(e.winner, 0);
    expect(e.phase, Phase.over);
  });

  test('10. No legal moves → turn passes with no state change', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    // All in base, roll != 6.
    await rollForced(e, 4);
    expect(e.movable, isEmpty);
    final before = e.steps.map((s) => s.join(',')).join('|');
    await Future.delayed(const Duration(milliseconds: 1400));
    expect(e.turn, 1);
    expect(e.steps.map((s) => s.join(',')).join('|'), before);
  });

  test('Bot turns auto-play without stuck states', () async {
    final e = makeEngine(players: 2, bots: true);
    addTearDown(e.dispose);
    // Let two bots play for a while; the watchdog + state machine must
    // keep the game moving (or finish it) — never freeze mid-phase.
    await Future.delayed(const Duration(seconds: 12));
    // Progress happened: turns advanced, a roll settled, or game over.
    expect(e.turnCount > 0 || e.lastRollBy != -1 || e.over, isTrue);
  });

  test('Pause freezes and resume recovers the turn', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    e.forcedRoll = 5;
    e.roll();
    await Future.delayed(const Duration(milliseconds: 300));
    expect(e.phase, Phase.rolling);
    e.setPaused(true);
    await Future.delayed(const Duration(milliseconds: 1400));
    expect(e.phase, Phase.rolling); // frozen, not settled
    e.setPaused(false);
    await Future.delayed(const Duration(milliseconds: 300));
    expect(e.phase, isNot(Phase.rolling)); // recovered
  });

  test('Safe squares: start squares are safe from capture', () async {
    final e = makeEngine();
    addTearDown(e.dispose);
    // P0 leaves base onto its start (idx 0, safe). P1 (seat 2) sits on
    // track idx 0 too? P1 cannot reach idx 0 as start... use idx 13 (P1's
    // start, safe): P0 token travels there.
    // P0 at step 12 → idx 12; P1 at step 39 → (26+39)%52 = 13.
    e.steps[0][0] = 12;
    e.steps[1][0] = 39;
    await rollForced(e, 1);
    e.moveToken(0);
    await waitAnim(e);
    expect(e.steps[0][0], 13);
    expect(e.steps[1][0], 39); // safe: no capture
  });
}
