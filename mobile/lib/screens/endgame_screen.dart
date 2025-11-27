import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/challenge_service.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/endgame_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/shop_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';

class EndgameScreen extends StatefulWidget {
  const EndgameScreen({
    required this.game,
    required this.gameId,
    this.moneyReward = 0,
    super.key,
  });

  final GameClassic game;
  final String gameId;
  final int moneyReward;

  @override
  State<EndgameScreen> createState() => _EndgameScreenState();
}

class _EndgameScreenState extends State<EndgameScreen> {
  String _sortBy = 'victories';
  bool _sortAscending = false;
  final _endgameService = EndgameService();
  final _challengeService = ChallengeService();
  final _shopService = ShopService();
  final Map<String, String> _playerBanners = {};
  bool _showLevelModal = false;
  int _newLevel = 0;
  bool _bannerUnlocked = false;

  @override
  void initState() {
    super.initState();

    _endgameService.initialize();

    final socketService = SocketService();
    final currentSocketId = socketService.socketId ?? '';
    if (currentSocketId.isNotEmpty) {
      _endgameService.updateUserStats(widget.game, currentSocketId);
    }
    _loadPlayerBanners();
    _listenToPlayerLeveledUp();
  }

  @override
  void dispose() {
    _endgameService.levelUpNotifier.removeListener(_onLevelUp);
    super.dispose();
  }

  void _listenToPlayerLeveledUp() {
    _endgameService.levelUpNotifier.addListener(_onLevelUp);
  }

  void _onLevelUp() {
    final data = _endgameService.levelUpNotifier.value;

    if (!mounted) {
      return;
    }
    if (data == null) {
      return;
    }

    setState(() {
      _showLevelModal = true;
      _newLevel = data.newLevel;
      _bannerUnlocked = data.bannerUnlocked;
    });
  }

  Future<void> _loadPlayerBanners() async {
    final players = widget.game.players;
    if (players.isEmpty) return;

    for (final player in players) {
      if (player.socketId.startsWith('virtualPlayer')) continue;

      try {
        final userItems = await _shopService.getUserItemsByUsername(
          player.name,
        );
        final equippedBanner = userItems.firstWhere(
          (item) =>
              item['equipped'] == true &&
              (item['itemId'] as String).startsWith('banner_'),
          orElse: () => {},
        );

        if (equippedBanner.isNotEmpty) {
          final bannerId = equippedBanner['itemId'] as String;
          final bannerNumber = bannerId.replaceAll('banner_', '');
          final bannerPath = 'lib/assets/banner/$bannerNumber.png';
          if (mounted) {
            setState(() {
              _playerBanners[player.name] = bannerPath;
            });
          }
        }
      } on Exception catch (e) {
        DebugLogger.log(
          'Error loading banner for ${player.name}: $e',
          tag: 'EndgameScreen',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = _getSortedPlayers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return WillPopScope(
      onWillPop: () async {
        _navigateToMainMenu();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ThemeBackground(pageId: 'endgame')),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FIN DE PARTIE',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Row(
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
                          const SizedBox(height: 12),
                          _buildGlobalStats(),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(child: _buildMoneyReward()),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: SizedBox(
                                      height: 140,
                                      child: Center(child: _buildMenuButton()),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showLevelModal) _buildLevelUpModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelUpModal() {
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
              Text(
                'Félicitations ! 🎉',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Tu viens de passer au niveau $_newLevel !',
                style: TextStyle(color: textColor, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _bannerUnlocked
                    ? 'Tu as débloqué une nouvelle bannière. Va voir la boutique pour la découvrir !'
                    : "Continue de jouer, une nouvelle bannière t'attend tous les 5 niveaux.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
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
                onPressed: () {
                  setState(() {
                    _showLevelModal = false;
                  });
                },
                child: const Text(
                  'OK',
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

     return players.where((player) => player.wasActivePlayer).toList();
  }

  Widget _buildStatsTable(List<Player> players) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark
            ? const Color(0xFF2C3E50).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: AppColors.accentHighlight(context), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [_buildTableHeader(), ...players.map(_buildPlayerRow)],
      ),
    );
  }

  Widget _buildTableHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? const Color(0xFF34495E) : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Joueur', 'name', flex: 2),
          _buildHeaderCell('Combats', 'combats'),
          _buildHeaderCell('Évasions', 'evasions'),
          _buildHeaderCell('Victoires', 'victories'),
          _buildHeaderCell('Défaites', 'defeats'),
          _buildHeaderCell('Vie\nperdue', 'lifeLost'),
          _buildHeaderCell('Vie\ninfligée', 'lifeTaken'),
          _buildHeaderCell('Objets', 'items'),
          _buildHeaderCell('Tuiles %', 'tiles'),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String sortKey, {int flex = 1}) {
    final isActive = _sortBy == sortKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.accentHighlight(context);
    final inactiveColor = isDark ? Colors.white : Colors.black87;
    final isPlayerColumn = sortKey == 'name';

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: isPlayerColumn ? 0 : 8),
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
                    color: isActive ? activeColor : inactiveColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: activeColor,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow(Player player) {
    final totalTiles = widget.game.mapSize.x * widget.game.mapSize.y;
    final tilePercentage = () {
      if (totalTiles <= 0) return '0';
      final pct = ((player.visitedTiles.length / totalTiles) * 100).floor();
      return pct.toString();
    }();
    final bannerPath = _playerBanners[player.name];
    final isVirtual = player.socketId.startsWith('virtualPlayer');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: const Border(top: BorderSide(color: Color(0xFF34495E))),
        image:
            bannerPath != null
                ? DecorationImage(
                  image: AssetImage(bannerPath),
                  fit: BoxFit.cover,
                )
                : null,
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
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isVirtual && player.level != null) ...[
                        const SizedBox(width: 6),
                        Image.asset(
                          'lib/assets/level-badges/level-${player.level}.png',
                          width: 26,
                          height: 26,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                        ),
                      ],
                      if (isVirtual) ...[
                        const SizedBox(width: 6),
                        Image.asset(
                          'lib/assets/icons/robot.png',
                          width: 26,
                          height: 26,
                        ),
                      ],
                    ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Text(
        value,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMoneyReward() {
    final challenge = _challengeService.challengeNotifier.value;
    final challengeReward =
        (challenge != null && challenge.completed) ? challenge.reward : 0;
    final totalReward = widget.moneyReward + challengeReward;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: Image.asset(
              'lib/assets/icons/money.png',
              width: 64,
              height: 64,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.monetization_on,
                  size: 64,
                  color: Color(0xFF7D4F00),
                );
              },
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récompenses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7D4F00).withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '+$totalReward pièces',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7D4F00),
                    shadows: [
                      Shadow(
                        color: Colors.white54,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.moneyReward > 0)
                      Expanded(
                        child: Text(
                          'Partie: +${widget.moneyReward}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7D4F00),
                          ),
                        ),
                      ),
                    if (challengeReward > 0)
                      Expanded(
                        child: Text(
                          'Défi: +$challengeReward',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7D4F00),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    final accent = AppColors.accentHighlight(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _navigateToMainMenu,
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Menu principal',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalStats() {
    final totalTiles = widget.game.mapSize.x * widget.game.mapSize.y;
    final uniqueVisited = <String>{};
    for (final p in widget.game.players) {
      for (final t in p.visitedTiles) {
        uniqueVisited.add('${t.x},${t.y}');
      }
    }
    final visitedTiles = uniqueVisited.length;
    final tilePercentage =
        totalTiles > 0
            ? ((visitedTiles / totalTiles) * 100).floor().toString()
            : '0';

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
        color:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C3E50).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
        border: Border.all(color: AppColors.accentHighlight(context), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques globales de la partie',
            style: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textDark
                      : AppColors.textLight,
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
    final textColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textDark
            : AppColors.textLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label : ', style: TextStyle(color: textColor, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: textColor,
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

    FriendService().updateUserStatus(UserStatus.online);

    if (widget.gameId.isNotEmpty) {
      ChannelService().removeGameChannel(widget.gameId);
    }

    if (context.mounted) {
      context.go('/');
    }
  }
}
