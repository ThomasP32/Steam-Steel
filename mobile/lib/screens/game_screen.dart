import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({required this.gameId, required this.mapName, super.key});
  final String gameId;
  final String mapName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Screen')),
      body: const Center(child: Text('Welcome to the Game!')),
    );
  }
}
