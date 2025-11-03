import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class WaitingRoomService {
  factory WaitingRoomService() => _instance;
  WaitingRoomService._();
  static final WaitingRoomService _instance = WaitingRoomService._();

  final ValueNotifier<List<Player>> players = ValueNotifier([]);
  final ValueNotifier<String> mapName = ValueNotifier('En attente...');
  final ValueNotifier<bool> isLocked = ValueNotifier(false);
  final ValueNotifier<int> maxPlayers = ValueNotifier(2);
  final ValueNotifier<bool> isHost = ValueNotifier(false);
  final ValueNotifier<String> gameId = ValueNotifier('');
  final ValueNotifier<String?> selectedPlayerSocketId = ValueNotifier(null);

  final _playerService = PlayerService();

  final Map<String, StreamSubscription<dynamic>> _subscriptions = {};

  void initialize(String? initialGameId, String? initialMapName) {
    gameId.value = initialGameId ?? '';

    if (initialMapName != null && initialMapName.isNotEmpty) {
      _createGameForHost(initialMapName);
    } else {
      requestPlayers();
      requestGameData();
    }

    _setupListeners();
  }

  void requestPlayers() {
    if (gameId.value.isEmpty) return;
    try {
      SocketService().send('getPlayers', gameId.value);
    } on Exception catch (e) {
      DebugLogger.log('getPlayers emit failed: $e', tag: 'WaitingRoomService');
    }
  }

  void requestGameData() {
    if (gameId.value.isEmpty) return;
    try {
      SocketService().send('getGameData', gameId.value);
    } on Exception catch (e) {
      DebugLogger.log('getGameData emit failed: $e', tag: 'WaitingRoomService');
    }
  }

  void _setupListeners() {
    _subscriptions['currentPlayers'] = SocketService()
        .listen<dynamic>('currentPlayers')
        .listen(_handleCurrentPlayers);

    _subscriptions['playerLeft'] = SocketService()
        .listen<dynamic>('playerLeft')
        .listen((_) => requestPlayers());

    _subscriptions['playerJoined'] = SocketService()
        .listen<dynamic>('playerJoined')
        .listen((_) => requestPlayers());

    _subscriptions['currentGame'] = SocketService()
        .listen<dynamic>('currentGame')
        .listen(_handleCurrentGame);

    _subscriptions['gameLockToggled'] = SocketService()
        .listen<dynamic>('gameLockToggled')
        .listen(_handleGameLockToggled);
  }

  void _handleCurrentPlayers(dynamic data) {
    try {
      final list =
          (data is List)
              ? data.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];

      final parsed =
          list.map((j) {
            final specsJson = j['specs'] as Map<String, dynamic>? ?? {};
            return Player(
              socketId: (j['socketId'] ?? '').toString(),
              name: (j['name'] ?? '').toString(),
              avatar: _avatarFromRaw(j['avatar']),
              isActive: j['isActive'] as bool? ?? true,
              isGameWinner: j['isGameWinner'] as bool? ?? false,
              specs: Specs(
                life: specsJson['life'] as int? ?? 0,
                speed: specsJson['speed'] as int? ?? 0,
                attack: specsJson['attack'] as int? ?? 0,
                defense: specsJson['defense'] as int? ?? 0,
                attackBonus:
                    (specsJson['attackBonus'] as int? ?? 4) == 6
                        ? Bonus.d6
                        : Bonus.d4,
                defenseBonus:
                    (specsJson['defenseBonus'] as int? ?? 6) == 6
                        ? Bonus.d6
                        : Bonus.d4,
                evasions: specsJson['evasions'] as int? ?? 0,
                actions: specsJson['actions'] as int? ?? 0,
                movePoints: specsJson['movePoints'] as int? ?? 0,
                nVictories: specsJson['nVictories'] as int? ?? 0,
                nDefeats: specsJson['nDefeats'] as int? ?? 0,
                nCombats: specsJson['nCombats'] as int? ?? 0,
                nEvasions: specsJson['nEvasions'] as int? ?? 0,
                nLifeTaken: specsJson['nLifeTaken'] as int? ?? 0,
                nLifeLost: specsJson['nLifeLost'] as int? ?? 0,
                nItemsUsed: specsJson['nItemsUsed'] as int? ?? 0,
              ),
              inventory:
                  (j['inventory'] as List<dynamic>? ?? [])
                      .map((i) => GameService.parseItemCategory(i.toString()))
                      .toList(),
              position:
                  (j['position'] as Map<String, dynamic>?) != null
                      ? [
                        Coordinate(
                          (j['position'] as Map<String, dynamic>)['x'] as int,
                          (j['position'] as Map<String, dynamic>)['y'] as int,
                        ),
                      ]
                      : [],
              turn: j['turn'] as int? ?? 0,
              visitedTiles:
                  (j['visitedTiles'] as List<dynamic>? ?? [])
                      .map((v) => Coordinate(v['x'] as int, v['y'] as int))
                      .toList(),
              profile: GameService.parseProfileType(j['profile'] as String?),
            );
          }).toList();

      players.value = parsed;

      if (selectedPlayerSocketId.value != null &&
          !parsed.any((p) => p.socketId == selectedPlayerSocketId.value)) {
        selectedPlayerSocketId.value = null;
      }

      if (players.value.length == maxPlayers.value &&
          !isLocked.value &&
          isHost.value) {
        toggleLock(true);
      }
    } on Exception catch (e) {
      DebugLogger.log(
        'currentPlayers parse failed: $e',
        tag: 'WaitingRoomService',
      );
    }
  }

  void _handleCurrentGame(dynamic data) {
    try {
      if (data is! Map<String, dynamic>) return;

      final mapSizeData = data['mapSize'] as Map<String, dynamic>?;
      if (mapSizeData != null) {
        final x = mapSizeData['x'] as int?;
        if (x != null) {
          maxPlayers.value = _getMaxPlayersFromMapSize(x);
        }
      }

      final nameData = data['name'] as String?;
      if (nameData != null && nameData.isNotEmpty) {
        mapName.value = nameData;
      }

      final isLockedData = data['isLocked'] as bool?;
      if (isLockedData != null) {
        isLocked.value = isLockedData;
      }
    } on Exception catch (e) {
      DebugLogger.log(
        'currentGame parse failed: $e',
        tag: 'WaitingRoomService',
      );
    }
  }

  void _handleGameLockToggled(dynamic payload) {
    final locked =
        (payload is bool && payload) ||
        (payload is String && payload.toLowerCase() == 'true');
    isLocked.value = locked;
  }

  int _getMaxPlayersFromMapSize(int size) {
    switch (size) {
      case 10:
        return 2;
      case 15:
        return 4;
      case 20:
        return 6;
      default:
        return 2;
    }
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

  String generateGameId() {
    const minCode = 1000;
    const maxCode = 9999;

    final random = Random();
    final number = minCode + random.nextInt(maxCode - minCode + 1);

    return number.toString();
  }

  Future<void> _createGameForHost(String mapNameParam) async {
    try {
      final newGameId = generateGameId();
      final storedPlayer = _playerService.notifier.value;

      if (storedPlayer == null) {
        throw Exception('No player configured');
      }

      Map<String, dynamic>? fullMapData;
      var mapData = <String, dynamic>{'x': 10, 'y': 10};

      try {
        final maps = await ApiClient().getMaps();
        final foundMap =
            maps.firstWhere(
                  (m) => m['name'] == mapNameParam,
                  orElse: () => null,
                )
                as Map<String, dynamic>?;

        if (foundMap != null && foundMap.containsKey('mapSize')) {
          fullMapData = foundMap;
          final size = foundMap['mapSize'] as Map<String, dynamic>?;
          if (size != null) {
            mapData = size;
          }
        }
      } on Exception catch (e) {
        DebugLogger.log(
          'Failed to fetch map data: $e',
          tag: 'WaitingRoomService',
        );
      }

      final playerPayload = {
        'name': storedPlayer.name,
        'socketId': SocketService().socketId ?? storedPlayer.socketId,
        'isActive': storedPlayer.isActive,
        'avatar': storedPlayer.avatar.index + 1,
        'specs': {
          'life': storedPlayer.specs.life,
          'speed': storedPlayer.specs.speed,
          'attack': storedPlayer.specs.attack,
          'defense': storedPlayer.specs.defense,
          'attackBonus': storedPlayer.specs.attackBonus.value,
          'defenseBonus': storedPlayer.specs.defenseBonus.value,
          'movePoints': storedPlayer.specs.speed,
          'evasions': storedPlayer.specs.evasions,
          'actions': storedPlayer.specs.actions,
          'nVictories': 0,
          'nDefeats': 0,
          'nCombats': 0,
          'nEvasions': 0,
          'nLifeTaken': 0,
          'nLifeLost': 0,
          'nItemsUsed': 0,
        },
        'inventory': <dynamic>[],
        'position': {'x': 0, 'y': 0},
        'initialPosition': {'x': 0, 'y': 0},
        'turn': 0,
        'visitedTiles': <dynamic>[],
        'profile': storedPlayer.profile.value,
      };

      final gamePayload = <String, dynamic>{
        'id': newGameId,
        'name': mapNameParam,
        'mapSize': mapData,
        'players': [playerPayload],
        'isLocked': false,
        'hasStarted': false,
        'currentTurn': 0,
        'nDoorsManipulated': <dynamic>[],
        'duration': 0,
        'nTurns': 0,
        'debug': false,
        'settings': {'isFastElimination': false, 'isFriendsOnly': false},
        if (fullMapData != null) ...{
          'tiles': fullMapData['tiles'] ?? <dynamic>[],
          'startTiles': fullMapData['startTiles'] ?? <dynamic>[],
          'doorTiles': fullMapData['doorTiles'] ?? <dynamic>[],
          'items': fullMapData['items'] ?? <dynamic>[],
          'description': fullMapData['description'] ?? '',
          'imagePreview': fullMapData['imagePreview'] ?? '',
          'mode': fullMapData['mode'] ?? 'classic',
        },
      };

      isHost.value = true;
      gameId.value = newGameId;
      mapName.value = mapNameParam;
      maxPlayers.value = _getMaxPlayersFromMapSize(
        (mapData['x'] as int?) ?? 10,
      );
      isLocked.value = false;
      players.value = [storedPlayer];

      SocketService().send('createGame', gamePayload);
    } on Exception catch (e) {
      DebugLogger.log('createGame failed: $e', tag: 'WaitingRoomService');
      rethrow;
    }
  }

  void toggleLock(bool lock) {
    if (gameId.value.isEmpty) return;
    try {
      final payload = <String, dynamic>{
        'gameId': gameId.value,
        'isLocked': lock,
      };
      SocketService().send('toggleGameLockState', payload);
    } on Exception catch (e) {
      DebugLogger.log(
        'toggleGameLockState emit failed: $e',
        tag: 'WaitingRoomService',
      );
    }
  }

  void kickPlayer(String playerSocketId) {
    if (gameId.value.isEmpty || playerSocketId.isEmpty) return;

    try {
      final payload = <String, dynamic>{
        'playerId': playerSocketId,
        'gameId': gameId.value,
      };
      SocketService().send('kickPlayer', payload);
      selectedPlayerSocketId.value = null;
    } on Exception catch (e) {
      DebugLogger.log('kickPlayer emit failed: $e', tag: 'WaitingRoomService');
    }
  }

  void initializeGame() {
    if (gameId.value.isEmpty) return;

    try {
      SocketService().send('initializeGame', gameId.value);
    } on Exception catch (e) {
      DebugLogger.log(
        'initializeGame emit failed: $e',
        tag: 'WaitingRoomService',
      );
    }
  }

  void leaveGame() {
    if (gameId.value.isEmpty) return;

    try {
      SocketService().send('leaveGame', gameId.value);
    } on Exception catch (e) {
      DebugLogger.log('leaveGame error: $e', tag: 'WaitingRoomService');
    }
  }

  Future<void> addVirtualPlayer(Player virtualPlayer) async {
    if (gameId.value.isEmpty) return;

    try {
      final payload = <String, dynamic>{
        'player': {
          'name': virtualPlayer.name,
          'socketId': virtualPlayer.socketId,
          'isActive': virtualPlayer.isActive,
          'avatar': virtualPlayer.avatar.index + 1,
          'specs': {
            'life': virtualPlayer.specs.life,
            'speed': virtualPlayer.specs.speed,
            'attack': virtualPlayer.specs.attack,
            'defense': virtualPlayer.specs.defense,
            'attackBonus': virtualPlayer.specs.attackBonus.value,
            'defenseBonus': virtualPlayer.specs.defenseBonus.value,
            'movePoints': virtualPlayer.specs.speed,
            'evasions': virtualPlayer.specs.evasions,
            'actions': virtualPlayer.specs.actions,
            'nVictories': 0,
            'nDefeats': 0,
            'nCombats': 0,
            'nEvasions': 0,
            'nLifeTaken': 0,
            'nLifeLost': 0,
            'nItemsUsed': 0,
          },
          'inventory': <dynamic>[],
          'position': {'x': 0, 'y': 0},
          'initialPosition': {'x': 0, 'y': 0},
          'turn': 0,
          'visitedTiles': <dynamic>[],
          'profile': virtualPlayer.profile.value,
        },
        'gameId': gameId.value,
      };
      SocketService().send('joinGame', payload);
    } on Exception catch (e) {
      DebugLogger.log('joinGame emit failed: $e', tag: 'WaitingRoomService');
    }
  }

  void reset() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();

    players.value = [];
    mapName.value = 'En attente...';
    isLocked.value = false;
    maxPlayers.value = 2;
    isHost.value = false;
    gameId.value = '';
    selectedPlayerSocketId.value = null;
  }
}
