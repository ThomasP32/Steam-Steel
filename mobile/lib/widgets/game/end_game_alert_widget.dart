import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';

class EndGameAlertWidget extends StatelessWidget {
  const EndGameAlertWidget({required this.game, super.key});

  final GameClassic? game;

  @override
  Widget build(BuildContext context) {
    var winnerName = 'Un joueur';
    var winMessage = 'a gagné la partie';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (game != null && game!.players.isNotEmpty) {
      final winner = game!.players.firstWhere(
        (p) => p.isGameWinner,
        orElse: () => game!.players.first,
      );

      if (winner.isGameWinner) {
        winnerName = winner.name.isNotEmpty ? winner.name : 'Un joueur';
        final gameMode = game!.mode;

        if (gameMode == Mode.ctf) {
          winMessage = '$winnerName a capturé le drapeau';
        } else {
          winMessage = '$winnerName a gagné';
        }
      }
    }

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C3E50) : Colors.white,
            border: Border.all(
              color: AppColors.accentHighlight(context),
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'La partie est finie, vous serez redirigé.',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
