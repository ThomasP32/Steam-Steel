import 'package:flutter/foundation.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/utils/debug_logger.dart';

class GameService {
  factory GameService() => _instance;
  GameService._();
  static final GameService _instance = GameService._();

  final ValueNotifier<GameClassic?> _gameNotifier = ValueNotifier(null);

  ValueNotifier<GameClassic?> get notifier => _gameNotifier;

  GameClassic? get currentGame => _gameNotifier.value;

  void setGame(GameClassic game) {
    DebugLogger.log('GameService: setting game ${game.id}', tag: 'GameService');
    _gameNotifier.value = game;
  }

  void updateFromJson(Map<String, dynamic> json) {
    try {
      final game = _parseGameFromJson(json);
      setGame(game);
    } catch (e) {
      DebugLogger.log(
        'GameService: failed to parse game: $e',
        tag: 'GameService',
      );
    }
  }

  void clearGame() {
    DebugLogger.log('GameService: clearing game', tag: 'GameService');
    _gameNotifier.value = null;
  }

  String getMapSizeLabel() {
    final game = currentGame;
    if (game == null) return 'Inconnue';

    // The size is determined by tiles dimensions - using dynamic access for now
    final size = (game as dynamic).size as String?;
    if (size != null) {
      if (size == 'small') return 'Petite';
      if (size == 'medium') return 'Moyenne';
      if (size == 'large') return 'Grande';
    }

    return 'Inconnue';
  }

  String getActivePlayerName() {
    final game = currentGame;
    if (game == null || game.players.isEmpty) return 'Aucun';

    // Find player with current turn
    try {
      final activePlayer = game.players.firstWhere(
        (p) => p.turn == game.currentTurn,
        orElse: () => game.players.first,
      );
      return activePlayer.name;
    } catch (e) {
      return game.players.first.name;
    }
  }

  GameClassic _parseGameFromJson(Map<String, dynamic> json) {
    final mode = json['mode'] as String?;

    // Parse players
    final playersJson = json['players'] as List<dynamic>? ?? [];
    final players =
        playersJson
            .map((p) => _parsePlayer(p as Map<String, dynamic>))
            .toList();

    // Parse coordinates
    final doorsJson = json['nDoorsManipulated'] as List<dynamic>? ?? [];
    final doors =
        doorsJson.map((d) => Coordinate(d['x'] as int, d['y'] as int)).toList();

    final baseGame = GameClassic(
      id: json['id'] as String,
      hostSocketId: json['hostSocketId'] as String,
      players: players,
      currentTurn: json['currentTurn'] as int? ?? 0,
      nDoorsManipulated: doors,
      duration: json['duration'] as int? ?? 0,
      nTurns: json['nTurns'] as int? ?? 0,
      debug: json['debug'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      hasStarted: json['hasStarted'] as bool? ?? false,
    );

    if (mode == 'ctf') {
      final nPlayersCtfJson = json['nPlayersCtf'] as List<dynamic>? ?? [];
      final nPlayersCtf =
          nPlayersCtfJson
              .map((p) => _parsePlayer(p as Map<String, dynamic>))
              .toList();

      return GameCtf(
        id: baseGame.id,
        hostSocketId: baseGame.hostSocketId,
        players: baseGame.players,
        currentTurn: baseGame.currentTurn,
        nDoorsManipulated: baseGame.nDoorsManipulated,
        duration: baseGame.duration,
        nTurns: baseGame.nTurns,
        debug: baseGame.debug,
        isLocked: baseGame.isLocked,
        hasStarted: baseGame.hasStarted,
        mode: Mode.ctf,
        nPlayersCtf: nPlayersCtf,
      );
    }

    return baseGame;
  }

  Player _parsePlayer(Map<String, dynamic> json) {
    final specsJson = json['specs'] as Map<String, dynamic>? ?? {};
    final inventoryJson = json['inventory'] as List<dynamic>? ?? [];
    final positionJson = json['position'] as Map<String, dynamic>?;
    final visitedJson = json['visitedTiles'] as List<dynamic>? ?? [];

    return Player(
      socketId: json['socketId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: Avatar.values[(json['avatar'] as int? ?? 1) - 1],
      isActive: json['isActive'] as bool? ?? true,
      specs: Specs(
        life: specsJson['life'] as int? ?? 0,
        evasions: specsJson['evasions'] as int? ?? 0,
        speed: specsJson['speed'] as int? ?? 0,
        attack: specsJson['attack'] as int? ?? 0,
        defense: specsJson['defense'] as int? ?? 0,
        attackBonus:
            (specsJson['attackBonus'] as int? ?? 4) == 6 ? Bonus.d6 : Bonus.d4,
        defenseBonus:
            (specsJson['defenseBonus'] as int? ?? 6) == 6 ? Bonus.d6 : Bonus.d4,
        movePoints: specsJson['movePoints'] as int? ?? 0,
        actions: specsJson['actions'] as int? ?? 0,
        nVictories: specsJson['nVictories'] as int? ?? 0,
        nDefeats: specsJson['nDefeats'] as int? ?? 0,
        nCombats: specsJson['nCombats'] as int? ?? 0,
        nEvasions: specsJson['nEvasions'] as int? ?? 0,
        nLifeTaken: specsJson['nLifeTaken'] as int? ?? 0,
        nLifeLost: specsJson['nLifeLost'] as int? ?? 0,
        nItemsUsed: specsJson['nItemsUsed'] as int? ?? 0,
      ),
      inventory:
          inventoryJson.map((i) => _parseItemCategory(i as String)).toList(),
      position:
          positionJson != null
              ? [Coordinate(positionJson['x'] as int, positionJson['y'] as int)]
              : [],
      turn: json['turn'] as int? ?? 0,
      visitedTiles:
          visitedJson
              .map((v) => Coordinate(v['x'] as int, v['y'] as int))
              .toList(),
      profile: _parseProfileType(json['profile'] as String?),
    );
  }

  ItemCategory _parseItemCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sword':
        return ItemCategory.sword;
      case 'armor':
        return ItemCategory.armor;
      case 'flask':
        return ItemCategory.flask;
      case 'wallbreaker':
        return ItemCategory.wallBreaker;
      case 'iceskates':
        return ItemCategory.iceSkates;
      case 'amulet':
        return ItemCategory.amulet;
      case 'flag':
        return ItemCategory.flag;
      default:
        return ItemCategory.random;
    }
  }

  ProfileType _parseProfileType(String? profile) {
    if (profile == null) return ProfileType.normal;
    switch (profile.toLowerCase()) {
      case 'aggressive':
        return ProfileType.aggressive;
      case 'defensive':
        return ProfileType.defensive;
      default:
        return ProfileType.normal;
    }
  }
}
