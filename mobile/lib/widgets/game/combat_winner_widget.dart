import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';

class CombatWinnerWidget extends StatelessWidget {
  const CombatWinnerWidget({
    required this.winnerName,
    required this.isEvasion,
    required this.onContinue,
    super.key,
  });

  final String winnerName;
  final bool isEvasion;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2C3E50) : Colors.white;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final accentColor = AppColors.accentHighlight(context);

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEvasion ? Icons.directions_run : Icons.emoji_events,
                size: 64,
                color: accentColor,
              ),
              const SizedBox(height: 20),
              Text(
                isEvasion
                    ? '$winnerName a évité le combat !'
                    : '$winnerName a remporté le combat !',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 12,
                  ),
                ),
                onPressed: onContinue,
                child: const Text(
                  'Continuer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
