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
    } on Exception catch (e) {
      DebugLogger.log(
        'GameService: failed to parse game: $e',
        tag: 'GameService',
      );
    }
  }

  Player? findPlayerBySocketId(String socketId) {
    final game = currentGame;
    if (game == null || socketId.isEmpty) return null;

    try {
      return game.players.firstWhere((p) => p.socketId == socketId);
    } catch (_) {
      return null;
    }
  }

  void clearGame() {
    DebugLogger.log('GameService: clearing game', tag: 'GameService');
    _gameNotifier.value = null;
  }

  String getMapSizeLabel() {
    final game = currentGame;
    if (game == null) return 'Inconnue';

    final mapSize = game.mapSize.x;

    if (mapSize == 10) return 'Petite';
    if (mapSize == 15) return 'Moyenne';
    return 'Grande';
  }

  String getActivePlayerName() {
    final game = currentGame;
    if (game == null || game.players.isEmpty) return 'Aucun';

    try {
      final activePlayer = game.players.firstWhere(
        (p) => p.turn == game.currentTurn,
        orElse: () => game.players.first,
      );
      return activePlayer.name;
    } on Exception {
      return game.players.first.name;
    }
  }

  String? getFlagHolderName() {
    final game = currentGame;
    if (game == null || game.players.isEmpty) return null;

    try {
      final flagHolder = game.players.firstWhere(
        (p) => p.inventory.contains(ItemCategory.flag),
        orElse: () => throw Exception('No flag holder'),
      );
      return flagHolder.name;
    } on Exception {
      return null;
    }
  }

  GameClassic _parseGameFromJson(Map<String, dynamic> json) {
    final mode = json['mode'] as String?;

    final playersJson = json['players'] as List<dynamic>? ?? [];
    final players =
        playersJson
            .map((p) => _parsePlayer(p as Map<String, dynamic>))
            .toList();

    final doorsJson = json['nDoorsManipulated'] as List<dynamic>? ?? [];
    final doors =
        doorsJson.map((d) => Coordinate(d['x'] as int, d['y'] as int)).toList();

    final mapSizeJson = json['mapSize'] as Map<String, dynamic>?;
    final mapSize =
        mapSizeJson != null
            ? Coordinate(mapSizeJson['x'] as int, mapSizeJson['y'] as int)
            : Coordinate(10, 10);

    final tilesJson = json['tiles'] as List<dynamic>? ?? [];
    final tiles =
        tilesJson.map((t) => _parseTile(t as Map<String, dynamic>)).toList();

    final doorTilesJson = json['doorTiles'] as List<dynamic>? ?? [];
    final doorTiles =
        doorTilesJson
            .map((d) => _parseDoorTile(d as Map<String, dynamic>))
            .toList();

    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items =
        itemsJson.map((i) => _parseItem(i as Map<String, dynamic>)).toList();

    final startTilesJson = json['startTiles'] as List<dynamic>? ?? [];
    final startTiles =
        startTilesJson
            .map(
              (s) => Coordinate(
                (s['coordinate']['x'] as int?) ?? (s['x'] as int? ?? 0),
                (s['coordinate']['y'] as int?) ?? (s['y'] as int? ?? 0),
              ),
            )
            .toList();

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
      mapSize: mapSize,
      tiles: tiles,
      doorTiles: doorTiles,
      items: items,
      startTiles: startTiles,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imagePreview: json['imagePreview'] as String? ?? '',
      lastTurnPlayer: json['lastTurnPlayer'] as String? ?? '',
      mode: mode != null ? _parseMode(mode) : null,
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
        mapSize: baseGame.mapSize,
        isLocked: baseGame.isLocked,
        hasStarted: baseGame.hasStarted,
        tiles: baseGame.tiles,
        doorTiles: baseGame.doorTiles,
        items: baseGame.items,
        startTiles: baseGame.startTiles,
        name: baseGame.name,
        description: baseGame.description,
        imagePreview: baseGame.imagePreview,
        mode: Mode.ctf,
        nPlayersCtf: nPlayersCtf,
        lastTurnPlayer: baseGame.lastTurnPlayer,
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
      level: json['level'] as int? ?? 1,
      isActive: json['isActive'] as bool? ?? true,
      isGameWinner: json['isGameWinner'] as bool? ?? false,
      isEliminated: json['isEliminated'] as bool? ?? false,
      wasActivePlayer: json['wasActivePlayer'] as bool? ?? false,
      isObserver: json['isObserver'] as bool? ?? false,
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
          inventoryJson.map((i) => parseItemCategory(i as String)).toList(),
      position:
          positionJson != null
              ? [Coordinate(positionJson['x'] as int, positionJson['y'] as int)]
              : [],
      turn: json['turn'] as int? ?? 0,
      visitedTiles:
          visitedJson
              .map((v) => Coordinate(v['x'] as int, v['y'] as int))
              .toList(),
      profile: parseProfileType(json['profile'] as String?),
    );
  }

  static ItemCategory parseItemCategory(String category) {
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

  static ProfileType parseProfileType(String? profile) {
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

  Tile _parseTile(Map<String, dynamic> json) {
    final coordJson = json['coordinate'] as Map<String, dynamic>;
    final coord = Coordinate(coordJson['x'] as int, coordJson['y'] as int);
    final category = parseTileCategory(json['category'] as String);
    return Tile(coord, category: category);
  }

  DoorTile _parseDoorTile(Map<String, dynamic> json) {
    final coordJson = json['coordinate'] as Map<String, dynamic>;
    final coord = Coordinate(coordJson['x'] as int, coordJson['y'] as int);
    final isOpened = json['isOpened'] as bool? ?? false;
    return DoorTile(coord, isOpened: isOpened);
  }

  Item _parseItem(Map<String, dynamic> json) {
    final coordJson = json['coordinate'] as Map<String, dynamic>;
    final coord = Coordinate(coordJson['x'] as int, coordJson['y'] as int);
    final category = parseItemCategory(json['category'] as String);
    return Item(coord, category);
  }

  static TileCategory parseTileCategory(String category) {
    switch (category.toLowerCase()) {
      case 'water':
        return TileCategory.water;
      case 'ice':
        return TileCategory.ice;
      case 'wall':
        return TileCategory.wall;
      case 'door':
        return TileCategory.door;
      case 'floor':
      default:
        return TileCategory.floor;
    }
  }

  Mode _parseMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'ctf':
        return Mode.ctf;
      case 'classique':
      case 'classic':
      default:
        return Mode.classic;
    }
  }

  bool isPlayerOnIce(Player player) {
    final game = currentGame;
    if (game == null || player.position.isEmpty) return false;

    final playerPos = player.position.first;
    return game.tiles.any(
      (tile) =>
          tile.coordinate.x == playerPos.x &&
          tile.coordinate.y == playerPos.y &&
          tile.category == TileCategory.ice,
    );
  }

  int getMaxAttack(Player player) {
    var maxAttack = player.specs.attack;
    final hasSkates = player.inventory.contains(ItemCategory.iceSkates);

    if (isPlayerOnIce(player) && !hasSkates) {
      maxAttack += ICE_ATTACK_PENALTY;
    }

    return maxAttack;
  }

  int getMaxDefense(Player player) {
    var maxDefense = player.specs.defense;
    final hasSkates = player.inventory.contains(ItemCategory.iceSkates);

    if (isPlayerOnIce(player) && !hasSkates) {
      maxDefense += ICE_DEFENSE_PENALTY;
    }

    return maxDefense;
  }
}
