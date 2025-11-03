import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/services/waiting_room_service.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/waiting_room/profile_modal_widget.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({this.gameId, this.mapName, super.key});

  final String? gameId;
  final String? mapName;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  final _service = WaitingRoomService();
  final _gameService = GameService();
  final _playerService = PlayerService();
  late AnimationController _gearController;

  StreamSubscription<dynamic>? _closedSub;
  StreamSubscription<dynamic>? _gameInitializedSub;
  StreamSubscription<dynamic>? _playerKickedSub;

  VoidCallback? _playerListener;
  String _playerName = '';

  @override
  void initState() {
    super.initState();

    final local = _playerService.notifier.value;
    if (local != null && local.name.isNotEmpty) {
      _playerName = local.name;
    }

    _playerListener = () {
      final p = _playerService.notifier.value;
      if (p != null && mounted && p.name.isNotEmpty && p.name != _playerName) {
        setState(() => _playerName = p.name);
      }
    };
    _playerService.notifier.addListener(_playerListener!);

    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _service.initialize(widget.gameId, widget.mapName);

    _listenToGameClosed();
    _listenToGameInitialized();
    _listenToPlayerKicked();
  }

  void _listenToGameClosed() {
    _closedSub = SocketService().listen<dynamic>('gameClosed').listen((_) {
      if (!mounted) return;
      GoRouter.of(context).go('/');
    });
  }

  void _listenToGameInitialized() {
    _gameInitializedSub = SocketService()
        .listen<dynamic>('gameInitialized')
        .listen((data) {
          if (!mounted) return;

          if (data is Map<String, dynamic>) {
            _gameService.updateFromJson(data);

            final players = data['players'] as List<dynamic>?;
            if (players != null && players.isNotEmpty) {
              final currentSocketId = SocketService().socketId;
              final myPlayerData =
                  players.firstWhere(
                        (p) =>
                            (p as Map<String, dynamic>)['socketId'] ==
                            currentSocketId,
                        orElse: () => null,
                      )
                      as Map<String, dynamic>?;
              if (myPlayerData != null) {
                _playerService.setPlayerFromJson(myPlayerData);
              }
            }
          }

          if (_service.isHost.value) {
            SocketService().send('startGame', _service.gameId.value);
          }

          GoRouter.of(context)
              .go('/game/${_service.gameId.value}/${_service.mapName.value}');
        });
  }

  void _listenToPlayerKicked() {
    _playerKickedSub = SocketService().listen<dynamic>('playerKicked').listen((
      _,
    ) {
      if (!mounted) return;

      SocketService().disconnect();
      GoRouter.of(context).go('/');
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(
          message: 'Vous avez été expulsé de la partie',
        ),
      );
    });
  }

  @override
  void dispose() {
    if (_playerListener != null) {
      _playerService.notifier.removeListener(_playerListener!);
    }
    _gearController.dispose();
    _closedSub?.cancel();
    _gameInitializedSub?.cancel();
    _playerKickedSub?.cancel();
    _service.reset();
    super.dispose();
  }

  Widget _buildPlayerRow(Player p) {
    final idx = (p.avatar.index + 1).clamp(1, 12);
    final isAI = p.socketId.startsWith('virtualPlayer');
    final isSelected =
        _service.selectedPlayerSocketId.value == p.socketId;
    final isFirstPlayer =
        _service.players.value.isNotEmpty &&
        _service.players.value[0].socketId == p.socketId;
    final canKick = _service.isHost.value && !isFirstPlayer;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border:
            isFirstPlayer
                ? Border.all(color: Colors.orange, width: 2)
                : null,
      ),
      child: ListTile(
        selected: isSelected,
        onTap:
            canKick
                ? () {
                  _service.selectedPlayerSocketId.value =
                      isSelected ? null : p.socketId;
                }
                : null,
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade900,
          radius: 22,
          child: Image.asset(
            'lib/assets/previewcharacters/${idx}_preview.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        title: Row(
          children: [
            Text(p.name.isNotEmpty ? p.name : 'Joueur'),
            if (isAI) ...[
              const SizedBox(width: 8),
              Image.asset('lib/assets/icons/robot.png', width: 30, height: 30),
            ],
          ],
        ),
        trailing:
            isSelected && canKick
                ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _service.kickPlayer(p.socketId),
                  child: const Text('Exclure'),
                )
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: Card(
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 12),
                          _buildPlayersList(),
                          const SizedBox(height: 12),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: 18, left: 50, child: ChatWidget()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder(
      valueListenable: _service.gameId,
      builder: (context, gameId, _) {
        return ValueListenableBuilder(
          valueListenable: _service.isLocked,
          builder: (context, isLocked, _) {
            return ValueListenableBuilder(
              valueListenable: _service.isHost,
              builder: (context, isHost, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.players,
                  builder: (context, players, _) {
                    return ValueListenableBuilder(
                      valueListenable: _service.maxPlayers,
                      builder: (context, maxPlayers, _) {
                        return ValueListenableBuilder(
                          valueListenable: _service.mapName,
                          builder: (context, mapName, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Code:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        gameId,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isHost) ...[
                                  const Text(
                                    'La partie est',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        (isLocked &&
                                                players.length == maxPlayers)
                                            ? null
                                            : () =>
                                                _service.toggleLock(!isLocked),
                                    child: Text(
                                      isLocked ? 'fermée' : 'ouverte',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    'La partie est',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    isLocked ? ' fermée' : ' ouverte',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Padding(
                                     padding: const EdgeInsets.only(right: 55),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Carte:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          mapName,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlayersList() {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.shade700),
          color: Colors.grey.shade800,
        ),
        child: ValueListenableBuilder(
          valueListenable: _service.players,
          builder: (context, players, _) {
            return ValueListenableBuilder(
              valueListenable: _service.isHost,
              builder: (context, isHost, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.maxPlayers,
                  builder: (context, maxPlayers, _) {
                    return ValueListenableBuilder(
                      valueListenable: _service.isLocked,
                      builder: (context, isLocked, _) {
                        if (players.isEmpty) {
                          return const Center(child: Text('Aucun joueur'));
                        }

                        final showAddButton =
                            isHost &&
                            players.length < maxPlayers &&
                            !isLocked;

                        return ListView.builder(
                          itemCount:
                              showAddButton ? players.length + 1 : players.length,
                          itemBuilder: (ctx, i) {
                            if (i < players.length) {
                              return ValueListenableBuilder(
                                valueListenable:
                                    _service.selectedPlayerSocketId,
                                builder: (context, _, __) {
                                  return _buildPlayerRow(players[i]);
                                },
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: ElevatedButton(
                                onPressed: _onAddVirtualPlayer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  side: BorderSide.none,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Icon(Icons.add, size: 24),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return ValueListenableBuilder(
      valueListenable: _service.isHost,
      builder: (context, isHost, _) {
        return ValueListenableBuilder(
          valueListenable: _service.players,
          builder: (context, players, _) {
            return ValueListenableBuilder(
              valueListenable: _service.isLocked,
              builder: (context, isLocked, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.maxPlayers,
                  builder: (context, maxPlayers, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _service.leaveGame();
                            GoRouter.of(context).go('/');
                          },
                          label: const Text('Quitter la partie'),
                        ),
                        if (isHost && players.length > 1 && isLocked) ...[
                          ElevatedButton(
                            onPressed: _service.initializeGame,
                            child: const Text('Commencer la partie'),
                          ),
                        ] else if (isHost && players.length > 1) ...[
                          const Text(
                            'Vérouillez la salle pour commencer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ] else ...[
                          RotationTransition(
                            turns: _gearController,
                            child: const Image(
                              image: AssetImage('lib/assets/icons/gear.png'),
                              width: 80,
                              height: 80,
                            ),
                          ),
                          const Text(
                            "En attente d'autres joueurs...",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                        Text(
                          '${players.length}/$maxPlayers joueurs',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _onAddVirtualPlayer() async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => ProfileModalWidget(
            activePlayers: _service.players.value,
            onSubmit: _service.addVirtualPlayer,
          ),
    );
  }
}
