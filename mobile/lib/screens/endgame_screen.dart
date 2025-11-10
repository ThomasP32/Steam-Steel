import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/endgame_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';

class EndgameScreen extends StatefulWidget {
  const EndgameScreen({required this.game, required this.gameId, super.key});

  final GameClassic game;
  final String gameId;

  @override
  State<EndgameScreen> createState() => _EndgameScreenState();
}

class _EndgameScreenState extends State<EndgameScreen> {
  String _sortBy = 'victories';
  bool _sortAscending = false;
  final _endgameService = EndgameService();

  @override
  void initState() {
    super.initState();
    final socketService = SocketService();
    final currentSocketId = socketService.socketId ?? '';
    if (currentSocketId.isNotEmpty) {
      _endgameService.updateUserStats(widget.game, currentSocketId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = _getSortedPlayers();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/backgroundcombat.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FIN DE PARTIE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [FriendButton(), ChatWidget()],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatsTable(sortedPlayers),
                        const SizedBox(height: 24),
                        _buildGlobalStats(),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34495E),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                          ),
                          onPressed: _navigateToMainMenu,
                          child: const Text(
                            'Menu principal',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Player> _getSortedPlayers() {
    final players = List<Player>.from(widget.game.players)..sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'combats':
          comparison = a.specs.nCombats.compareTo(b.specs.nCombats);
        case 'evasions':
          comparison = a.specs.nEvasions.compareTo(b.specs.nEvasions);
        case 'victories':
          comparison = a.specs.nVictories.compareTo(b.specs.nVictories);
        case 'defeats':
          comparison = a.specs.nDefeats.compareTo(b.specs.nDefeats);
        case 'lifeLost':
          comparison = a.specs.nLifeLost.compareTo(b.specs.nLifeLost);
        case 'lifeTaken':
          comparison = a.specs.nLifeTaken.compareTo(b.specs.nLifeTaken);
        case 'items':
          comparison = a.specs.nItemsUsed.compareTo(b.specs.nItemsUsed);
        case 'tiles':
          comparison = a.visitedTiles.length.compareTo(b.visitedTiles.length);
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return players;
  }

  Widget _buildStatsTable(List<Player> players) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withValues(alpha: 0.95),
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [_buildTableHeader(), ...players.map(_buildPlayerRow)],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF34495E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Joueur', 'name', flex: 2),
          _buildHeaderCell('Combats', 'combats'),
          _buildHeaderCell('Évasions', 'evasions'),
          _buildHeaderCell('Victoires', 'victories'),
          _buildHeaderCell('Défaites', 'defeats'),
          _buildHeaderCell('Vie perdue', 'lifeLost'),
          _buildHeaderCell('Vie infligée', 'lifeTaken'),
          _buildHeaderCell('Objets', 'items'),
          _buildHeaderCell('Tuiles %', 'tiles'),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String sortKey, {int flex = 1}) {
    final isActive = _sortBy == sortKey;

    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortBy == sortKey) {
              _sortAscending = !_sortAscending;
            } else {
              _sortBy = sortKey;
              _sortAscending = false;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.orange : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.orange,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(Player player) {
    final totalTiles = widget.game.mapSize.x * widget.game.mapSize.y;
    final tilePercentage =
        totalTiles > 0
            ? ((player.visitedTiles.length / totalTiles) * 100).toStringAsFixed(
              0,
            )
            : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF34495E))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade900,
                  child: Image.asset(
                    'lib/assets/previewcharacters/${player.avatar.value}_preview.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    player.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _buildStatCell('${player.specs.nCombats}'),
          _buildStatCell('${player.specs.nEvasions}'),
          _buildStatCell('${player.specs.nVictories}'),
          _buildStatCell('${player.specs.nDefeats}'),
          _buildStatCell('${player.specs.nLifeLost}'),
          _buildStatCell('${player.specs.nLifeTaken}'),
          _buildStatCell('${player.specs.nItemsUsed}'),
          _buildStatCell('$tilePercentage%'),
        ],
      ),
    );
  }

  Widget _buildStatCell(String value) {
    return Expanded(
      child: Text(
        value,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGlobalStats() {
    final totalTiles = widget.game.mapSize.x * widget.game.mapSize.y;
    final visitedTiles =
        widget.game.players.expand((p) => p.visitedTiles).toSet().length;
    final tilePercentage =
        totalTiles > 0
            ? ((visitedTiles / totalTiles) * 100).toStringAsFixed(0)
            : '0.0';

    final totalDoors = widget.game.doorTiles.length;
    final doorPercentage =
        totalDoors > 0
            ? ((widget.game.nDoorsManipulated.length / totalDoors) * 100)
                .toStringAsFixed(0)
            : '0';

    final durationMinutes = (widget.game.duration / 60).floor();
    final durationSeconds = widget.game.duration % 60;

    final isCtfMode = widget.game is GameCtf;
    final flagHolderCount =
        isCtfMode ? (widget.game as GameCtf).nPlayersCtf.length : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withValues(alpha: 0.95),
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques globales de la partie',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildGlobalStatRow(
            'Durée de la partie',
            '$durationMinutes min $durationSeconds s',
          ),
          _buildGlobalStatRow('Tours de jeu', '${widget.game.nTurns}'),
          _buildGlobalStatRow(
            'Pourcentage de tuiles visitées',
            '$tilePercentage%',
          ),
          _buildGlobalStatRow(
            'Pourcentage de portes manipulées',
            '$doorPercentage%',
          ),
          if (isCtfMode)
            _buildGlobalStatRow(
              'Nombre de joueurs différents ayant détenu le drapeau',
              '$flagHolderCount',
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label : ',
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

  void _navigateToMainMenu() {
    try {
      SocketService().send('leaveGame', widget.gameId);
    } on Exception catch (e) {
      DebugLogger.log('Error leaving game: $e', tag: 'EndgameScreen');
    }

    if (widget.gameId.isNotEmpty) {
      ChannelService().removeGameChannel(widget.gameId);
    }

    if (context.mounted) {
      context.go('/');
    }
  }
}
