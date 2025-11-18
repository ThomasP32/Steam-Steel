import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';

class EndgameService {
  factory EndgameService() {
    return _instance;
  }

  EndgameService._();
  static final EndgameService _instance = EndgameService._();

  final _authService = AuthService();

  final ValueNotifier<LevelUpData?> levelUpNotifier = ValueNotifier(null);
  StreamSubscription<dynamic>? _levelUpSubscription;

  void initialize() {
    _listenToLevelUpEvents();
  }

  void _listenToLevelUpEvents() {
    _levelUpSubscription?.cancel();

    _levelUpSubscription = SocketService()
        .listen<dynamic>('playerLeveledUp')
        .listen((data) {
          if (data is Map<String, dynamic>) {
            final newLevel = data['newLevel'] as int?;
            final bannerUnlocked = data['bannerUnlocked'] as bool?;

            if (newLevel != null) {
              levelUpNotifier.value = LevelUpData(
                newLevel: newLevel,
                bannerUnlocked: bannerUnlocked ?? false,
              );
            }
          }
        });
  }

  Future<void> updateUserStats(GameClassic game, String playerSocketId) async {
    final player = game.players.firstWhere(
      (p) => p.socketId == playerSocketId,
      orElse: () => game.players.first,
    );

    final hasWon = player.isGameWinner;
    final gameMode = game.mode == Mode.ctf ? 'ctf' : 'classique';

    await _authService.updateStats(
      mode: gameMode,
      isWin: hasWon,
      duration: game.duration,
    );
  }

  void reset() {
    levelUpNotifier.value = null;
    _levelUpSubscription?.cancel();
  }

  void dispose() {
    _levelUpSubscription?.cancel();
    levelUpNotifier.dispose();
  }

  double getPlayerTilePercentage(Player player, GameClassic game) {
    final totalTiles = game.mapSize.x * game.mapSize.y;
    if (totalTiles == 0) return 0;
    return (player.visitedTiles.length / totalTiles) * 100;
  }

  double getGameTilePercentage(GameClassic game) {
    final totalTiles = game.mapSize.x * game.mapSize.y;
    if (totalTiles == 0) return 0;

    final uniqueTiles = <String>{};
    for (final player in game.players) {
      for (final tile in player.visitedTiles) {
        uniqueTiles.add('${tile.x},${tile.y}');
      }
    }

    return (uniqueTiles.length / totalTiles) * 100;
  }

  double getDoorPercentage(GameClassic game) {
    final totalDoors = game.doorTiles.length;
    if (totalDoors == 0) return 0;

    final uniqueDoors = <String>{};
    for (final door in game.nDoorsManipulated) {
      uniqueDoors.add('${door.x},${door.y}');
    }

    return (uniqueDoors.length / totalDoors) * 100;
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}min ${secs}s';
  }
}

class LevelUpData {
  const LevelUpData({required this.newLevel, required this.bannerUnlocked});

  final int newLevel;
  final bool bannerUnlocked;
}
