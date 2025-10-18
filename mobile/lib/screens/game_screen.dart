import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/widgets/chat_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.gameId, required this.mapName, super.key});
  final String gameId;
  final String mapName;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showGameInfo = false;
  final GameService _gameService = GameService();
  StreamSubscription<dynamic>? _gameInitializedSub;

  @override
  void initState() {
    super.initState();
    _listenToGameEvents();
  }

  void _listenToGameEvents() {
    _gameInitializedSub = SocketService()
        .listen<dynamic>('gameInitialized')
        .listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            _gameService.updateFromJson(data);
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _gameInitializedSub?.cancel();
    super.dispose();
  }

  void _toggleGameInfo() {
    setState(() {
      _showGameInfo = !_showGameInfo;
    });
  }

  void quitGame() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text(
            'Quitter la partie',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Voulez-vous vraiment quitter la partie?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                SocketService().send('leaveGame', widget.gameId);
                SocketService().disconnect();
                GoRouter.of(context).go('/');
              },
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/citybackground.png',
              fit: BoxFit.cover,
            ),
          ),
          // Game content
          const Center(
            child: Text(
              'Welcome to the Game!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: quitGame,
                        child: const Icon(
                          Icons.logout,
                          color: Color(0xFFC0C0C0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Info button
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _toggleGameInfo,
                        child: const Icon(
                          Icons.info_outline,
                          color: Color(0xFFC0C0C0),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showGameInfo)
                  Container(
                    width: 300,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      border: Border.all(color: Colors.orange, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(
                          child: Text(
                            'Informations de la partie',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Taille de la carte :',
                          _gameService.getMapSizeLabel(),
                        ),
                        const Divider(color: Colors.grey),
                        _buildInfoRow(
                          'Nombre de joueurs :',
                          '${_gameService.currentGame?.players.length ?? 0}',
                        ),
                        const Divider(color: Colors.grey),
                        _buildInfoRow(
                          'Joueur Actif :',
                          _gameService.getActivePlayerName(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const ChatWidget(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
