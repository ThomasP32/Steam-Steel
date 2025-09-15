import 'package:flutter/material.dart';

class MainPageFooter extends StatelessWidget {
  const MainPageFooter({super.key});

  static const String teamNumber = 'Équipe 106';
  static const List<String> developers = [
    'Maude Racine',
    'Noémie Hélias',
    'Thomas Perron Duveau',
    'Camille Ménard',
    'Cerine Ouchene',
    'Valentine Champvillard',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            teamNumber,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            developers.join(', '),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
