import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/player_service.dart';

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Test Waiting Room Screen : $gameId'),
                    const SizedBox(height: 8),
                    Text('Player : ${PlayerService().player.name}'),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<Player?>(
                      valueListenable: PlayerService().notifier,
                      builder: (ctx, player, _) {
                        if (player == null) return const Text('No player yet');

                        // derive avatar asset index from enum
                        final avatarIndex = (player.avatar.index + 1).clamp(
                          1,
                          12,
                        );

                        Widget statRow(String label, int value, Color color) {
                          final pct = (value / 10).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$label : $value'),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: pct,
                                  color: color,
                                  backgroundColor: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            Text('Player : ${player.specs.defenseBonus.value}'),
                            const SizedBox(height: 8),
                            Container(
                              width: 160,
                              height: 160,
                              color: Colors.grey.shade900,
                              child: Image.asset(
                                'lib/assets/characters/$avatarIndex.png',
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (ctx, err, stack) => Image.asset(
                                      'lib/assets/characters/unlocked.png',
                                      width: 120,
                                      height: 120,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            statRow('Vie', player.specs.life, Colors.red),
                            statRow(
                              'Rapidité',
                              player.specs.speed,
                              Colors.blue,
                            ),
                            statRow(
                              'Attaque',
                              player.specs.attack,
                              Colors.orange,
                            ),
                            statRow(
                              'Défense',
                              player.specs.defense,
                              Colors.green,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.home),
                      label: const Text('Go Home'),
                      onPressed: () => context.go('/'),
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
}
