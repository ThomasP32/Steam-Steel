import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile/utils/debug_logger.dart';

class GamePreviewWidget extends StatelessWidget {
  const GamePreviewWidget({required this.game, required this.onTap, super.key});

  final Map<String, dynamic> game;
  final VoidCallback onTap;

  String get _gameName => game['name'] as String? ?? 'Sans nom';

  String get _gameCode => game['id'] as String? ?? '????';

  int get _playerCount => (game['players'] as List?)?.length ?? 0;

  int get _maxPlayers {
    final size = game['mapSize'] as Map<String, dynamic>?;
    if (size == null) return 0;
    final x = size['x'] as int? ?? 0;

    if (x == 10) return 2;
    if (x == 15) return 4;
    if (x == 20) return 6;
    return 0;
  }

  bool get _isLocked => game['isLocked'] as bool? ?? false;

  bool get _hasStarted => game['hasStarted'] as bool? ?? false;

  String get _mapSize {
    final size = game['mapSize'] as Map<String, dynamic>?;
    if (size == null) return 'Inconnue';
    final x = size['x'] as int? ?? 0;

    if (x == 10) return 'Petite';
    if (x == 15) return 'Moyenne';
    if (x == 20) return 'Grande';
    return 'Inconnue';
  }

  String? get _imagePreview => game['imagePreview'] as String?;

  String get _status => _hasStarted ? 'En cours' : 'En attente';

  Widget _buildImage() {
    if (_imagePreview == null || _imagePreview!.isEmpty) {
      return Container(color: Colors.grey[300]);
    }
    try {
      if (_imagePreview!.startsWith('data:image')) {
        final parts = _imagePreview!.split(',');
        final base64Str = parts.length > 1 ? parts[1] : parts[0];
        final bytes = base64Decode(base64Str);
        return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain);
      }
      final maybeBytes = base64Decode(_imagePreview!);
      return Image.memory(Uint8List.fromList(maybeBytes), fit: BoxFit.contain);
    } on Exception catch (e) {
      DebugLogger.log('Failed to decode image: $e', tag: 'GamePreviewWidget');
      return Image.network(
        _imagePreview!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canObserve = _hasStarted;
    final isJoinable = !_hasStarted && !_isLocked;
    final isDisabled = !canObserve && !isJoinable;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDisabled ? Colors.red.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Text(
              _gameCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(),
                          if (isDisabled)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _gameName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.people, size: 10, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      '$_playerCount/$_maxPlayers',
                      style: const TextStyle(fontSize: 9),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.map, size: 10, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(_mapSize, style: const TextStyle(fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _hasStarted ? Colors.orange : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(_status, style: const TextStyle(fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: isDisabled ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canObserve
                              ? Colors.orange
                              : isJoinable
                              ? Colors.blue
                              : Colors.grey,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    ),
                    child: Text(
                      canObserve
                          ? 'Observer'
                          : isJoinable
                          ? 'Rejoindre'
                          : 'Verrouillée',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDisabled ? Colors.grey.shade600 : Colors.white,
                      ),
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
}
