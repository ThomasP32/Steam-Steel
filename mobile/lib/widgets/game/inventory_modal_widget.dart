import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/services/socket_service.dart';

class InventoryModalWidget extends StatelessWidget {
  const InventoryModalWidget({
    required this.player,
    required this.gameId,
    required this.getItemAssetPath,
    super.key,
  });

  final Player player;
  final String gameId;
  final String Function(ItemCategory) getItemAssetPath;

  void _dropItem(BuildContext context, ItemCategory item) {
    final payload = <String, dynamic>{
      'itemDropping': _getItemCategoryString(item),
      'gameId': gameId,
    };
    SocketService().send('dropItem', payload);
    Navigator.of(context).pop();
  }

  String _getItemCategoryString(ItemCategory item) {
    switch (item) {
      case ItemCategory.sword:
        return 'sword';
      case ItemCategory.armor:
        return 'armor';
      case ItemCategory.flask:
        return 'flask';
      case ItemCategory.wallBreaker:
        return 'wallbreaker';
      case ItemCategory.iceSkates:
        return 'iceskates';
      case ItemCategory.amulet:
        return 'amulet';
      case ItemCategory.flag:
        return 'flag';
      case ItemCategory.random:
        return 'random';
      case ItemCategory.startingPoint:
        return 'startingPoint';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2C3E50) : Colors.white,
      title: Column(
        children: [
          Text(
            'Votre inventaire est plein',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Choisissez un item à jeter',
            style: TextStyle(
              color: AppColors.accentHighlight(context),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children:
              player.inventory
                  .map((item) => _buildInventorySlot(context, item))
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildInventorySlot(BuildContext context, ItemCategory item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _dropItem(context, item),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A252F) : Colors.grey.shade200,
          border: Border.all(color: AppColors.accentHighlight(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(getItemAssetPath(item), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
