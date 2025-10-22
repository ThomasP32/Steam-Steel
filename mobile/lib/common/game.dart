import 'package:mobile/common/constants.dart';
import 'package:mobile/common/map_types.dart';

class Player {
  Player({
    required this.socketId,
    required this.name,
    required this.avatar,
    this.position = const [],
    this.inventory = const [],
    this.turn = 0,
    this.isActive = true,
    this.visitedTiles = const [],
    this.profile = ProfileType.normal,
    Specs? specs,
  }) : specs = specs ?? Specs();
  String socketId;
  String name;
  Avatar avatar;
  bool isActive;
  Specs specs;
  List<ItemCategory> inventory;
  List<Coordinate> position;
  int turn;
  List<Coordinate> visitedTiles;
  ProfileType profile;
}

enum Avatar {
  avatar1(1),
  avatar2(2),
  avatar3(3),
  avatar4(4),
  avatar5(5),
  avatar6(6),
  avatar7(7),
  avatar8(8),
  avatar9(9),
  avatar10(10),
  avatar11(11),
  avatar12(12);

  const Avatar(this.value);
  final int value;
}

enum Bonus {
  d4(4),
  d6(6);

  const Bonus(this.value);
  final int value;
}

class Specs {
  Specs({
    this.life = 0,
    this.evasions = 0,
    this.speed = 0,
    this.attack = 0,
    this.defense = 0,
    this.attackBonus = Bonus.d4,
    this.defenseBonus = Bonus.d6,
    this.movePoints = 0,
    this.actions = 0,
    this.nVictories = 0,
    this.nDefeats = 0,
    this.nCombats = 0,
    this.nEvasions = 0,
    this.nLifeTaken = 0,
    this.nLifeLost = 0,
    this.nItemsUsed = 0,
  });
  int life;
  int evasions;
  int speed;
  int attack;
  int defense;
  Bonus attackBonus;
  Bonus defenseBonus;
  int movePoints;
  int actions;
  int nVictories;
  int nDefeats;
  int nCombats;
  int nEvasions;
  int nLifeTaken;
  int nLifeLost;
  int nItemsUsed;
}

class GameClassic {
  GameClassic({
    required this.id,
    required this.hostSocketId,
    required this.players,
    required this.currentTurn,
    required this.nDoorsManipulated,
    required this.duration,
    required this.nTurns,
    required this.debug,
    required this.isLocked,
    required this.hasStarted,
    required this.mapSize,
    this.tiles = const [],
    this.doorTiles = const [],
    this.items = const [],
    this.startTiles = const [],
    this.name = '',
    this.description = '',
    this.imagePreview = '',
    this.mode,
  });
  final String id;
  final String hostSocketId;
  final List<Player> players;
  final int currentTurn;
  final List<Coordinate> nDoorsManipulated;
  final int duration;
  final int nTurns;
  final bool debug;
  final bool isLocked;
  final bool hasStarted;
  final Coordinate mapSize;
  final List<Tile> tiles;
  final List<DoorTile> doorTiles;
  final List<Item> items;
  final List<Coordinate> startTiles;
  final String name;
  final String description;
  final String imagePreview;
  final Mode? mode;
}

class GameCtf extends GameClassic {
  GameCtf({
    required super.id,
    required super.hostSocketId,
    required super.players,
    required super.currentTurn,
    required super.nDoorsManipulated,
    required super.duration,
    required super.nTurns,
    required super.debug,
    required super.isLocked,
    required super.hasStarted,
    required super.mapSize,
    required this.nPlayersCtf,
    super.tiles,
    super.doorTiles,
    super.items,
    super.startTiles,
    super.name,
    super.description,
    super.imagePreview,
    super.mode,
  });
  final List<Player> nPlayersCtf;
}
