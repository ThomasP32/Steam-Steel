import 'package:flutter/material.dart';

class PlayerLeftModalWidget extends StatelessWidget {
  const PlayerLeftModalWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50),
            border: Border.all(color: Colors.orange, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tous les joueurs ont abandonné.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'La partie est finie, vous serez redirigé.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
