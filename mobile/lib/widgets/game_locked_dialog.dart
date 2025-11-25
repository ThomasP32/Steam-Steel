import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/services/socket_service.dart';

enum GameLockedAction { goToMenu, retry }

Future<GameLockedAction?> showGameLockedDialog(BuildContext context) {
  final completer = Completer<GameLockedAction?>();

  final overlay = Overlay.of(context, rootOverlay: true);

  StreamSubscription<dynamic>? gameClosedSub;
  gameClosedSub = SocketService().listen<dynamic>('gameClosed').listen((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    gameClosedSub?.cancel();
    if (overlay.mounted) {}
  });

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, minWidth: 350),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentHighlight(ctx),
                  width: 3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'La partie est verrouillée',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppColors.accentHighlight(ctx),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentHighlight(ctx),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (!completer.isCompleted) {
                                  completer.complete(GameLockedAction.goToMenu);
                                }
                              },
                              child: const Text(
                                'Menu principal',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentHighlight(ctx),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                if (!completer.isCompleted) {
                                  completer.complete(GameLockedAction.retry);
                                }
                              },
                              child: const Text(
                                'Réessayer',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  completer.future.then((_) {
    gameClosedSub?.cancel();
    try {
      entry.remove();
    } catch (_) {}
  });

  return completer.future;
}
