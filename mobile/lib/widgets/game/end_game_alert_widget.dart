import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';

class EndGameAlertWidget extends StatelessWidget {
  const EndGameAlertWidget({
    required this.game,
    this.reason,
    super.key,
  });

  final GameClassic? game;
  final GameEndReason? reason;

  @override
  Widget build(BuildContext context) {
    final winnerName = _getWinnerName();
    final winMessage = _getEndGameMessage(winnerName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

  String _getWinnerName() {
    if (game == null || game!.players.isEmpty) {
      return 'Un joueur';
    }

    final winner = game!.players.firstWhere(
      (p) => p.isGameWinner,
      orElse: () => game!.players.first,
    );

    return winner.name.isNotEmpty ? winner.name : 'Un joueur';
  }

  String _getEndGameMessage(String winnerName) {
    if (reason == null) {
      return '$winnerName a gagné.';
    }

    switch (reason!) {
      case GameEndReason.victoryCtfFlag:
        return '$winnerName a capturé le drapeau';
      case GameEndReason.victoryCombatWins:
        return '$winnerName a gagné 3 combats';
      case GameEndReason.victoryElimination:
        return 'Tous les joueurs sont éliminés, $winnerName a gagné.';
      case GameEndReason.victoryLastPlayerStanding:
        return 'Tous les joueurs ont abandonné, $winnerName a gagné';
      default:
        return '$winnerName a gagné.';
    }
  }
}
