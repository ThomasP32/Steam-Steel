import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';

class ObservationModeModalWidget extends StatelessWidget {
  const ObservationModeModalWidget({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
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
              Icon(
                Icons.remove_red_eye,
                color: AppColors.accentHighlight(context),
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                'Mode Observation',
                style: TextStyle(
                  color: AppColors.accentHighlight(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Text(
                'Vous pouvez continuer à observer la partie.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
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
