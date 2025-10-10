import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({required this.gameId, super.key});

  final String gameId;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final List<Player> _players = [];
  bool _isLocked = false;
  final String _mapLabel = 'CTF';

  StreamSubscription<dynamic>? _playersSub;
  StreamSubscription<dynamic>? _lockedSub;
  StreamSubscription<dynamic>? _closedSub;

  @override
  void initState() {
    super.initState();

    try {
      SocketService().send('getPlayers', widget.gameId);
    } on Exception catch (e) {
      DebugLogger.log('getPlayers emit failed: $e', tag: 'WaitingRoom');
    }

    _playersSub = SocketService().listen<dynamic>('currentPlayers').listen((
      data,
    ) {
      try {
        final list =
            (data is List)
                ? data.whereType<Map<String, dynamic>>().toList()
                : <Map<String, dynamic>>[];
        final parsed =
            list.map((j) {
              return Player(
                socketId: (j['socketId'] ?? '').toString(),
                name: (j['name'] ?? '').toString(),
                avatar: _avatarFromRaw(j['avatar']),
              );
            }).toList();
        if (!mounted) return;
        setState(() {
          _players
            ..clear()
            ..addAll(parsed);
        });
      } on Exception catch (e) {
        DebugLogger.log('currentPlayers parse failed: $e', tag: 'WaitingRoom');
      }
    });

    _lockedSub = SocketService().listen<dynamic>('gameLocked').listen((
      payload,
    ) {
      //TODO: improve this we know what the payload should be
      final locked =
          (payload is bool && payload) ||
          (payload is String && payload.toLowerCase() == 'true');
      if (!mounted) return;
      setState(() => _isLocked = locked);
    });

    _closedSub = SocketService().listen<dynamic>('gameClosed').listen((_) {
      if (!mounted) return;
      try {
        GoRouter.of(context).go('/');
      } on Exception catch (e) {
        DebugLogger.log('navigate home failed: $e', tag: 'WaitingRoom');
      }
    });
  }

  Avatar _avatarFromRaw(dynamic raw) {
    if (raw == null) return Avatar.avatar1;
    if (raw is int) {
      final idx = (raw - 1).clamp(0, Avatar.values.length - 1);
      return Avatar.values[idx];
    }
    if (raw is String) {
      return Avatar.values.firstWhere(
        (a) => a.name.toLowerCase() == raw.toLowerCase(),
        orElse: () => Avatar.avatar1,
      );
    }
    return Avatar.avatar1;
  }

  @override
  void dispose() {
    _playersSub?.cancel();
    _lockedSub?.cancel();
    _closedSub?.cancel();
    super.dispose();
  }

  Widget _buildPlayerRow(Player p) {
    final idx = (p.avatar.index + 1).clamp(1, 12);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade900,
        radius: 22,
        child: Image.asset(
          'lib/assets/characters/$idx.png',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(p.name.isNotEmpty ? p.name : 'Joueur'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Salle d'attente")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_isLocked)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.redAccent,
                child: const Text(
                  'Fermée',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Code:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.gameId,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Carte:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _mapLabel,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade700),
                        color: Colors.grey.shade800,
                      ),
                      child:
                          _players.isEmpty
                              ? const Center(child: Text('Aucun joueur'))
                              : ListView.builder(
                                itemCount: _players.length,
                                itemBuilder:
                                    (ctx, i) => _buildPlayerRow(_players[i]),
                              ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            try {
                              SocketService().send('leaveGame', widget.gameId);
                            } on Exception catch (_) {}
                            GoRouter.of(context).go('/');
                          },
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Quitter la partie'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
