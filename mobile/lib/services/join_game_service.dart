import 'dart:async';

import 'package:mobile/common/game.dart';
import 'package:mobile/services/auth_service.dart';
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

  void fetchGames() {
    _loadingController.add(true);
    _socketService.send('getGames', null);

    Timer(const Duration(seconds: 3), () {
      if (_loadingController.isClosed) return;
      _loadingController.add(false);
      DebugLogger.log('getGames timeout', tag: 'JoinGameService');
    });
  }

  void handleGamesResponse(dynamic gameRooms) {
    if (gameRooms is List) {
      final games = gameRooms.whereType<Map<String, dynamic>>().toList();

      DebugLogger.log('Received ${games.length} games', tag: 'JoinGameService');
      _gamesController.add(games);
    } else {
      DebugLogger.log(
        'Invalid games response: ${gameRooms.runtimeType}',
        tag: 'JoinGameService',
      );
      _gamesController.add([]);
    }
    _loadingController.add(false);
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

    DebugLogger.log(
      'Sending observeGame for player: ${player['name']}',
      tag: 'JoinGameService',
    );

    final payload = {'player': player, 'gameId': gameId};
    _socketService.send('observeGame', payload);
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

  Map<String, dynamic>? getExistingParticipant(Map<String, dynamic> game) {
    final participants = game['participants'] as List<dynamic>? ?? [];
    final participant = participants.firstWhere((p) {
      if (p is! Map<String, dynamic>) return false;
      return (p['name'] as String? ?? p['username'] as String? ?? '') ==
          (currentUsername ?? '');
    }, orElse: () => null);

    return participant is Map<String, dynamic> ? participant : null;
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

  Future<void> resumeGame(String gameId) async {
    await _ensureSocketConnected();
    DebugLogger.log(
      'Requesting resumeGame for $gameId',
      tag: 'JoinGameService',
    );
    _socketService.send('resumeGame', gameId);
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
    );
  }

  void dispose() {
    _gamesController.close();
    _loadingController.close();
  }
}
