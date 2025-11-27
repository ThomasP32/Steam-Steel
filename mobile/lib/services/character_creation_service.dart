import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class CharacterCreationService {
  factory CharacterCreationService() => _instance;
  CharacterCreationService._internal() {
    AuthService().notifier.addListener(_onUserChanged);
  }
  static final CharacterCreationService _instance =
      CharacterCreationService._internal();

  final ValueNotifier<Set<int>> unavailableAvatars = ValueNotifier({});
  final ValueNotifier<int> selectedAvatar = ValueNotifier(1);
  final ValueNotifier<Set<int>> ownedAvatars = ValueNotifier({});

  StreamSubscription<dynamic>? _currentPlayersSub;
  StreamSubscription<dynamic>? _playerLeftSub;
  String? _currentGameId;

  int get totalAvatars => 17;

  void _onUserChanged() {
    initializeOwnedAvatars();
  }

  void initializeOwnedAvatars() {
    final user = AuthService().notifier.value;
    if (user == null) {
      ownedAvatars.value = {};
      return;
    }

    final owned = <int>{};
    for (var i = 1; i <= 12; i++) {
      owned.add(i);
    }

    for (final item in user.shopItems) {
      if (item.itemId.startsWith('avatar_')) {
        final avatarNumber = int.tryParse(
          item.itemId.replaceAll('avatar_', ''),
        );
        if (avatarNumber != null) {
          final characterId = 12 + avatarNumber;
          owned.add(characterId);
        }
      }
    }

    ownedAvatars.value = owned;
    DebugLogger.log(
      'Owned avatars initialized: $owned',
      tag: 'CharacterCreationService',
    );
  }

  void startListening(String gameId) {
    if (_currentGameId == gameId) return;
    stopListening();
    _currentGameId = gameId;
    initializeOwnedAvatars();
    unavailableAvatars.value = {};
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
    unavailableAvatars.value = {};
    selectedAvatar.value = 1;
    _currentGameId = null;
  }

  bool isAvatarAvailable(int avatarId) =>
      !unavailableAvatars.value.contains(avatarId);

  bool isAvatarOwned(int avatarId) => ownedAvatars.value.contains(avatarId);

  int? findFirstAvailable() {
    for (var i = 1; i <= totalAvatars; i++) {
      if (isAvatarAvailable(i) && isAvatarOwned(i)) return i;
    }
    return null;
  }

  void selectAvatar(int avatarId) {
    if (isAvatarAvailable(avatarId) && isAvatarOwned(avatarId)) {
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
              if (avatarValue is int &&
                  avatarValue >= 1 &&
                  avatarValue <= totalAvatars) {
                unavailable.add(avatarValue);
              }
            }
          }

          unavailableAvatars.value = unavailable;
          _ensureValidSelection();
        });
  }

  void _ensureValidSelection() {
    if (!isAvatarAvailable(selectedAvatar.value) ||
        !isAvatarOwned(selectedAvatar.value)) {
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
    required int level,
    bool isObserver = false,
  }) {
    return {
      'name': name,
      'socketId': socketId,
      'isActive': !isObserver,
      'isEliminated': isObserver,
      'avatar': avatar,
      'level': level,
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
    required int level,
    bool isObserver = false,
  }) {
    return Player(
      socketId: socketId,
      name: name,
      avatar: Avatar.values[(avatar - 1).clamp(0, Avatar.values.length - 1)],
      level: level,
      position: [Coordinate(0, 0)],
      inventory: [],
      visitedTiles: [],
      specs: specs,
      isActive: !isObserver,
      isEliminated: isObserver,
    );
  }

  Future<void> observeGame({
    required String gameId,
    required String name,
    required String socketId,
    required int avatar,
    required Specs specs,
    required int level,
    required void Function(Player) onSuccess,
    required VoidCallback onTimeout,
  }) async {
    await _ensureSocketConnection(socketId, onTimeout);

    final player = buildPlayerPayload(
      name: name,
      socketId: SocketService().socketId ?? socketId,
      avatar: avatar,
      specs: specs,
      level: level,
      isObserver: true,
    );

    final localPlayer = buildLocalPlayer(
      name: name,
      socketId: SocketService().socketId ?? socketId,
      avatar: avatar,
      specs: specs,
      level: level,
      isObserver: true,
    );

    final payload = {'gameId': gameId, 'player': player};

    _handleJoinResponse(
      event: 'observeGame',
      payload: payload,
      gameId: gameId,
      localPlayer: localPlayer,
      onSuccess: onSuccess,
      onTimeout: onTimeout,
    );
  }

  Future<void> _ensureSocketConnection(
    String socketId,
    VoidCallback onTimeout,
  ) async {
    if (SocketService().socketId == null) {
      DebugLogger.log(
        '[CharacterCreationService] Socket not connected, reconnecting...',
      );
      await SocketService().connect();

      var attempts = 0;
      while (SocketService().socketId == null && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      DebugLogger.log(
        '[CharacterCreationService] Reconnected after ${attempts * 100}ms, new socketId: ${SocketService().socketId}',
      );

      if (SocketService().socketId == null) {
        DebugLogger.log(
          '[CharacterCreationService] Failed to reconnect socket after 3 seconds',
        );
        onTimeout();
      }
    }
  }

  void _handleJoinResponse({
    required String event,
    required Map<String, dynamic> payload,
    required String gameId,
    required Player localPlayer,
    required void Function(Player) onSuccess,
    required VoidCallback onTimeout,
  }) {
    StreamSubscription<dynamic>? youJoinedSub;
    StreamSubscription<dynamic>? gameLockedSub;

    youJoinedSub = SocketService().listen<dynamic>('youJoined').listen((data) {
      DebugLogger.log('[CharacterCreationService] Received youJoined event');
      try {
        gameLockedSub?.cancel();
      } on Exception catch (_) {}
      if (data is Map<String, dynamic>) {
        final serverPlayer = _parsePlayerFromJson(data);
        onSuccess(serverPlayer ?? localPlayer);
      } else {
        onSuccess(localPlayer);
      }

      ChannelService().createPartyChannel(gameId);

      youJoinedSub?.cancel();
    });

    gameLockedSub = SocketService().listen<dynamic>('gameLocked').listen((
      reason,
    ) {
      DebugLogger.log(
        '[CharacterCreationService] Received gameLocked event: $reason',
      );
      try {
        youJoinedSub?.cancel();
      } on Exception catch (_) {}
      gameLockedSub?.cancel();
      onTimeout();
    });

    SocketService().send(event, payload);
  }

  Future<void> joinGame({
    required String gameId,
    required String name,
    required String socketId,
    required int avatar,
    required Specs specs,
    required int level,
    required void Function(Player) onSuccess,
    required VoidCallback onTimeout,
  }) async {
    await _ensureSocketConnection(socketId, onTimeout);

    final player = buildPlayerPayload(
      name: name,
      socketId: SocketService().socketId ?? socketId,
      avatar: avatar,
      specs: specs,
      level: level,
    );

    final localPlayer = buildLocalPlayer(
      name: name,
      socketId: SocketService().socketId ?? socketId,
      avatar: avatar,
      specs: specs,
      level: level,
    );

    final payload = {'gameId': gameId, 'player': player};

    _handleJoinResponse(
      event: 'joinGame',
      payload: payload,
      gameId: gameId,
      localPlayer: localPlayer,
      onSuccess: onSuccess,
      onTimeout: onTimeout,
    );
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
        level: json['level'] as int? ?? 1,
        isActive: json['isActive'] as bool? ?? true,
        isEliminated: json['isEliminated'] as bool? ?? false,
        wasActivePlayer: json['wasActivePlayer'] as bool? ?? false,
        isObserver: json['isObserver'] as bool? ?? false,
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
    } on Exception {
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
