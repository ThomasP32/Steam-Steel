import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/diagonal_painter.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/countdown_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/game_turn_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game/action_button_widget.dart';
import 'package:mobile/widgets/game/challenges_widget.dart';
import 'package:mobile/widgets/game/combat_modal_widget.dart';
import 'package:mobile/widgets/game/door_selector_widget.dart';
import 'package:mobile/widgets/game/end_game_alert_widget.dart';
import 'package:mobile/widgets/game/inventory_modal_widget.dart';
import 'package:mobile/widgets/game/observation_mode_modal_widget.dart';
import 'package:mobile/widgets/game/player_left_modal_widget.dart';

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
  final GameTurnService _gameTurnService = GameTurnService();
  final CountdownService _countdownService = CountdownService();
  StreamSubscription<dynamic>? _countdownSub;
  StreamSubscription<int>? _delaySub;
  StreamSubscription<dynamic>? _inventoryFullSub;
  StreamSubscription<dynamic>? _itemDroppedSub;
  StreamSubscription<dynamic>? _combatStartedSub;
  StreamSubscription<dynamic>? _playerLeftSub;
  dynamic _countdown = 30;
  static const int _turnDuration = 30;
  String _currentPlayerName = 'Aucun';
  int _startTurnCountdown = 3;
  bool _delayFinished = true;
  Map<String, dynamic>? _selectedMove;
  List<dynamic>? _previewPath;
  bool _isProcessingClick = false;
  VoidCallback? _playerTurnListener;
  VoidCallback? _possibleMovesListener;
  VoidCallback? _possibleDoorsListener;
  VoidCallback? _possibleWallsListener;
  bool _pendingInventoryFull = false;
  bool _showCombatModal = false;
  Map<String, dynamic>? _combatChallenger;
  Map<String, dynamic>? _combatOpponent;
  VoidCallback? _gameFinishedListener;
  bool _showPlayerLeftModal = false;
  VoidCallback? _observationModeListener;
  bool _showObservationModal = false;

  @override
  void initState() {
    super.initState();

    FriendService().updateUserStatus(UserStatus.inGame);

    _ensureGameDataLoaded();
    _gameTurnService.initialize(widget.gameId);
    _listenToGameEvents();
    _listenToPlayerTurnUpdates();
    _listenToStartTurnDelay();
    _listenToInventoryFull();
    _listenToItemDropped();
    _listenToCombatStarted();
    _listenToDoorUpdates();
    _listenToWallUpdates();
    _listenToGameFinished();
    _listenToPlayerLeft();
    _countdownService.initialize();
    _listenToCountdown();
    _listenToObservationMode();
    final turnName = _gameTurnService.playerTurnNotifier.value;
    if (turnName.isNotEmpty) {
      _currentPlayerName = turnName;
    } else {
      final initialName = _gameService.getActivePlayerName();
      if (initialName != 'Aucun') {
        _currentPlayerName = initialName;
      }
    }
  }

  void _ensureGameDataLoaded() {
    if (_gameService.currentGame == null) {
      SocketService().send('getGameData', widget.gameId);
      SocketService().listen<dynamic>('currentGame').listen((data) {
        if (!mounted) return;
        if (data is Map<String, dynamic>) {
          _gameService.updateFromJson(data);
          setState(() {
            final turnName = _gameTurnService.playerTurnNotifier.value;
            if (turnName.isNotEmpty) {
              _currentPlayerName = turnName;
            } else {
              _currentPlayerName = _gameService.getActivePlayerName();
            }
          });
        }
      });
    }
  }

  void _listenToCountdown() {
    _countdownSub = _countdownService.countdownStream.listen((countdown) {
      setState(() {
        _countdown = countdown;
      });
    });
  }

  void _listenToPlayerTurnUpdates() {
    _playerTurnListener = () {
      if (!mounted) return;
      setState(() {
        _currentPlayerName = _gameTurnService.playerTurnNotifier.value;
      });
    };
    _gameTurnService.playerTurnNotifier.addListener(_playerTurnListener!);

    _possibleMovesListener = () {
      if (!mounted) return;
      setState(() {
        _selectedMove = null;
        _previewPath = null;
      });
    };
    _gameTurnService.possibleMovesNotifier.addListener(_possibleMovesListener!);
  }

  void _listenToGameEvents() {
    SocketService().listen<dynamic>('positionToUpdate').listen((data) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        final gameData = data['game'] as Map<String, dynamic>?;
        final playerData = data['player'] as Map<String, dynamic>?;

        if (gameData != null) {
          _gameService.updateFromJson(gameData);
        }

        if (playerData != null) {
          final currentPlayer = PlayerService().player;
          final updatedSocketId = playerData['socketId']?.toString() ?? '';

          if (updatedSocketId == currentPlayer.socketId) {
            PlayerService().setPlayerFromJson(playerData);

            if (_pendingInventoryFull &&
                PlayerService().player.inventory.length > INVENTORY_SIZE) {
              _pendingInventoryFull = false;
              _showInventoryModal();
            }

            if (_gameTurnService.isYourTurn) {
              final updatedPlayer = PlayerService().player;

              SocketService().send('getCombats', widget.gameId);
              if (updatedPlayer.specs.actions > 0) {
                SocketService().send('getAdjacentDoors', widget.gameId);
              }
              SocketService().send('getMovements', widget.gameId);
            }
          }
        }

        setState(() {});
      }
    });
  }

  void _listenToStartTurnDelay() {
    _delaySub = SocketService().listen<int>('delay').listen((delay) {
      if (!mounted) return;
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

  void _listenToInventoryFull() {
    _inventoryFullSub = SocketService().listen<dynamic>('inventoryFull').listen(
      (_) {
        if (!mounted) return;
        _gameTurnService.pendingInventoryModal = true;
        _pendingInventoryFull = true;
      },
    );
  }

  void _showInventoryModal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => InventoryModalWidget(
            player: PlayerService().player,
            gameId: widget.gameId,
            getItemAssetPath: _getItemAssetPath,
          ),
    );
  }

  void _listenToItemDropped() {
    _itemDroppedSub = SocketService().listen<dynamic>('itemDropped').listen((
      data,
    ) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        final updatedGameData = data['updatedGame'] as Map<String, dynamic>?;
        final updatedPlayerData =
            data['updatedPlayer'] as Map<String, dynamic>?;

        if (updatedGameData != null) {
          _gameService.updateFromJson(updatedGameData);
        }

        if (updatedPlayerData != null) {
          final currentPlayer = PlayerService().player;
          final updatedSocketId =
              updatedPlayerData['socketId']?.toString() ?? '';

          if (updatedSocketId == currentPlayer.socketId) {
            PlayerService().setPlayerFromJson(updatedPlayerData);
            _gameTurnService.notifyInventoryActionCompleted();
          }
        }

        setState(() {});
      }
    });
  }

  void _listenToCombatStarted() {
    _combatStartedSub = SocketService().listen<dynamic>('combatStarted').listen(
      (data) {
        if (!mounted) return;
        if (data is Map<String, dynamic>) {
          final challenger = data['challenger'] as Map<String, dynamic>?;
          final opponent = data['opponent'] as Map<String, dynamic>?;

          if (challenger != null && opponent != null) {
            setState(() {
              _combatChallenger = challenger;
              _combatOpponent = opponent;
              _showCombatModal = true;
            });
          }
        }
      },
    );

    SocketService().listen<dynamic>('combatFinished').listen((data) {
      if (!mounted) return;

      if (data is Map<String, dynamic>) {
        final gameData = data['updatedGame'] as Map<String, dynamic>?;
        if (gameData != null) {
          _gameService.updateFromJson(gameData);
        }
      } else {}
      setState(() {
        _showCombatModal = false;
        _combatChallenger = null;
        _combatOpponent = null;
      });
    });

    SocketService().listen<dynamic>('combatFinishedByEvasion').listen((data) {
      if (!mounted) return;

      if (data is Map<String, dynamic>) {
        final gameData = data['updatedGame'] as Map<String, dynamic>?;
        if (gameData != null) {
          DebugLogger.log(
            'Updating game from combatFinishedByEvasion',
            tag: 'GameScreen',
          );
          _gameService.updateFromJson(gameData);
        }
      }
      setState(() {
        _showCombatModal = false;
        _combatChallenger = null;
        _combatOpponent = null;
      });
    });

    SocketService().listen<dynamic>('combatFinishedNormally').listen((data) {
      if (!mounted) return;
      DebugLogger.log(
        'combatFinishedNormally event received: $data',
        tag: 'GameScreen',
      );
      if (data is Map<String, dynamic>) {
        final gameData = data['updatedGame'] as Map<String, dynamic>?;
        if (gameData != null) {
          DebugLogger.log(
            'Updating game from combatFinishedNormally',
            tag: 'GameScreen',
          );
          _gameService.updateFromJson(gameData);
        } else {
          DebugLogger.log(
            'No updatedGame in combatFinishedNormally',
            tag: 'GameScreen',
          );
        }
      }
      setState(() {
        _showCombatModal = false;
        _combatChallenger = null;
        _combatOpponent = null;
      });
    });
  }

  void _listenToDoorUpdates() {
    _possibleDoorsListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _gameTurnService.possibleDoorsNotifier.addListener(_possibleDoorsListener!);

    SocketService().listen<dynamic>('doorToggled').listen((data) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        final gameData = data['game'] as Map<String, dynamic>?;
        final playerData = data['player'] as Map<String, dynamic>?;

        if (gameData != null) {
          _gameService.updateFromJson(gameData);
        }

        if (playerData != null) {
          final currentPlayer = PlayerService().player;
          final updatedSocketId = playerData['socketId']?.toString() ?? '';

          if (updatedSocketId == currentPlayer.socketId) {
            PlayerService().setPlayerFromJson(playerData);
            _gameTurnService.resumeTurn();
          }
        }

        setState(() {});
      }
    });
  }

  void _listenToWallUpdates() {
    _possibleWallsListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _gameTurnService.possibleWallsNotifier.addListener(_possibleWallsListener!);

    SocketService().listen<dynamic>('wallBroken').listen((data) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        final gameData = data['game'] as Map<String, dynamic>?;
        final playerData = data['player'] as Map<String, dynamic>?;

        if (gameData != null) {
          _gameService.updateFromJson(gameData);
        }

        if (playerData != null) {
          final currentPlayer = PlayerService().player;
          final updatedSocketId = playerData['socketId']?.toString() ?? '';

          if (updatedSocketId == currentPlayer.socketId) {
            PlayerService().setPlayerFromJson(playerData);
            _gameTurnService.resumeTurn();
          }
        }

        setState(() {});
      }
    });
  }

  void _listenToGameFinished() {
    _gameFinishedListener = () {
      if (!mounted) return;
      if (_gameTurnService.gameFinishedNotifier.value) {
        _handleGameFinished();
      }
    };
    _gameTurnService.gameFinishedNotifier.addListener(_gameFinishedListener!);
  }

  void _handleGameFinished() {
    final gameData = _gameTurnService.gameFinishedDataNotifier.value;
    final updatedGame = gameData?['updatedGame'] as Map<String, dynamic>?;

    if (updatedGame != null) {
      _gameService.updateFromJson(updatedGame);
    }

    setState(() {});

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final currentGame = _gameService.notifier.value;
        if (currentGame != null) {
          context.go('/endgame/${widget.gameId}', extra: currentGame);
        } else {
          _navigateToMainMenu();
        }
      }
    });
  }

  void _navigateToMainMenu() {
    try {
      SocketService().send('leaveGame', widget.gameId);
    } on Exception catch (e) {
      DebugLogger.log('leaveGame error: $e', tag: 'GameScreen');
    }

    if (widget.gameId.isNotEmpty) {
      ChannelService().removeGameChannel(widget.gameId);
    }

    if (context.mounted) {
      GoRouter.of(context).go('/');
    }
  }

  void _listenToPlayerLeft() {
    _playerLeftSub = SocketService().listen<dynamic>('playerLeft').listen((
      data,
    ) {
      if (!mounted) return;
      if (data is List<dynamic>) {
        final players =
            data
                .whereType<Map<String, dynamic>>()
                .map(PlayerService.parsePlayer)
                .toList();

        final game = _gameService.currentGame;
        if (game != null) {
          final updatedGame = GameClassic(
            id: game.id,
            hostSocketId: game.hostSocketId,
            players: players,
            currentTurn: game.currentTurn,
            nDoorsManipulated: game.nDoorsManipulated,
            duration: game.duration,
            nTurns: game.nTurns,
            debug: game.debug,
            isLocked: game.isLocked,
            hasStarted: game.hasStarted,
            mapSize: game.mapSize,
            tiles: game.tiles,
            doorTiles: game.doorTiles,
            items: game.items,
            startTiles: game.startTiles,
            name: game.name,
            description: game.description,
            imagePreview: game.imagePreview,
            mode: game.mode,
          );
          _gameService.setGame(updatedGame);
        }

        final activePlayers =
            players
                .where(
                  (p) =>
                      p.isActive &&
                      !p.isObservationMode &&
                      p.socketId.isNotEmpty,
                )
                .toList();
        final allVirtual =
            activePlayers.isNotEmpty &&
            activePlayers.every((p) => p.socketId.contains('virtualPlayer'));

        if (activePlayers.length <= 1 || allVirtual) {
          setState(() {
            _showPlayerLeftModal = true;
          });

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _navigateToMainMenu();
            }
          });
        }

        setState(() {});
      }
    });

    SocketService().listen<dynamic>('gameUpdated').listen((data) {
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        _gameService.updateFromJson(data);
        setState(() {});
      }
    });
  }

  void _listenToObservationMode() {
    _observationModeListener = () {
      if (!mounted) return;
      if (_gameTurnService.observationModeNotifier.value &&
          !_showObservationModal) {
        setState(() {
          _showObservationModal = true;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showObservationModal = false;
            });
          }
        });
      }
    };
    _gameTurnService.observationModeNotifier.addListener(
      _observationModeListener!,
    );
  }

  @override
  void dispose() {
    FriendService().updateUserStatus(UserStatus.online);

    _deleteSubs();
    if (_playerTurnListener != null) {
      _gameTurnService.playerTurnNotifier.removeListener(_playerTurnListener!);
    }
    if (_possibleMovesListener != null) {
      _gameTurnService.possibleMovesNotifier.removeListener(
        _possibleMovesListener!,
      );
    }
    if (_possibleDoorsListener != null) {
      _gameTurnService.possibleDoorsNotifier.removeListener(
        _possibleDoorsListener!,
      );
    }
    if (_possibleWallsListener != null) {
      _gameTurnService.possibleWallsNotifier.removeListener(
        _possibleWallsListener!,
      );
    }
    if (_gameFinishedListener != null) {
      _gameTurnService.gameFinishedNotifier.removeListener(
        _gameFinishedListener!,
      );
    }
    if (_observationModeListener != null) {
      _gameTurnService.observationModeNotifier.removeListener(
        _observationModeListener!,
      );
    }
    _gameTurnService.dispose();
    super.dispose();
  }

  void _deleteSubs() {
    _countdownSub?.cancel();
    _delaySub?.cancel();
    _inventoryFullSub?.cancel();
    _itemDroppedSub?.cancel();
    _combatStartedSub?.cancel();
    _playerLeftSub?.cancel();
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
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ChannelService().removeGameChannel(widget.gameId);
                SocketService().send('leaveGame', widget.gameId);

                FriendService().updateUserStatus(UserStatus.online);

                try {
                  SocketService().send('leaveGame', widget.gameId);
                  await Future.delayed(const Duration(milliseconds: 100));
                } on Exception catch (e) {
                  DebugLogger.log('leaveGame error: $e', tag: 'GameScreen');
                }
                if (context.mounted) {
                  GoRouter.of(context).go('/');
                }
              },
              child: const Text('Quitter'),
            ),
          ],
        );
      },
    );
  }

  void _handleCombatAction() {
    final opponents = _gameTurnService.possibleOpponentsNotifier.value;

    DebugLogger.log(
      'Combat action triggered: opponents=${opponents.length}, isYourTurn=${_gameTurnService.isYourTurn}, hasCombatAvailable=${_gameTurnService.hasCombatAvailable}',
      tag: 'GameScreen',
    );

    if (opponents.isEmpty) {
      DebugLogger.log('No opponents available', tag: 'GameScreen');
      return;
    }

    if (opponents.length == 1) {
      _gameTurnService.startCombat(widget.gameId, opponents[0]);
    } else {
      DebugLogger.log(
        'Showing opponent selection for ${opponents.length} opponents',
        tag: 'GameScreen',
      );
      _showCombatSelectionModal(opponents);
    }
  }

  void _showCombatSelectionModal(List<dynamic> opponents) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text(
            'Choisir un adversaire',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opponents.length,
              itemBuilder: (context, index) {
                final opponent = opponents[index];
                final opponentName = opponent['name'] as String? ?? 'Joueur';
                final avatar = opponent['avatar'];
                final avatarValue =
                    avatar is Map ? (avatar['value'] ?? '1') : (avatar ?? '1');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34495E),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _gameTurnService.startCombat(widget.gameId, opponent);
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade900,
                          child: Image.asset(
                            'lib/assets/previewcharacters/${avatarValue}_preview.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.orange),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGameFinished = _gameTurnService.gameFinishedNotifier.value;
    final isObserving = PlayerService().player.isObservationMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/backgrounds/backgroundcombat.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(top: -40, left: 320, child: _buildMapGrid()),
          Positioned(
            top: 16,
            left: 880,
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
                        onPressed: _toggleGameInfo,
                        child: const Icon(
                          Icons.info_outline,
                          color: Color(0xFFC0C0C0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const FriendButton(withPadding: false),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: SizedBox(child: ChatWidget()),
                    ),
                  ],
                ),
                if (_showGameInfo)
                  ValueListenableBuilder<GameClassic?>(
                    valueListenable: _gameService.notifier,
                    builder: (context, game, _) {
                      final activePlayerCount =
                          game?.players.where((p) => p.isActive).length ?? 0;
                      return Container(
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
                              '$activePlayerCount',
                            ),
                            const Divider(color: Colors.grey),
                            _buildInfoRow('Joueur Actif :', _currentPlayerName),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),
                ValueListenableBuilder<GameClassic?>(
                  valueListenable: _gameService.notifier,
                  builder: (context, game, _) {
                    return Container(
                      width: 270,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: _buildPlayerList(game),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: 270,
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: const ChallengesWidget(showInfoButton: false),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: _gameTurnService.yourTurnNotifier,
              builder: (context, isYourTurn, _) {
                return ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _gameTurnService.possibleOpponentsNotifier,
                  builder: (context, opponents, _) {
                    final hasCombat = opponents.isNotEmpty && isYourTurn;
                    DebugLogger.log(
                      'Combat button: opponents=${opponents.length}, isYourTurn=$isYourTurn, enabled=$hasCombat',
                      tag: 'GameScreen',
                    );
                    return ActionButton(
                      iconPath: 'lib/assets/icons/fighting.png',
                      onPressed: _handleCombatAction,
                      isEnabled: hasCombat,
                    );
                  },
                );
              },
            ),
          ),
          if (PlayerService().player.inventory.contains(
            ItemCategory.wallBreaker,
          ))
            Positioned(
              left: 86,
              bottom: 16,
              child: ActionButton(
                iconPath: 'lib/assets/items/wallbreaker.png',
                onPressed: _handleWallAction,
                isEnabled:
                    _gameTurnService.isYourTurn &&
                    _gameTurnService.possibleWallsNotifier.value.isNotEmpty &&
                    (_gameTurnService.possibleActions['wall'] ?? false) &&
                    PlayerService().player.specs.actions > 0,
              ),
            ),
          Positioned(
            left:
                PlayerService().player.inventory.contains(
                      ItemCategory.wallBreaker,
                    )
                    ? 156
                    : 86,
            bottom: 16,
            child: ActionButton(
              iconPath: 'lib/assets/icons/door.png',
              onPressed: _handleDoorAction,
              isEnabled:
                  _gameTurnService.isYourTurn &&
                  _gameTurnService.possibleDoorsNotifier.value.isNotEmpty &&
                  (_gameTurnService.possibleActions['door'] ?? false) &&
                  PlayerService().player.specs.actions > 0,
            ),
          ),
          Positioned(
            left:
                PlayerService().player.inventory.contains(
                      ItemCategory.wallBreaker,
                    )
                    ? 226
                    : 156,
            bottom: 16,
            child: ActionButton(
              iconPath: 'lib/assets/icons/endturn_icon.png',
              onPressed: () => _gameTurnService.endTurn(widget.gameId),
              isEnabled: _gameTurnService.isYourTurn,
            ),
          ),
          Positioned(
            left:
                PlayerService().player.inventory.contains(
                      ItemCategory.wallBreaker,
                    )
                    ? 296
                    : 226,
            bottom: 16,
            child: ActionButton(
              iconPath: 'lib/assets/icons/quit_icon.png',
              onPressed: quitGame,
              isEnabled: true,
            ),
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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showCombatModal &&
              _combatChallenger != null &&
              _combatOpponent != null)
            CombatModalWidget(
              challenger: _combatChallenger!,
              opponent: _combatOpponent!,
              gameId: widget.gameId,
              isObserver: PlayerService().player.isObservationMode,
            ),
          if (_showPlayerLeftModal) const PlayerLeftModalWidget(),
          if (isGameFinished)
            EndGameAlertWidget(game: _gameService.currentGame),

          if (_showObservationModal)
            ObservationModeModalWidget(
              message: _gameTurnService.observationMessageNotifier.value,
            ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final displayTime = _countdown.toString();
    final timeLeft = _countdown is int ? _countdown as int : 0;
    final progress = timeLeft / _turnDuration;

    return Stack(
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
    );
  }

  Widget _buildMapGrid() {
    final game = _gameService.currentGame;
    if (game == null) {
      return const SizedBox.shrink();
    }

    final mapSize = game.mapSize;
    final gridSize = mapSize.x;

    final tileSize = 700.0 / gridSize;

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

    if (needsInteractiveViewer) {
      return Padding(
        padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
        child: SizedBox(
          width: 700,
          height: 700,
          child: ClipRect(
            child: InteractiveViewer(
              constrained: false,
              panEnabled: false,
              scaleEnabled: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 2,
              child: gridWidget,
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
        child: gridWidget,
      );
    }
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
      if (p.isActive == false) return false;
      if (p.isObservationMode == true) return false;
      final pos = p.position as List;
      return pos.isNotEmpty && pos[0].x == row && pos[0].y == col;
    }, orElse: () => null);

    final isYourTurn = _gameTurnService.isYourTurn;
    final isPossibleMove =
        isYourTurn && _gameTurnService.isPossibleMove(row, col);
    final isInPreviewPath =
        isYourTurn &&
        (_previewPath?.any((coord) {
              if (coord is Map<String, dynamic>) {
                return coord['x'] == row && coord['y'] == col;
              }
              return false;
            }) ??
            false);

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

    return GestureDetector(
      onTap: () => _onTileClick(row, col),
      child: Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF654321)),
        ),
        child: Stack(
          children: [
            Image.asset(
              tileAsset,
              width: tileSize,
              height: tileSize,
              fit: BoxFit.cover,
            ),

            if (startPoint != null)
              Center(
                child: Image.asset(
                  'lib/assets/tiles/startingpoint.png',
                  width: tileSize,
                  height: tileSize,
                  fit: BoxFit.contain,
                ),
              ),

            if (item != null)
              Center(
                child: Image.asset(
                  _getItemAssetPath(item.category as ItemCategory),
                  width: tileSize * 0.7,
                  height: tileSize * 0.7,
                  fit: BoxFit.contain,
                ),
              ),

            if (player != null)
              Center(
                child: CircleAvatar(
                  radius: tileSize,
                  backgroundColor: Colors.transparent,
                  child: Image.asset(
                    'lib/assets/pixelcharacters/${player.avatar.value}_pixelated.png',
                    width: tileSize,
                    height: tileSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (isPossibleMove && !isInPreviewPath)
              CustomPaint(
                size: Size(tileSize, tileSize),
                painter: DiagonalStripePainter(),
              ),

            if (isInPreviewPath)
              CustomPaint(
                size: Size(tileSize, tileSize),
                painter: PathPreviewPainter(),
              ),
          ],
        ),
      ),
    );
  }

  void _onTileClick(int row, int col) {
    if (_isProcessingClick) return;
    _isProcessingClick = true;

    final key = '$row,$col';
    final moveData = _gameTurnService.possibleMovesNotifier.value[key];

    if (moveData == null) {
      if (_selectedMove != null || _previewPath != null) {
        setState(() {
          _selectedMove = null;
          _previewPath = null;
        });
      }
      _isProcessingClick = false;
      return;
    }

    if (_selectedMove != null && _selectedMove!['key'] == key) {
      final player = PlayerService().player;
      DebugLogger.log(
        'Executing move to: ($row, $col) by player turn ${player.turn}',
        tag: 'GameScreen',
      );
      SocketService().send('moveToPosition', {
        'playerTurn': player.turn,
        'gameId': widget.gameId,
        'destination': {'x': row, 'y': col},
      });
      setState(() {
        _selectedMove = null;
        _previewPath = null;
      });
    } else {
      setState(() {
        _selectedMove = {'key': key, 'data': moveData};
        _previewPath = moveData['path'] as List<dynamic>?;
      });
      DebugLogger.log(
        'Selected tile ($row, $col), path preview: $_previewPath',
        tag: 'GameScreen',
      );
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _isProcessingClick = false;
    });
  }

  void _handleDoorAction() {
    final doors = _gameTurnService.possibleDoorsNotifier.value;
    if (doors.isEmpty) return;

    if (doors.length == 1) {
      _gameTurnService.toggleDoor(doors.first);
    } else {
      _showDoorSelector(doors);
    }
  }

  void _handleWallAction() {
    final walls = _gameTurnService.possibleWallsNotifier.value;
    if (walls.isEmpty) return;

    _gameTurnService.breakWall(walls.first);
  }

  void _showDoorSelector(List<DoorTile> doors) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return DoorSelectorWidget(
          doors: doors,
          onDoorSelected: (door) {
            Navigator.of(context).pop();
            _gameTurnService.toggleDoor(door);
          },
          onCancel: () => Navigator.of(context).pop(),
          getItemAssetPath: _getItemAssetPath,
        );
      },
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
              Expanded(child: _buildInventorySlot(0)),
              const SizedBox(width: 8),
              Expanded(child: _buildInventorySlot(1)),
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

  Widget _buildInventorySlot(int index) {
    return ValueListenableBuilder<Player>(
      valueListenable: PlayerService().notifier,
      builder: (context, player, _) {
        final hasItem = player.inventory.length > index;
        final item = hasItem ? player.inventory[index] : null;

        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1A252F),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child:
                item != null
                    ? Image.asset(
                      _getItemAssetPath(item),
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    )
                    : const Text(
                      'Vide',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
          ),
        );
      },
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

  List<Widget> _buildPlayerList(GameClassic? game) {
    if (game == null || game.players.isEmpty) {
      return [
        const Text(
          'Aucun joueur',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ];
    }

    return game.players.map((player) {
      final isActivePlayer = player.name == _currentPlayerName;
      final avatarIndex = (player.avatar.index + 1).clamp(1, 12);
      final hasFlag = player.inventory.contains(ItemCategory.flag);
      final hasLeftGame = !player.isActive;
      final isObserving = player.isObservationMode;
      final isVirtualPlayer = player.socketId.contains('virtualPlayer');
      final isGameCreator = player.socketId == game.hostSocketId;
      final isNotInGame = hasLeftGame || isObserving;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isActivePlayer
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: isNotInGame ? 0.4 : 1.0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade900,
                        child: Image.asset(
                          'lib/assets/previewcharacters/${avatarIndex}_preview.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.name.isNotEmpty ? player.name : 'Joueur',
                        style: TextStyle(
                          color:
                              isNotInGame
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.white,
                          fontSize: 16,
                          fontWeight:
                              isActivePlayer
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          decoration:
                              isNotInGame
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                          decorationColor: Colors.orange,
                          decorationThickness: 3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: isNotInGame ? 0.4 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        if (isActivePlayer) ...[
                          Image.asset(
                            'lib/assets/icons/arrow.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isObserving) ...[
                          const Icon(
                            Icons.remove_red_eye,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isVirtualPlayer) ...[
                          Image.asset(
                            'lib/assets/icons/robot.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isGameCreator) ...[
                          Image.asset(
                            'lib/assets/icons/crown.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hasFlag) ...[
                          Image.asset(
                            'lib/assets/icons/flag_player.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Image.asset(
                          'lib/assets/icons/trophy_icon.png',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${player.specs.nVictories}',
                          style: TextStyle(
                            color:
                                isActivePlayer
                                    ? Colors.orange.shade200
                                    : Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  String _getItemAssetPath(ItemCategory category) {
    switch (category) {
      case ItemCategory.sword:
        return 'lib/assets/items/sword.png';
      case ItemCategory.armor:
        return 'lib/assets/items/armor.png';
      case ItemCategory.flask:
        return 'lib/assets/items/flask.png';
      case ItemCategory.wallBreaker:
        return 'lib/assets/items/wallbreaker.png';
      case ItemCategory.iceSkates:
        return 'lib/assets/items/iceskates.png';
      case ItemCategory.amulet:
        return 'lib/assets/items/amulet.png';
      case ItemCategory.flag:
        return 'lib/assets/items/flag.png';
      case ItemCategory.random:
        return 'lib/assets/items/randomitem.png';
      case ItemCategory.startingPoint:
        return 'lib/assets/items/startingPoint.png';
    }
  }
}

class _CrossLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.8)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
