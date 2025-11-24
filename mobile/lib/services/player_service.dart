import 'package:flutter/foundation.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class PlayerService {
  factory PlayerService() => _instance;
  PlayerService._();
  static final PlayerService _instance = PlayerService._();

  final ValueNotifier<Player> notifier = ValueNotifier(
    Player(socketId: '', name: '', avatar: Avatar.avatar1, specs: Specs()),
  );

  Player get player => notifier.value;

  void setPlayer(Player newPlayer) {
    DebugLogger.log(
      'PlayerService: setting player ${newPlayer.name}',
      tag: 'PlayerService',
    );
    notifier.value = newPlayer;
  }

  void setPlayerFromJson(Map<String, dynamic> json) {
    try {
      final newPlayer = parsePlayer(json);
      setPlayer(newPlayer);
    } on Exception catch (e) {
      DebugLogger.log(
        'PlayerService: failed to parse player: $e',
        tag: 'PlayerService',
      );
    }
  }

  static Player parsePlayer(Map<String, dynamic> json) {
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
      isEliminated: json['isEliminated'] as bool? ?? false,
      isGameWinner: json['isGameWinner'] as bool? ?? false,
      isObserver: json['isObserver'] as bool? ?? false,
      wasActivePlayer: json['wasActivePlayer'] as bool? ?? false,
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
          inventoryJson
              .map((i) => GameService.parseItemCategory(i.toString()))
              .toList(),
      position:
          positionJson != null
              ? [Coordinate(positionJson['x'] as int, positionJson['y'] as int)]
              : [],
      turn: json['turn'] as int? ?? 0,
      visitedTiles:
          visitedJson
              .map((v) => Coordinate(v['x'] as int, v['y'] as int))
              .toList(),
      profile: GameService.parseProfileType(json['profile'] as String?),
    );
  }

  void clearPlayer() {
    DebugLogger.log('PlayerService: clearing player', tag: 'PlayerService');
    notifier.value = Player(
      socketId: '',
      name: '',
      avatar: Avatar.avatar1,
      specs: Specs(),
    );
  }
}
