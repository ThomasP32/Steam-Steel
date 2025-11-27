import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/utils/debug_logger.dart';

class GamePreviewWidget extends StatelessWidget {
  const GamePreviewWidget({
    required this.game,
    required this.onTap,
    this.onJoinGame,
    this.onObserve,
    this.currentUsername,
    super.key,
  });

  final Map<String, dynamic> game;
  final VoidCallback onTap;
  final VoidCallback? onJoinGame;
  final VoidCallback? onObserve;
  final String? currentUsername;

  String get _gameName => game['name'] as String? ?? 'Sans nom';

  String get _gameCode => game['id'] as String? ?? '????';

  int get _maxPlayers {
    final size = game['mapSize'] as Map<String, dynamic>?;
    if (size == null) return 0;
    final x = size['x'] as int? ?? 0;

    if (x == 10) return 2;
    if (x == 15) return 4;
    if (x == 20) return 6;
    return 0;
  }

  int get _activePlayerCount {
    final players = game['players'] as List<dynamic>?;
    if (players == null) return 0;
    return players
        .where(
          (p) => p is Map<String, dynamic> && (p['isActive'] as bool? ?? false),
        )
        .length;
  }

  int get _participantsCount => (game['participants'] as List?)?.length ?? 0;

  bool get _isLocked => game['isLocked'] as bool? ?? false;

  bool get _hasStarted => game['hasStarted'] as bool? ?? false;

  bool get _isFastElimination =>
      (game['settings'] as Map<String, dynamic>?)?['isFastElimination']
          as bool? ??
      false;

  int get _entryFee =>
      (game['settings'] as Map<String, dynamic>?)?['entryFee'] as int? ?? 0;

  bool get _isFull {
    if (_maxPlayers <= 0) return false;
    if (_isFastElimination) {
      return _participantsCount >= _maxPlayers;
    }
    return _activePlayerCount >= _maxPlayers;
  }

  bool get _existingParticipant {
    if (currentUsername == null || currentUsername!.isEmpty) return false;

    final players = game['players'] as List<dynamic>?;
    if (players != null) {
      for (final p in players) {
        if (p is Map<String, dynamic>) {
          final name = p['name'] as String? ?? p['username'] as String? ?? '';
          if (name == currentUsername) return true;
        }
      }
    }

    final participants = game['participants'] as List<dynamic>?;
    if (participants != null) {
      for (final p in participants) {
        if (p is Map<String, dynamic>) {
          final name = p['name'] as String? ?? p['username'] as String? ?? '';
          if (name == currentUsername) return true;
        }
      }
    }

    return false;
  }

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

  bool get _isDropInOut =>
      (game['settings'] as Map<String, dynamic>?)?['isDropInOut'] as bool? ??
      false;

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
        errorBuilder: (_, _, _) => Container(color: Colors.grey[300]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canObserve = _hasStarted;
    DebugLogger.log(
      'GamePreviewWidget: canObserve=$canObserve, isDropInOut=$_isDropInOut, hasStarted=$_hasStarted, isLocked=$_isLocked',
      tag: 'PREVIEW',
    );
    DebugLogger.log('${game['settings']}', tag: 'PREVIEW');
    final canJoin = _hasStarted && _isDropInOut;
    final isJoinable = !_hasStarted && !_isLocked;
    final isDisabled = !canObserve && !isJoinable && !canJoin;

    return SizedBox(
      height: 200,
      child: Card(
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 10, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        '$_activePlayerCount/$_maxPlayers',
                        style: const TextStyle(fontSize: 9),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.map, size: 10, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(_mapSize, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _hasStarted
                              ? AppColors.accentHighlight(context)
                              : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(_status, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                   const SizedBox(height: 2),
                  _entryFee > 0
                      ? Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 10,
                              color: AppColors.accentHighlight(context),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$_entryFee pièces',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.accentHighlight(context),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  if (canJoin) _buildDualButtons() else _buildSingleButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleButton() {
    final canObserve = _hasStarted;
    final isJoinable = !_hasStarted && !_isLocked;
    final isDisabled = !canObserve && !isJoinable;

    return SizedBox(
      width: double.infinity,
      height: 26,
      child: ElevatedButton(
        onPressed:
            isDisabled ? null : (canObserve ? (onObserve ?? onTap) : onTap),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canObserve
                  ? const Color(0xFF1c5276)
                  : isJoinable
                  ? const Color(0xFF125719)
                  : Colors.grey,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
    );
  }

  Widget _buildDualButtons() {
    final rightLabel =
        _existingParticipant
            ? 'Reprendre'
            : _isFull
            ? 'Verrouillée'
            : 'Jouer';
    final rightEnabled = !_isFull || _existingParticipant;
    final rightOnPressed = rightEnabled ? (onJoinGame ?? onTap) : null;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: onObserve ?? onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1c5276),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 2),
              ),
              child: const Text(
                'Observer',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: rightOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    rightEnabled ? const Color(0xFF125719) : Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 2),
              ),
              child: Text(
                rightLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: rightEnabled ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
