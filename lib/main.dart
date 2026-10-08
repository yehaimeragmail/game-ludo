import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const LudoApp());

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.cozyPaper,
      title: 'Ludo',
      tagline: 'Roll big, capture bigger, race all four tokens home! 🎲',
      emoji: '🎲',
      slug: 'ludo',
      howToPlay: '• Tap the dice, then tap a glowing token to move it\n'
          '• Roll a 6 to launch a token out of base\n'
          '• Land on a rival\'s token to send it back to base (💥 capture!)\n'
          '• ⭐ Star squares are safe — no captures there\n'
          '• You need the EXACT roll to enter the home triangle\n'
          '• Bonus turn on a 6, a capture, or bringing a token home\n'
          '• First to bring all 4 tokens home wins! 🏆',
      playerOptions: const [1, 2, 3, 4],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => LudoScreen(players: players, callbacks: cb),
    );
  }
}
