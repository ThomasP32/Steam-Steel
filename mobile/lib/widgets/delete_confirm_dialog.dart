import 'dart:async';

import 'package:flutter/material.dart';

Future<bool?> showDeleteConfirmDialog(
  BuildContext context, {
  String title = 'Supprimer ce message?',
  String message = 'Voulez-vous vraiment supprimer ce message?',
}) {
  final completer = Completer<bool?>();

  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return GestureDetector(
        onTap: () {
          if (!completer.isCompleted) completer.complete(false);
          entry.remove();
        },
        child: Material(
          color: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
              child: Material(
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(message),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            if (!completer.isCompleted) {
                              completer.complete(false);
                            }
                            entry.remove();
                          },
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (!completer.isCompleted) {
                              completer.complete(true);
                            }
                            entry.remove();
                          },
                          child: const Text('Supprimer'),
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
  return completer.future;
}
