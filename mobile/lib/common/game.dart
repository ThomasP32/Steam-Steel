import 'package:mobile/common/constants.dart';
import 'package:mobile/common/map_types.dart';

class Player {
  Player({
    required this.socketId,
    required this.name,
    required this.avatar,
    required this.specs,
    this.isActive = true,
    this.isGameWinner = false,
    this.isObserver = false,
    this.isEliminated = false,
    this.wasActivePlayer = false,
    this.inventory = const [],
    this.position = const [],
    this.turn = 0,
    this.visitedTiles = const [],
    this.profile = ProfileType.normal,
    this.level = 1,
  });

  final String socketId;
  final String name;
  final Avatar avatar;
  final bool isActive;
  final bool isEliminated;
  final bool isGameWinner;
  final bool wasActivePlayer;
  final bool isObserver;
  final Specs specs;
  final List<ItemCategory> inventory;
  final List<Coordinate> position;
  final int turn;
  final List<Coordinate> visitedTiles;
  final ProfileType profile;
  final int level;
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
  avatar12(12),
  avatar13(13),
  avatar14(14),
  avatar15(15),
  avatar16(16),
  avatar17(17);

  const Avatar(this.value);
  final int value;
}

enum Bonus {
  d4(4),
  d6(6);

  const Bonus(this.value);
  final int value;
}

enum ProfilePicture {
  profile1(1),
  profile2(2),
  profile3(3),
  profile4(4),
  profile5(5),
  profile6(6),
  profile7(7),
  profile8(8),
  profile9(9),
  profile10(10),
  profile11(11),
  profile12(12),
  profile13(13);

  const ProfilePicture(this.value);
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

class GameSettings {
  GameSettings({
    this.isFastElimination = false,
    this.isDropInOut = false,
    this.isFriendsOnly = false,
    this.entryFee = 0,
  });

  final bool isFastElimination;
  final bool isDropInOut;
  final bool isFriendsOnly;
  final int entryFee;

  Map<String, dynamic> toJson() => {
    'isFastElimination': isFastElimination,
    'isDropInOut': isDropInOut,
    'isFriendsOnly': isFriendsOnly,
    'entryFee': entryFee,
  };
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
    this.settings,
    this.lastTurnPlayer,
    this.participants = const [],
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
  final GameSettings? settings;
  final String? lastTurnPlayer;
  final List<Player> participants;
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
    super.settings,
    super.lastTurnPlayer,
    super.participants,
  });
  final List<Player> nPlayersCtf;
}

enum GameEndReason {
  noWinnerTermination('no_winner_termination'),
  victoryElimination('victory_elimination'),
  victoryCombatWins('victory_combat_wins'),
  victoryCtfFlag('victory_ctf_flag'),
  victoryLastPlayerStanding('victory_last_player_standing'),
  ongoing('ongoing');

  const GameEndReason(this.value);
  final String value;

  static GameEndReason fromString(String value) {
    return GameEndReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GameEndReason.ongoing,
    );
  }
}