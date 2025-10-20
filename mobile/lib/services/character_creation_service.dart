import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/socket_service.dart';

class CharacterCreationService {
  factory CharacterCreationService() => _instance;
  CharacterCreationService._internal();
  static final CharacterCreationService _instance =
      CharacterCreationService._internal();

  final ValueNotifier<Set<int>> unavailableAvatars = ValueNotifier({});
  final ValueNotifier<int> selectedAvatar = ValueNotifier(1);

  StreamSubscription<dynamic>? _currentPlayersSub;
  StreamSubscription<dynamic>? _playerLeftSub;
  String? _currentGameId;

  void startListening(String gameId) {
    if (_currentGameId == gameId) return;
    stopListening();
    _currentGameId = gameId;
    _listenToCurrentPlayers();
    _listenToPlayerLeft();
    SocketService().send('getPlayers', gameId);
  }

  void stopListening() {
    _currentPlayersSub?.cancel();
    _playerLeftSub?.cancel();
    _currentGameId = null;
    unavailableAvatars.value = {};
  }

  void reset() {
    stopListening();
    selectedAvatar.value = 1;
  }

  bool isAvatarAvailable(int avatarId) =>
      !unavailableAvatars.value.contains(avatarId);

  int? findFirstAvailable() {
    for (var i = 1; i <= 12; i++) {
      if (isAvatarAvailable(i)) return i;
    }
    return null;
  }

  void selectAvatar(int avatarId) {
    if (isAvatarAvailable(avatarId)) {
      selectedAvatar.value = avatarId;
    }
  }

  void _listenToCurrentPlayers() {
    _currentPlayersSub?.cancel();
    _currentPlayersSub = SocketService()
        .listen<dynamic>('currentPlayers')
        .listen((data) {
          if (data is! List) return;

          final unavailable = <int>{};
          for (final playerData in data) {
            if (playerData is Map<String, dynamic>) {
              final avatarValue = playerData['avatar'];
              if (avatarValue is int && avatarValue >= 1 && avatarValue <= 12) {
                unavailable.add(avatarValue);
              }
            }
          }

          unavailableAvatars.value = unavailable;
          _ensureValidSelection();
        });
  }

  void _ensureValidSelection() {
    if (!isAvatarAvailable(selectedAvatar.value)) {
      final firstAvailable = findFirstAvailable();
      if (firstAvailable != null) {
        selectedAvatar.value = firstAvailable;
      }
    }
  }

  void _listenToPlayerLeft() {
    _playerLeftSub?.cancel();
    _playerLeftSub = SocketService().listen<dynamic>('playerLeft').listen((_) {
      if (_currentGameId != null) {
        SocketService().send('getPlayers', _currentGameId);
      }
    });
  }

  Map<String, dynamic> buildPlayerPayload({
    required String name,
    required String socketId,
    required int avatar,
    required Specs specs,
  }) {
    return {
      'name': name,
      'socketId': socketId,
      'isActive': true,
      'avatar': avatar,
      'specs': {
        'life': specs.life,
        'speed': specs.speed,
        'attack': specs.attack,
        'defense': specs.defense,
        'attackBonus': specs.attackBonus.value,
        'defenseBonus': specs.defenseBonus.value,
        'movePoints': specs.speed,
        'evasions': DEFAULT_EVASIONS,
        'actions': DEFAULT_ACTIONS,
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
      'profile': ProfileType.normal.value,
    };
  }

  Player buildLocalPlayer({
    required String name,
    required String socketId,
    required int avatar,
    required Specs specs,
  }) {
    return Player(
      socketId: socketId,
      name: name,
      avatar: Avatar.values[(avatar - 1).clamp(0, Avatar.values.length - 1)],
      specs: specs,
    );
  }

  void joinGame({
    required String gameId,
    required String name,
    required String socketId,
    required int avatar,
    required Specs specs,
    required void Function(Player) onSuccess,
    required VoidCallback onTimeout,
  }) {
    final player = buildPlayerPayload(
      name: name,
      socketId: socketId,
      avatar: avatar,
      specs: specs,
    );

    final localPlayer = buildLocalPlayer(
      name: name,
      socketId: socketId,
      avatar: avatar,
      specs: specs,
    );

    final payload = {'gameId': gameId, 'player': player};

    StreamSubscription<dynamic>? youJoinedSub;
    youJoinedSub = SocketService().listen<dynamic>('youJoined').listen((data) {
      if (data is Map<String, dynamic>) {
        final serverPlayer = _parsePlayerFromJson(data);
        onSuccess(serverPlayer ?? localPlayer);
      } else {
        onSuccess(localPlayer);
      }
      youJoinedSub?.cancel();
    });

    SocketService().send('joinGame', payload);

    Future.delayed(const Duration(seconds: 8), () {
      youJoinedSub?.cancel();
      onTimeout();
    });
  }

  Player? _parsePlayerFromJson(Map<String, dynamic> json) {
    try {
      final specs = json['specs'] as Map<String, dynamic>?;
      if (specs == null) return null;

      return Player(
        socketId: json['socketId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatar:
            Avatar.values[((json['avatar'] as int? ?? 1) - 1).clamp(
              0,
              Avatar.values.length - 1,
            )],
        specs: Specs(
          life: specs['life'] as int? ?? DEFAULT_HP,
          speed: specs['speed'] as int? ?? DEFAULT_SPEED,
          attack: specs['attack'] as int? ?? DEFAULT_ATTACK,
          defense: specs['defense'] as int? ?? DEFAULT_DEFENSE,
          attackBonus:
              (specs['attackBonus'] as int?) == 6 ? Bonus.d6 : Bonus.d4,
          defenseBonus:
              (specs['defenseBonus'] as int?) == 6 ? Bonus.d6 : Bonus.d4,
          movePoints: specs['movePoints'] as int? ?? DEFAULT_SPEED,
          evasions: specs['evasions'] as int? ?? DEFAULT_EVASIONS,
          actions: specs['actions'] as int? ?? DEFAULT_ACTIONS,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    stopListening();
    unavailableAvatars.dispose();
    selectedAvatar.dispose();
  }

  Specs assignBonus(Specs specs, String type) {
    if (type == 'life') {
      specs
        ..life = DEFAULT_HP + BONUS
        ..speed = DEFAULT_SPEED;
    } else {
      specs
        ..speed = DEFAULT_SPEED + BONUS
        ..life = DEFAULT_HP;
    }
    return specs;
  }

  Specs assignDice(Specs specs, String which) {
    if (which == 'attack') {
      specs
        ..attackBonus = Bonus.d6
        ..defenseBonus = Bonus.d4;
    } else {
      specs
        ..attackBonus = Bonus.d4
        ..defenseBonus = Bonus.d6;
    }
    return specs;
  }
}
