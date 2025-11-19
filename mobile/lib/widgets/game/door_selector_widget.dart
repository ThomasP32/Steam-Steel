import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';

class DoorSelectorWidget extends StatelessWidget {
  const DoorSelectorWidget({
    required this.doors,
    required this.onDoorSelected,
    required this.onCancel,
    required this.getItemAssetPath,
    super.key,
  });

  final List<DoorTile> doors;
  final void Function(DoorTile door) onDoorSelected;
  final VoidCallback onCancel;
  final String Function(ItemCategory category) getItemAssetPath;

  @override
  Widget build(BuildContext context) {
    final game = GameService().currentGame;
    if (game == null) {
      return const SizedBox.shrink();
    }

    final player = PlayerService().player;
    final playerPos = player.position.isNotEmpty ? player.position.first : null;

    if (playerPos == null) {
      return const SizedBox.shrink();
    }

    final surroundingMap = _buildSurroundingMap(game, playerPos);
    const cellSize = 80.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C3E50) : Colors.white,
              border: Border.all(
                color: isDark ? const Color(0xFFB85C38) : Colors.grey.shade400,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CHOISIS TA PORTE',
                  style: TextStyle(
                    color: AppColors.accentHighlight(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isDark
                              ? const Color(0xFFB85C38)
                              : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        surroundingMap.asMap().entries.map((rowEntry) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                rowEntry.value.asMap().entries.map((cellEntry) {
                                  final cell = cellEntry.value;
                                  final coord =
                                      cell['coordinates'] as Coordinate;
                                  final isDoorCell = _isDoor(coord);

                                  return GestureDetector(
                                    onTap:
                                        isDoorCell
                                            ? () {
                                              final door = doors.firstWhere(
                                                (d) =>
                                                    d.coordinate.x == coord.x &&
                                                    d.coordinate.y == coord.y,
                                              );
                                              onDoorSelected(door);
                                            }
                                            : null,
                                    child: Container(
                                      width: cellSize,
                                      height: cellSize,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          if (!isDoorCell)
                                            const ColoredBox(
                                              color: Colors.black54,
                                              child: SizedBox.expand(),
                                            ),
                                          if (cell['tileAsset'] != null)
                                            Image.asset(
                                              cell['tileAsset'] as String,
                                              width: cellSize,
                                              height: cellSize,
                                              fit: BoxFit.cover,
                                            ),
                                          if (cell['isStartingPoint'] == true)
                                            Center(
                                              child: Image.asset(
                                                'lib/assets/tiles/startingpoint.png',
                                                width: cellSize,
                                                height: cellSize,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          if (cell['itemCategory'] != null)
                                            Center(
                                              child: Image.asset(
                                                getItemAssetPath(
                                                  cell['itemCategory']
                                                      as ItemCategory,
                                                ),
                                                width: cellSize * 0.7,
                                                height: cellSize * 0.7,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          if (cell['playerAvatar'] != null)
                                            Center(
                                              child: Image.asset(
                                                'lib/assets/pixelcharacters/${cell['playerAvatar']}_pixelated.png',
                                                width: cellSize,
                                                height: cellSize,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              onPressed: onCancel,
              icon: Icon(
                Icons.close,
                color: AppColors.accentHighlight(context),
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  List<List<Map<String, dynamic>>> _buildSurroundingMap(
    GameClassic game,
    Coordinate playerPos,
  ) {
    const radius = 1;
    final surroundingMap = <List<Map<String, dynamic>>>[];

    for (var row = playerPos.x - radius; row <= playerPos.x + radius; row++) {
      final rowCells = <Map<String, dynamic>>[];
      for (var col = playerPos.y - radius; col <= playerPos.y + radius; col++) {
        final coord = Coordinate(row, col);
        final cellData = _getCellData(game, coord);
        rowCells.add(cellData);
      }
      surroundingMap.add(rowCells);
    }

    return surroundingMap;
  }

  Map<String, dynamic> _getCellData(GameClassic game, Coordinate coord) {
    final tile = game.tiles.cast<Tile?>().firstWhere(
      (t) => t?.coordinate.x == coord.x && t?.coordinate.y == coord.y,
      orElse: () => null,
    );

    final door = game.doorTiles.cast<DoorTile?>().firstWhere(
      (d) => d?.coordinate.x == coord.x && d?.coordinate.y == coord.y,
      orElse: () => null,
    );

    final item = game.items.cast<Item?>().firstWhere(
      (i) => i?.coordinate.x == coord.x && i?.coordinate.y == coord.y,
      orElse: () => null,
    );

    final startPoint = game.startTiles.cast<Coordinate?>().firstWhere(
      (s) => s?.x == coord.x && s?.y == coord.y,
      orElse: () => null,
    );

    final player = game.players.cast<Player?>().firstWhere((p) {
      if (p?.position == null || p!.position.isEmpty) return false;
      final pos = p.position.first;
      return pos.x == coord.x && pos.y == coord.y;
    }, orElse: () => null);

    String? tileAsset;
    if (door != null) {
      tileAsset =
          door.isOpened
              ? 'lib/assets/tiles/door_opened.jpg'
              : 'lib/assets/tiles/door_closed.jpg';
    } else if (tile != null) {
      switch (tile.category) {
        case TileCategory.water:
          tileAsset = 'lib/assets/tiles/water.png';
        case TileCategory.ice:
          tileAsset = 'lib/assets/tiles/ice1.jpg';
        case TileCategory.wall:
          tileAsset = 'lib/assets/tiles/wall.png';
        case TileCategory.floor:
        case TileCategory.door:
          tileAsset = 'lib/assets/tiles/floor.png';
      }
    } else {
      tileAsset = 'lib/assets/tiles/floor.png';
    }

    return {
      'coordinates': coord,
      'tileAsset': tileAsset,
      'isStartingPoint': startPoint != null,
      'itemCategory': item?.category,
      'playerAvatar': player?.avatar.value,
    };
  }

  bool _isDoor(Coordinate coord) {
    return doors.any(
      (d) => d.coordinate.x == coord.x && d.coordinate.y == coord.y,
    );
  }
}
