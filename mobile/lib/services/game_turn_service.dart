import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/common/game.dart';

class GameTurnService {
  factory GameTurnService() => _instance;
  GameTurnService._();
  static final GameTurnService _instance = GameTurnService._();

  final _playerTurnNotifier = ValueNotifier<String>('');
  final _yourTurnNotifier = ValueNotifier<bool>(false);
  final _possibleMovesNotifier = ValueNotifier<Map<String, dynamic>>({});
  final _possibleOpponentsNotifier = ValueNotifier<List<dynamic>>([]);
  final _possibleDoorsNotifier = ValueNotifier<List<DoorTile>>([]);
  final _possibleWallsNotifier = ValueNotifier<List<Tile>>([]);
  final _gameFinishedNotifier = ValueNotifier<bool>(false);
  final _gameFinishedDataNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final _gameEndReasonNotifier = ValueNotifier<GameEndReason?>(null);
  final _observationModeNotifier = ValueNotifier<bool>(false);
  final _observationMessageNotifier = ValueNotifier<String>('');
  String _currentGameId = '';
  bool _pendingInventoryModal = false;

  ValueNotifier<String> get playerTurnNotifier => _playerTurnNotifier;
  ValueNotifier<bool> get yourTurnNotifier => _yourTurnNotifier;
  ValueNotifier<Map<String, dynamic>> get possibleMovesNotifier =>
      _possibleMovesNotifier;
  ValueNotifier<List<dynamic>> get possibleOpponentsNotifier =>
      _possibleOpponentsNotifier;
  ValueNotifier<List<DoorTile>> get possibleDoorsNotifier =>
      _possibleDoorsNotifier;
  ValueNotifier<List<Tile>> get possibleWallsNotifier => _possibleWallsNotifier;
  ValueNotifier<bool> get gameFinishedNotifier => _gameFinishedNotifier;
  ValueNotifier<Map<String, dynamic>?> get gameFinishedDataNotifier =>
      _gameFinishedDataNotifier;
  ValueNotifier<GameEndReason?> get gameEndReasonNotifier =>
      _gameEndReasonNotifier;
  ValueNotifier<bool> get observationModeNotifier => _observationModeNotifier;
  ValueNotifier<String> get observationMessageNotifier =>
      _observationMessageNotifier;

  String get currentPlayerTurn => _playerTurnNotifier.value;
  bool get isYourTurn => _yourTurnNotifier.value;
  bool get hasCombatAvailable =>
      _possibleOpponentsNotifier.value.isNotEmpty && isYourTurn;

  // ignore: avoid_setters_without_getters : dont worry
  set pendingInventoryModal(bool value) {
    _pendingInventoryModal = value;
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Map<String, bool> possibleActions = {
    'combat': false,
    'door': false,
    'wall': false,
  };

  void initialize(String gameId) {
    dispose();
    _currentGameId = gameId;

    _subscriptions
      ..add(
        SocketService().listen<dynamic>('yourTurn').listen((data) {
          if (data is Map<String, dynamic>) {
            final playerName = data['name'] as String?;

            if (playerName != null) {
              _playerTurnNotifier.value = playerName;
              _yourTurnNotifier.value = true;
              _pendingInventoryModal = false;

              _possibleMovesNotifier.value = {};
              DebugLogger.log(
                'GameTurnService: Sending getCombats from yourTurn event',
                tag: 'GameTurnService',
              );
              SocketService().send('getCombats', gameId);
            }

            PlayerService().setPlayerFromJson(data);
          }
        }),
      )
      ..add(
        SocketService().listen<String>('playerTurn').listen((playerName) {
          _playerTurnNotifier.value = playerName;
          _yourTurnNotifier.value = false;
          _pendingInventoryModal = false;
          _possibleMovesNotifier.value = {};
          _possibleOpponentsNotifier.value = [];
          _possibleDoorsNotifier.value = [];
          _possibleWallsNotifier.value = [];
        }),
      )
      ..add(
        SocketService().listen<dynamic>('startTurn').listen((data) {
          if (data is Map<String, dynamic>) {
            final playerName = data['name'] as String?;
            if (playerName != null) {
              _playerTurnNotifier.value = playerName;
              final currentPlayer = PlayerService().player;
              _yourTurnNotifier.value = playerName == currentPlayer.name;
              _pendingInventoryModal = false;
            }
          }
          if (isYourTurn) {
            possibleActions['combat'] = true;
            SocketService().send('getCombats', gameId);
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('yourCombats').listen((data) {
          DebugLogger.log(
            'GameTurnService: yourCombats event -> $data (isYourTurn: $isYourTurn)',
            tag: 'GameTurnService',
          );
          if (data is List) {
            _possibleOpponentsNotifier.value = data;
            DebugLogger.log(
              'GameTurnService: ${data.length} possible opponents, notifier updated',
              tag: 'GameTurnService',
            );
          } else {
            _possibleOpponentsNotifier.value = [];
            DebugLogger.log(
              'GameTurnService: No opponents (data is not a List)',
              tag: 'GameTurnService',
            );
          }
          if (data is List && data.isEmpty) {
            possibleActions['combat'] = false;
          }
          SocketService().send('getAdjacentDoors', gameId);
        }),
      )
      ..add(
        SocketService().listen<dynamic>('yourDoors').listen((data) {
          _handleDoorsResponse(data);
          final player = PlayerService().player;
          if (player.inventory.contains(ItemCategory.wallBreaker) &&
              player.specs.actions > 0) {
            SocketService().send('getAdjacentWalls', gameId);
          } else {
            SocketService().send('getMovements', gameId);
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('yourWalls').listen((data) {
          _handleWallsResponse(data);
          SocketService().send('getMovements', gameId);
        }),
      )
      ..add(
        SocketService().listen<dynamic>('playerPossibleMoves').listen((data) {
          if (data is List) {
            final movesMap = <String, dynamic>{};
            for (final item in data) {
              if (item is List && item.length == 2) {
                final firstElement = item[0];
                final value = item[1];

                if (firstElement is String) {
                  movesMap[firstElement] = value;
                }
              }
            }

            _possibleMovesNotifier.value = movesMap;

            final player = PlayerService().player;

            if (movesMap.length == 1 && player.specs.movePoints == 0) {
              _checkAndEndTurn();
            }
          }
        }),
      )
      ..add(
        SocketService().listen<dynamic>('gameFinished').listen((data) {
          if (data is Map<String, dynamic>) {
            _gameFinishedDataNotifier.value = data;
            
            final reasonString = data['reason'] as String?;
            if (reasonString != null) {
              _gameEndReasonNotifier.value = GameEndReason.fromString(reasonString);
            }
          }
          _gameFinishedNotifier.value = true;
        }),
      )
      ..add(
        SocketService().listen<dynamic>('playerEnteredObservationMode').listen((
          data,
        ) {
          DebugLogger.log(
            'GameTurnService: playerEnteredObservationMode -> $data',
            tag: 'GameTurnService',
          );
          if (data is Map<String, dynamic>) {
            final message =
                data['message'] as String? ?? 'Vous êtes en mode observation';
            _observationMessageNotifier.value = message;
            _observationModeNotifier.value = true;

            final playerData = data['player'] as Map<String, dynamic>?;
            if (playerData != null) {
              PlayerService().setPlayerFromJson(playerData);
            }
          }
        }),
      );

    final currentPlayer = PlayerService().player;
    final game = GameService().currentGame;
    if (game != null) {
      final activePlayer = game.players.firstWhere(
        (p) => p.turn == game.currentTurn,
        orElse: () => currentPlayer,
      );

      if (activePlayer.name == currentPlayer.name) {
        _yourTurnNotifier.value = true;
        _playerTurnNotifier.value = currentPlayer.name;
        DebugLogger.log(
          "GameTurnService: It's your turn! Requesting combat state",
          tag: 'GameTurnService',
        );
        SocketService().send('getCombats', gameId);
      }
    }
  }

  void _handleDoorsResponse(dynamic data) {
    if (data is List) {
      final doors =
          data
              .map(
                (d) => DoorTile(
                  Coordinate(
                    d['coordinate']['x'] as int,
                    d['coordinate']['y'] as int,
                  ),
                  isOpened: d['isOpened'] as bool? ?? false,
                ),
              )
              .toList();
      _possibleDoorsNotifier.value = doors;
      possibleActions['door'] = doors.isNotEmpty;
    } else {
      _possibleDoorsNotifier.value = [];
      possibleActions['door'] = false;
    }
  }

  void _handleWallsResponse(dynamic data) {
    if (data is List) {
      final walls =
          data
              .map(
                (w) => Tile(
                  Coordinate(
                    w['coordinate']['x'] as int,
                    w['coordinate']['y'] as int,
                  ),
                  category: GameService.parseTileCategory(
                    w['category'] as String,
                  ),
                ),
              )
              .toList();
      _possibleWallsNotifier.value = walls;
      possibleActions['wall'] = walls.isNotEmpty;
    } else {
      _possibleWallsNotifier.value = [];
      possibleActions['wall'] = false;
    }
  }

  void endTurn(String gameId) {
    _possibleMovesNotifier.value = {};
    SocketService().send('endTurn', gameId);
  }

  void notifyInventoryActionCompleted() {
    _pendingInventoryModal = false;
    final player = PlayerService().player;
    if (isYourTurn && player.specs.movePoints == 0) {
      endTurn(_currentGameId);
    }
  }

  void toggleDoor(DoorTile door) {
    if (possibleActions['door'] ?? false) {
      SocketService().send('toggleDoor', {
        'gameId': _currentGameId,
        'door': {
          'coordinate': {'x': door.coordinate.x, 'y': door.coordinate.y},
          'isOpened': door.isOpened,
        },
      });
      possibleActions['door'] = false;
      _possibleMovesNotifier.value = {};

      _checkAndEndTurn();
    }
  }

  void breakWall(Tile wall) {
    if (possibleActions['wall'] ?? false) {
      SocketService().send('breakWall', {
        'gameId': _currentGameId,
        'wall': {
          'coordinate': {'x': wall.coordinate.x, 'y': wall.coordinate.y},
          'category': wall.category.toString().split('.').last,
        },
      });
      possibleActions['wall'] = false;
      _possibleMovesNotifier.value = {};

      _checkAndEndTurn();
    }
  }

  void _checkAndEndTurn() {
    final player = PlayerService().player;
    final hasAvailableActions = possibleActions.values.any((v) => v);

    if (player.specs.movePoints == 0 && player.specs.actions == 0 ||
        player.specs.movePoints == 0 &&
            !hasAvailableActions &&
            !_pendingInventoryModal) {
      endTurn(_currentGameId);
    }
  }

  void resumeTurn() {
    if (isYourTurn) {
      _possibleDoorsNotifier.value = [];
      _possibleWallsNotifier.value = [];

      final player = PlayerService().player;
      if (player.specs.actions > 0) {
        SocketService().send('getCombats', _currentGameId);
      } else if (player.specs.movePoints > 0) {
        SocketService().send('getMovements', _currentGameId);
      }
    }
  }

  void checkDoorsAfterMove() {
    if (isYourTurn) {
      final player = PlayerService().player;
      DebugLogger.log(
        'GameTurnService: checkDoorsAfterMove - actions: ${player.specs.actions}',
        tag: 'GameTurnService',
      );
      if (player.specs.actions > 0) {
        SocketService().send('getAdjacentDoors', _currentGameId);
      } else {
        _possibleDoorsNotifier.value = [];
        possibleActions['door'] = false;
      }
    }
  }

  void startCombat(String gameId, dynamic opponent) {
    DebugLogger.log(
      'GameTurnService: starting combat with opponent',
      tag: 'GameTurnService',
    );
    SocketService().send('startCombat', {
      'gameId': gameId,
      'opponent': opponent,
    });
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _playerTurnNotifier.value = '';
    _yourTurnNotifier.value = false;
    _possibleMovesNotifier.value = {};
    _possibleOpponentsNotifier.value = [];
    _possibleDoorsNotifier.value = [];
    _possibleWallsNotifier.value = [];
    _gameFinishedNotifier.value = false;
    _gameFinishedDataNotifier.value = null;
    _gameEndReasonNotifier.value = null;
    _observationModeNotifier.value = false;
    _observationMessageNotifier.value = '';
    _pendingInventoryModal = false;
    possibleActions = {'combat': false, 'door': false, 'wall': false};
  }

  bool isPossibleMove(int row, int col) {
    final key = '$row,$col';
    return _possibleMovesNotifier.value.containsKey(key);
  }
}
