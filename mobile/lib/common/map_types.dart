// ignore_for_file: non_constant_identifier_names : const

class Coordinate {
  Coordinate(this.x, this.y);
  int x;
  int y;
}

enum TileCategory {
  water('water'),
  ice('ice'),
  wall('wall'),
  floor('floor'),
  door('door');

  const TileCategory(this.value);
  final String value;
}

enum Mode {
  ctf('ctf'),
  classic('classique');

  const Mode(this.value);
  final String value;
}

enum ItemCategory {
  armor('armor'),
  sword('sword'),
  flask('flask'),
  wallBreaker('wallbreaker'),
  iceSkates('iceskates'),
  amulet('amulet'),
  random('randomitem'),
  flag('flag'),
  startingPoint('startingPoint');

  const ItemCategory(this.value);
  final String value;
}

enum GameDescriptions {
  amulet(
    "Amulette de Résilience : Augmente votre vitalité de 2 lorsque vous affrontez un adversaire avec plus d'attaque.",
  ),
  armor(
    'Armure Renforcée : +2 en défense, mais réduit votre vitesse de 1. Conçue pour les stratèges prudents.',
  ),
  flag(
    'Drapeau de Victoire : Capturez-le et ramenez-le à votre point de départ pour triompher.',
  ),
  iceSkates(
    'Patins Stabilisateurs : Immunisé aux pénalités sur glace. Glissez avec maîtrise.',
  ),
  sword(
    "Lame d'Agilité : +2 en attaque et +1 en vitesse. Parfait pour un combat rapide et décisif.",
  ),
  wallBreaker(
    'Destructeur de Murs : Détruit instantanément tous les murs adjacents. Ouvrez votre chemin avec style.',
  ),
  flask(
    'Potion de Résurrection : Lorsque vous tombez à 2 vies en combat, gagnez un boost de +2 en attaque pour un dernier effort héroïque.',
  ),
  random(
    'Une boîte mystère contenant un objet aléatoire. Qui sait ce que vous trouverez ?',
  ),

  waterTile(
    "Un déplacement sur une tuile d'eau nécessite 2 points de mouvements.",
  ),
  iceTile(
    "Un déplacement sur une tuile de glace ne nécessite aucun point de mouvement, mais a un risque de chute qui s'élève à 10%.",
  ),
  wallTile("Aucun déplacement n'est possible sur ou à travers un mur."),
  floorTile(
    'Un déplacement sur une tuile de terrain nécessite 1 point de mouvement.',
  ),

  closedDoor(
    'Une porte fermée ne peut être franchie, mais peut être ouverte par une action.',
  ),
  openedDoor(
    'Une porte ouverte peut être franchie, mais peut être fermée par une action.',
  );

  const GameDescriptions(this.text);
  final String text;
}

class Tile {
  Tile(this.coordinate, {required this.category});
  final Coordinate coordinate;
  final TileCategory category;
}

class DoorTile {
  DoorTile(this.coordinate, {required this.isOpened});
  final Coordinate coordinate;
  final bool isOpened;
}

class StartTile {
  StartTile(this.coordinate);
  final Coordinate coordinate;
}

class Item {
  Item(this.coordinate, this.category);
  final Coordinate coordinate;
  final ItemCategory category;
}

/// Renamed from `Map` to avoid collision with dart:core Map
class GameMap {
  GameMap({
    required this.name,
    required this.description,
    required this.imagePreview,
    required this.mode,
    required this.mapSize,
    required this.startTiles,
    required this.items,
    required this.doorTiles,
    required this.tiles,
  });
  final String name;
  final String description;
  final String imagePreview;
  final Mode mode;
  final Coordinate mapSize;
  final List<StartTile> startTiles;
  final List<Item> items;
  final List<DoorTile> doorTiles;
  final List<Tile> tiles;
}

class DetailedMap extends GameMap {
  DetailedMap({
    required super.name,
    required super.description,
    required super.imagePreview,
    required super.mode,
    required super.mapSize,
    required super.startTiles,
    required super.items,
    required super.doorTiles,
    required super.tiles,
    required this.isVisible,
    required this.lastModified,
  });
  final bool isVisible;
  final DateTime lastModified;
}

class CurrentDraggedItem {
  CurrentDraggedItem(this.rowIndex, this.colIndex);
  final int rowIndex;
  final int colIndex;
}
