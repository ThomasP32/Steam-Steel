import 'dart:async';

import 'package:mobile/common/game.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class JoinGameService {
  factory JoinGameService() => _instance;
  JoinGameService._();
  static final JoinGameService _instance = JoinGameService._();

  final SocketService _socketService = SocketService();
  final _gamesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();

  Stream<List<Map<String, dynamic>>> get gamesStream => _gamesController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;

  String? get currentUsername => AuthService().notifier.value?.username;

  Future<void> fetchGames() async {
    _loadingController.add(true);

    await FriendService().getFriends();

    await _socketService
        .emitWithAck<dynamic>('getGames')
        .then(handleGamesResponse)
        .catchError((_) {
          _loadingController.add(false);
          _gamesController.add([]);
        })
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            _loadingController.add(false);
            _gamesController.add([]);
          },
        );
  }

  void handleGamesResponse(dynamic gameRooms) {
    if (gameRooms is List) {
      final games = gameRooms.whereType<Map<String, dynamic>>().toList();
      final filteredGames = _filterFriendsOnlyGames(games);
      _gamesController.add(filteredGames);
    } else {
      _gamesController.add([]);
    }
    _loadingController.add(false);
  }

  List<Map<String, dynamic>> _filterFriendsOnlyGames(
    List<Map<String, dynamic>> games,
  ) {
    final myFriends = FriendService().getCachedFriends();
    final myFriendUsernames = myFriends.map((f) => f.username).toSet();

    final filtered =
        games.where((game) {
          final settings = game['settings'] as Map<String, dynamic>?;
          final isFriendsOnly = settings?['isFriendsOnly'] as bool? ?? false;

          if (!isFriendsOnly) {
            return true;
          }

          final players = game['players'] as List<dynamic>?;
          if (players != null && players.isNotEmpty) {
            final hostPlayer = players[0] as Map<String, dynamic>?;
            final hostName = hostPlayer?['name'] as String?;

            if (hostName == currentUsername) {
              return true;
            }

            if (hostName != null && myFriendUsernames.contains(hostName)) {
              return true;
            }
          }

          return false;
        }).toList();

    return filtered;
  }

  Future<void> accessGame(String gameCode) async {
    await _ensureSocketConnected();
    _socketService.send('accessGame', gameCode);
  }

  Future<void> observeGame({
    required String gameId,
    required Map<String, dynamic> player,
  }) async {
    await _ensureSocketConnected();

    final observerPlayer = Map<String, dynamic>.from(player);
    observerPlayer['isObserver'] = true;
    observerPlayer['isEliminated'] = false;

    DebugLogger.log(
      'Sending observeGame with player: ${observerPlayer['name']}, '
      'isObserver: ${observerPlayer['isObserver']}, '
      'isEliminated: ${observerPlayer['isEliminated']}',
      tag: 'JoinGameService',
    );

    _socketService.send('observeGame', {
      'player': observerPlayer,
      'gameId': gameId,
    });
  }

  bool hasExistingPlayer(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>? ?? [];
    return players.any((p) {
      if (p is! Map<String, dynamic>) return false;
      return p['name'] == currentUsername;
    });
  }

  Map<String, dynamic>? getExistingPlayer(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>? ?? [];
    final player = players.firstWhere((p) {
      if (p is! Map<String, dynamic>) return false;
      return p['name'] == currentUsername;
    }, orElse: () => null);

    return player is Map<String, dynamic> ? player : null;
  }

  String extractMapName(Map<String, dynamic> game) {
    final mapData = game['map'];
    if (mapData is Map<String, dynamic>) {
      return mapData['name'] as String? ?? '';
    } else if (mapData is String) {
      return mapData;
    }
    return game['name'] as String? ?? '';
  }

  void handleYouJoined(Map<String, dynamic> data) {
    final updatedGame = data['updatedGame'] as Map<String, dynamic>?;
    final updatedPlayer = data['updatedPlayer'] as Map<String, dynamic>?;

    if (updatedGame == null) {
      DebugLogger.log('youJoined missing game data', tag: 'JoinGameService');
      return;
    }

    if (updatedPlayer != null) {
      PlayerService().setPlayerFromJson(updatedPlayer);
    }
    GameService().updateFromJson(updatedGame);

    DebugLogger.log('Game and player data updated', tag: 'JoinGameService');
  }

  String buildGameRoute(Map<String, dynamic> game) {
    final gameId = game['id'] as String?;
    final mapName = extractMapName(game);
    return '/game/$gameId/$mapName';
  }

  Future<void> _ensureSocketConnected() async {
    if (_socketService.socketId != null) return;

    DebugLogger.log('Reconnecting socket...', tag: 'JoinGameService');
    await _socketService.connect();

    var attempts = 0;
    while (_socketService.socketId == null && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (_socketService.socketId == null) {
      throw Exception('Failed to connect socket after 3 seconds');
    }

    DebugLogger.log(
      'Socket reconnected: ${_socketService.socketId}',
      tag: 'JoinGameService',
    );
  }

  Future<void> resumeGame({
    required String gameId,
    required Map<String, dynamic> player,
  }) async {
    await _ensureSocketConnected();

    DebugLogger.log(
      'Resuming game with player: ${player['name']}, '
      'isEliminated: ${player['isEliminated']}, '
      'isObserver: ${player['isObserver']}',
      tag: 'JoinGameService',
    );

    _socketService.send('resumeGame', {'player': player, 'gameId': gameId});
  }

  Future<void> joinGame({
    required String gameId,
    required Map<String, dynamic> player,
  }) async {
    await _ensureSocketConnected();
    DebugLogger.log(
      'Sending joinGame for player: ${player['name']}',
      tag: 'JoinGameService',
    );
    final payload = {'gameId': gameId, 'player': player};
    _socketService.send('joinGame', payload);
  }

  GameSettings? extractGameSettings(Map<String, dynamic> game) {
    final settingsMap = game['settings'] as Map<String, dynamic>?;
    if (settingsMap == null) return null;

    return GameSettings(
      isFastElimination: settingsMap['isFastElimination'] as bool? ?? false,
      isDropInOut: settingsMap['isDropInOut'] as bool? ?? false,
      isFriendsOnly: settingsMap['isFriendsOnly'] as bool? ?? false,
      entryFee: settingsMap['entryFee'] as int? ?? 0,
    );
  }

  Map<String, dynamic> createMinimalObserverPlayer() {
    final username = currentUsername ?? 'Observer';
    final socketId = _socketService.socketId ?? '';

    return {
      'name': username,
      'socketId': socketId,
      'level': 1,
      'isActive': false,
      'isEliminated': false,
      'isObserver': true,
      'avatar': 1,
      'specs': {
        'life': 0,
        'evasions': 0,
        'speed': 0,
        'attack': 0,
        'defense': 0,
        'attackBonus': 4,
        'defenseBonus': 6,
        'movePoints': 0,
        'actions': 0,
        'nVictories': 0,
        'nDefeats': 0,
        'nCombats': 0,
        'nEvasions': 0,
        'nLifeTaken': 0,
        'nLifeLost': 0,
        'nItemsUsed': 0,
      },
      'inventory': [],
      'position': {'x': 0, 'y': 0},
      'initialPosition': {'x': 0, 'y': 0},
      'turn': 0,
      'visitedTiles': [],
      'profile': 'normal',
    };
  }

  bool isPlayerEliminated(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>? ?? [];
    final participant = players.firstWhere((p) {
      return p['name'] == currentUsername;
    }, orElse: () => null);

    if (participant is Map<String, dynamic>) {
      return participant['isEliminated'] as bool? ?? false;
    }
    return false;
  }

  bool isPlayerInGame(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>? ?? [];
    return players.any((p) {
      return p['name'] == currentUsername;
    });
  }

  void dispose() {
    _gamesController.close();
    _loadingController.close();
  }
}
