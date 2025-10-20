import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/countdown_service.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
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
  bool _showChat = false;
  final GameService _gameService = GameService();
  final CountdownService _countdownService = CountdownService();
  StreamSubscription<dynamic>? _gameInitializedSub;
  StreamSubscription<dynamic>? _countdownSub;
  StreamSubscription<String>? _playerTurnSub;
  StreamSubscription<int>? _delaySub;
  dynamic _countdown = 30;
  static const int _turnDuration = 30;
  String _currentPlayerName = 'Aucun';
  int _startTurnCountdown = 3;
  bool _delayFinished = true;

  @override
  void initState() {
    super.initState();
    _listenToGameEvents();
    _listenToPlayerTurn();
    _listenToStartTurnDelay();
    _countdownService.initialize();
    _listenToCountdown();
  }

  void _listenToCountdown() {
    _countdownSub = _countdownService.countdownStream.listen((countdown) {
      setState(() {
        _countdown = countdown;
      });
    });
  }

  void _listenToPlayerTurn() {
    _playerTurnSub = SocketService().listen<String>('playerTurn').listen((
      playerName,
    ) {
      if (!mounted) return;
      DebugLogger.log(
        'GameScreen: playerTurn event -> $playerName',
        tag: 'GameScreen',
      );
      setState(() {
        _currentPlayerName = playerName;
      });
    });

    SocketService().listen<dynamic>('yourTurn').listen((data) {
      if (!mounted) return;
      DebugLogger.log('GameScreen: yourTurn event -> $data', tag: 'GameScreen');
      if (data is Map<String, dynamic>) {
        final playerName = data['name'] as String?;
        if (playerName != null) {
          setState(() {
            _currentPlayerName = playerName;
          });
        }
      }
    });

    SocketService().listen<dynamic>('startTurn').listen((_) {
      if (!mounted) return;
      DebugLogger.log('GameScreen: startTurn event', tag: 'GameScreen');
      final activePlayerName = _gameService.getActivePlayerName();
      DebugLogger.log(
        'GameScreen: active player from game -> $activePlayerName',
        tag: 'GameScreen',
      );
      if (activePlayerName != 'Aucun') {
        setState(() {
          _currentPlayerName = activePlayerName;
        });
      }
    });
  }

  void _listenToGameEvents() {
    _gameInitializedSub = SocketService()
        .listen<dynamic>('gameInitialized')
        .listen((data) {
          if (!mounted) return;
          if (data is Map<String, dynamic>) {
            _gameService.updateFromJson(data);
            final activePlayerName = _gameService.getActivePlayerName();
            if (activePlayerName != 'Aucun') {
              _currentPlayerName = activePlayerName;
            }
            setState(() {});
          }
        });
  }

  void _listenToStartTurnDelay() {
    _delaySub = SocketService().listen<int>('delay').listen((delay) {
      if (!mounted) return;
      DebugLogger.log('GameScreen: delay event -> $delay', tag: 'GameScreen');
      setState(() {
        _startTurnCountdown = delay;
        if (delay == 0) {
          _startTurnCountdown = 3;
          _delayFinished = true;
        } else {
          _delayFinished = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _gameInitializedSub?.cancel();
    _countdownSub?.cancel();
    _playerTurnSub?.cancel();
    _delaySub?.cancel();
    super.dispose();
  }

  void _toggleGameInfo() {
    setState(() {
      _showGameInfo = !_showGameInfo;
    });
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
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
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/backgroundcombat.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(child: _buildMapGrid()),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _buildTimer()),
          ),
          Positioned(left: 16, top: 16, child: _buildPlayerPanel()),
          Positioned(
            top: 18,
            right: 16,
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
                        onPressed: _toggleChat,
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFFC0C0C0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
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
                  ],
                ),
                if (_showGameInfo)
                  Container(
                    width: 400,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(20),
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
                        _buildInfoRow('Joueur Actif :', _currentPlayerName),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_showChat)
            ChatWidget(
              initiallyVisible: true,
              showToggleButton: false,
              onClose: () {
                setState(() {
                  _showChat = false;
                });
              },
            ),
          if (!_delayFinished)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    border: Border.all(color: Colors.orange, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "C'est au tour de $_currentPlayerName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _startTurnCountdown.toString(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final displayTime = _countdown.toString();
    final timeLeft = _countdown is int ? _countdown as int : 0;
    final progress = timeLeft / _turnDuration;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        border: Border.all(color: Colors.orange, width: 2),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: const Color(0xFF1A252F),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          Text(
            displayTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapGrid() {
    final game = _gameService.currentGame;
    if (game == null) {
      return const SizedBox.shrink();
    }

    final mapSize = game.mapSize;
    final gridSize = mapSize.x;
    const tileSize = 60.0;
    final needsInteractiveViewer = gridSize > 10;

    final gridWidget = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          gridSize,
          (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              gridSize,
              (col) => _buildTile(row, col, tileSize, game),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - 120;
        final availableWidth = constraints.maxWidth - 40;
        final gridTotalSize = gridSize * tileSize;

        // Calculate offset to center the grid
        final offsetX = (availableWidth - gridTotalSize) / 2;
        final offsetY = (availableHeight - gridTotalSize) / 2;

        return Padding(
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child:
              needsInteractiveViewer
                  ? SizedBox(
                    height: availableHeight,
                    width: availableWidth,
                    child: ClipRect(
                      child: InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 2,
                        child: Transform.translate(
                          offset: Offset(
                            offsetX > 0 ? offsetX : 0,
                            offsetY > 0 ? offsetY : 0,
                          ),
                          child: gridWidget,
                        ),
                      ),
                    ),
                  )
                  : gridWidget,
        );
      },
    );
  }

  Widget _buildTile(int row, int col, double tileSize, dynamic game) {
    final tile = game.tiles.cast<dynamic>().firstWhere(
      (t) => t.coordinate.x == row && t.coordinate.y == col,
      orElse: () => null,
    );

    final door = game.doorTiles.cast<dynamic>().firstWhere(
      (d) => d.coordinate.x == row && d.coordinate.y == col,
      orElse: () => null,
    );

    final item = game.items.cast<dynamic>().firstWhere(
      (i) => i.coordinate.x == row && i.coordinate.y == col,
      orElse: () => null,
    );

    final startPoint = game.startTiles.cast<dynamic>().firstWhere(
      (s) => s.x == row && s.y == col,
      orElse: () => null,
    );

    final player = game.players.cast<dynamic>().firstWhere((p) {
      if (p.position == null) return false;
      final pos = p.position as List;
      return pos.isNotEmpty && pos[0].x == row && pos[0].y == col;
    }, orElse: () => null);

    String? tileAsset;
    if (door != null) {
      final isOpened = door.isOpened as bool? ?? false;
      tileAsset =
          isOpened
              ? 'lib/assets/tiles/door_opened.jpg'
              : 'lib/assets/tiles/door_closed.jpg';
    } else if (tile != null) {
      final category = tile.category.toString().split('.').last;

      switch (category) {
        case 'water':
          tileAsset = 'lib/assets/tiles/water.png';
        case 'ice':
          tileAsset = 'lib/assets/tiles/ice1.jpg';
        case 'wall':
          tileAsset = 'lib/assets/tiles/wall.png';
        case 'floor':
        default:
          tileAsset = 'lib/assets/tiles/floor.png';
      }
    } else {
      tileAsset = 'lib/assets/tiles/floor.png';
    }

    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF654321)),
      ),
      child: Stack(
        children: [
          // Base tile
          Image.asset(
            tileAsset,
            width: tileSize,
            height: tileSize,
            fit: BoxFit.cover,
          ),

          // Starting point overlay
          if (startPoint != null)
            Center(
              child: Image.asset(
                'lib/assets/tiles/startingpoint.png',
                width: tileSize * 0.6,
                height: tileSize * 0.6,
                fit: BoxFit.contain,
              ),
            ),

          // Item overlay
          if (item != null)
            Center(
              child: Icon(
                Icons.star,
                color: Colors.yellow,
                size: tileSize * 0.4,
              ),
            ),

          // Player overlay
          if (player != null)
            Center(
              child: CircleAvatar(
                radius: tileSize * 0.3,
                backgroundColor: Colors.transparent,
                child: Image.asset(
                  'lib/assets/pixelcharacters/${player.avatar.value}_pixelated.png',
                  width: tileSize,
                  height: tileSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel() {
    final player = PlayerService().player;
    final specs = player.specs;

    return Container(
      width: 300,
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
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF3A4F5F),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'lib/assets/previewcharacters/${player.avatar.value}_preview.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatBar('❤️', 'Vie', specs.life, specs.life),
          const SizedBox(height: 8),
          _buildStatBar('⚡', 'Vitesse', specs.speed, specs.speed),
          const SizedBox(height: 8),
          _buildStatBar('⚔️', 'Attaque', specs.attack, specs.attack),
          const SizedBox(height: 8),
          _buildStatBar('🛡️', 'Défense', specs.defense, specs.defense),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDiceIndicator('Attaque', specs.attackBonus.value),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDiceIndicator('Défense', specs.defenseBonus.value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Inventaire',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildInventorySlot()),
              const SizedBox(width: 8),
              Expanded(child: _buildInventorySlot()),
            ],
          ),
          const SizedBox(height: 16),
          _buildCounter('Actions restantes', specs.actions),
          const SizedBox(height: 8),
          _buildCounter('Mouvements restants', specs.movePoints),
        ],
      ),
    );
  }

  Widget _buildStatBar(String icon, String label, int current, int max) {
    final percentage = max > 0 ? current / max : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            Text(
              '$current/$max',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF1A252F),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiceIndicator(String label, int value) {
    final diceImage = value == 4 ? 'd4.png' : 'd6.png';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A252F),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('lib/assets/icons/$diceImage', width: 24, height: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySlot() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1A252F),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Text(
          'Vide',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
