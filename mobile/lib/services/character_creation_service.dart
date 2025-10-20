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

  bool isAvatarAvailable(int avatarId) =>
      !unavailableAvatars.value.contains(avatarId);

  int? findFirstAvailable() {
    for (var i = 1; i <= 12; i++) {
      if (isAvatarAvailable(i)) return i;
    }
    return null;
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
              if (avatarValue is int) {
                unavailable.add(avatarValue);
              }
            }
          }

          unavailableAvatars.value = unavailable;
        });
  }

  void _listenToPlayerLeft() {
    _playerLeftSub?.cancel();
    _playerLeftSub = SocketService().listen<dynamic>('playerLeft').listen((_) {
      if (_currentGameId != null) {
        SocketService().send('getPlayers', _currentGameId);
      }
    });
  }

  void dispose() {
    stopListening();
    unavailableAvatars.dispose();
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
