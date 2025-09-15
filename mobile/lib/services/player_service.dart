import 'package:flutter/foundation.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class PlayerService {
  factory PlayerService() => _instance;
  PlayerService._internal() {
    resetPlayer();
  }
  static final PlayerService _instance = PlayerService._internal();

  late Player player;

  /// Notifier you can listen to from widgets to react to changes.
  final ValueNotifier<Player?> notifier = ValueNotifier<Player?>(null);

  void createPlayer() {
    final playerSpecs = Specs(
      life: player.specs.life,
      speed: player.specs.speed,
      attack: player.specs.attack,
      defense: player.specs.defense,
      attackBonus: player.specs.attackBonus,
      defenseBonus: player.specs.defenseBonus,
      movePoints: player.specs.speed,
      evasions: DEFAULT_EVASIONS,
      actions: DEFAULT_ACTIONS,
    );

    final p = Player(
      socketId: SocketService().socketId ?? '',
      name: player.name,
      avatar: player.avatar,
      specs: playerSpecs,
    );

    player = p;
    notifier.value = player;
  }

  void setPlayer(Player p) {
    player = p;
    notifier.value = player;
  }

  void setPlayerName(String name) {
    player.name = name.trim();
    notifier.value = player;
  }

  void setPlayerAvatar(Avatar avatar) {
    player.avatar = avatar;
    notifier.value = player;
  }

  void resetPlayer() {
    final playerSpecs = Specs(
      life: DEFAULT_HP,
      speed: DEFAULT_SPEED,
      attack: DEFAULT_ATTACK,
      defense: DEFAULT_DEFENSE,
      attackBonus: Bonus.d6,
      defenseBonus: Bonus.d4,
      evasions: DEFAULT_EVASIONS,
      actions: DEFAULT_ACTIONS,
    );

    final p = Player(
      socketId: '',
      name: '',
      avatar: Avatar.avatar1,
      specs: playerSpecs,
    );

    player = p;
    notifier.value = player;
  }

  /// Convenience: update from a JSON-like map (server payload).
  void setPlayerFromJson(Map<String, dynamic> j) {
    try {
      final specsJson = (j['specs'] as Map<String, dynamic>?) ?? {};
      int readInt(dynamic v, [int fallback = 0]) {
        if (v == null) return fallback;
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v) ?? fallback;
        return fallback;
      }

      final specs = Specs(
        life: readInt(specsJson['life'], DEFAULT_HP),
        speed: readInt(specsJson['speed'], DEFAULT_SPEED),
        attack: readInt(specsJson['attack'], DEFAULT_ATTACK),
        defense: readInt(specsJson['defense'], DEFAULT_DEFENSE),
        attackBonus:
            (readInt(specsJson['attackBonus'], Bonus.d4.value) ==
                    Bonus.d6.value)
                ? Bonus.d6
                : Bonus.d4,
        defenseBonus:
            (readInt(specsJson['defenseBonus'], Bonus.d6.value) ==
                    Bonus.d6.value)
                ? Bonus.d6
                : Bonus.d4,
        movePoints: readInt(specsJson['movePoints']),
        evasions: readInt(specsJson['evasions'], DEFAULT_EVASIONS),
        actions: readInt(specsJson['actions'], DEFAULT_ACTIONS),
      );

      // socketId and name may come as int or string depending on server; coerce to String
      final socketId = j['socketId']?.toString() ?? '';
      final name = j['name']?.toString() ?? '';

      // avatar may be sent as number (index) or string enum name
      final avatarRaw = j['avatar'];
      Avatar avatar;
      if (avatarRaw is int) {
        final idx = (avatarRaw - 1).clamp(0, Avatar.values.length - 1);
        avatar = Avatar.values[idx];
      } else if (avatarRaw is String) {
        avatar = Avatar.values.firstWhere(
          (a) =>
              a.name == avatarRaw ||
              a.name.toLowerCase() == avatarRaw.toLowerCase(),
          orElse: () => Avatar.avatar1,
        );
      } else {
        avatar = Avatar.avatar1;
      }

      final p = Player(
        socketId: socketId,
        name: name,
        avatar: avatar,
        specs: specs,
      );

      setPlayer(p);
    } on Exception catch (e) {
      DebugLogger.log(
        'PlayerService.setPlayerFromJson: exception $e',
        tag: 'PlayerService',
      );
    }
  }
}
