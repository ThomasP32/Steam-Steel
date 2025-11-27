import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/models/shop_item.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/shop_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class ShopWidget extends StatefulWidget {
  const ShopWidget({super.key});

  @override
  State<ShopWidget> createState() => _ShopWidgetState();
}

class _ShopWidgetState extends State<ShopWidget> {
  final ShopService _shopService = ShopService();
  final AuthService _authService = AuthService();

  List<ShopItem> _allItems = [];
  int _currentMoney = 0;
  String _selectedCategory = 'characters';
  bool _isLoading = true;
  StreamSubscription<int>? _moneySub;
  VoidCallback? _userListener;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'characters', 'name': 'Personnages', 'icon': '👤'},

    {'id': 'profilePicture', 'name': 'Photo de profil', 'icon': '📸'},
    {'id': 'banner', 'name': 'Bannières', 'icon': '🏳️'},
    {'id': 'sound', 'name': 'Musique', 'icon': '🔊'},
  ];

  @override
  void initState() {
    super.initState();
    _loadShopData();
    _listenToMoneyUpdates();
    _listenToUserUpdates();
  }

  @override
  void dispose() {
    _moneySub?.cancel();
    if (_userListener != null) {
      _authService.notifier.removeListener(_userListener!);
    }
    super.dispose();
  }

  void _listenToUserUpdates() {
    _userListener = () {
      DebugLogger.log(
        'Shop: Listener triggered, mounted=$mounted',
        tag: 'ShopWidget',
      );

      final user = _authService.notifier.value;
      if (user == null) {
        DebugLogger.log('Shop: User is null', tag: 'ShopWidget');
        return;
      }
      if (!mounted) {
        DebugLogger.log('Shop: Widget not mounted', tag: 'ShopWidget');
        return;
      }

      DebugLogger.log(
        'Shop: User data changed, current avatar: ${user.avatar}',
        tag: 'ShopWidget',
      );

      final currentAvatarId = int.tryParse(user.avatar);

      for (final item in _allItems) {
        if (item.category == 'characters') {
          final shopAvatarMatch = RegExp(r'avatar_(\d+)').firstMatch(item.id);
          if (shopAvatarMatch != null) {
            final shopAvatarNum = int.parse(shopAvatarMatch.group(1)!);
            final characterId = shopAvatarNum + 12;

            final wasEquipped = item.equipped;
            item.equipped = (characterId == currentAvatarId);

            if (wasEquipped != item.equipped) {
              DebugLogger.log(
                'Shop: ${item.id} equipped state changed: $wasEquipped -> ${item.equipped}',
                tag: 'ShopWidget',
              );
            }
          }
        }
      }

      if (_currentMoney != user.virtualMoney) {
        setState(() {
          _currentMoney = user.virtualMoney;
        });
      } else {
        if (mounted) {
          setState(() {});
        }
      }
    };
    _authService.notifier.addListener(_userListener!);
    DebugLogger.log('Shop: User listener added', tag: 'ShopWidget');
  }

  void _listenToMoneyUpdates() {
    _moneySub = _shopService.moneyUpdates.listen((money) {
      if (mounted) {
        setState(() => _currentMoney = money);
      }
    });
  }

  Future<void> _loadShopData() async {
    try {
      final user = _authService.notifier.value;
      if (user == null) {
        DebugLogger.log('User not logged in', tag: 'ShopWidget');
        return;
      }

      _currentMoney = user.virtualMoney;

      final items = await _shopService.getCatalogWithUserStatus(user.id);

      final currentAvatarId = int.tryParse(user.avatar);
      DebugLogger.log(
        'Shop: Loading data, current avatar: ${user.avatar}',
        tag: 'ShopWidget',
      );

      for (final item in items) {
        if (item.category == 'characters') {
          final shopAvatarMatch = RegExp(r'avatar_(\d+)').firstMatch(item.id);
          if (shopAvatarMatch != null) {
            final shopAvatarNum = int.parse(shopAvatarMatch.group(1)!);
            final characterId = shopAvatarNum + 12;

            final correctEquippedState = (characterId == currentAvatarId);
            if (item.equipped != correctEquippedState) {
              DebugLogger.log(
                'Shop: Correcting ${item.id} equipped: ${item.equipped} -> $correctEquippedState',
                tag: 'ShopWidget',
              );
              item.equipped = correctEquippedState;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      DebugLogger.log('Error loading shop data: $e', tag: 'ShopWidget');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCategoryInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String message;

    switch (_selectedCategory) {
      case 'characters':
        title = '🎭 Personnages';
        message =
            'Personnalise ton identité ! Une fois acheté, ce personnage sera disponible comme personnage jouable en partie.';
      case 'profilePicture':
        title = '📸 Photos de profil';
        message =
            "Ces photos de profil uniques apparaîtront partout où ton identité est visible : dans les chats, la liste d'amis, et le compte. Montre qui tu es vraiment ! Si équipé, il deviendra automatiquement ta photo de profil.";
      case 'banner':
        title = '✨ Bannières';
        message =
            "Affiche ton style ! Cette bannière décorative encadrera élégamment tes infos dans la salle d'attente, fin de partie et dans la liste d'amis. Tous les autres joueurs pourront admirer ton choix esthétique !";
      case 'sound':
        title = '🔊 Musique';
        message =
            'Personnalise ton expérience sonore avec nos morceaux exclusifs ! Une fois achetée, la musique sera disponible pour être équipée dans les paramètres de compte. Aussi, les créateurs de parties pourront choisir la musique de fond pour leurs parties!';
      default:
        title = 'Information';
        message = 'Catégorie inconnue';
    }

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF2C3E50) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: AppColors.accentHighlight(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(color: AppColors.accentHighlight(context)),
                ),
              ),
            ],
          ),
    );
  }

  List<ShopItem> get _currentCategoryItems {
    return _allItems
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  bool _canAfford(ShopItem item) {
    final hasEnoughMoney = _currentMoney >= item.price && !item.owned;
    final hasRequiredLevel = item.levelRequired == null || item.canPurchase;
    final hasRequiredChallenges =
        item.challengeRequired == null || item.canPurchase;
    return hasEnoughMoney && hasRequiredLevel && hasRequiredChallenges;
  }

  Future<void> _buyItem(ShopItem item) async {
    if (!_canAfford(item)) return;

    try {
      final user = _authService.notifier.value;
      if (user == null) return;

      final result = await _shopService.purchaseItem(user.id, item.id);

      if (result['success'] == true) {
        await _authService.fetchUser();

        if (mounted) {
          setState(() {
            item.owned = true;
            if (result['newBalance'] != null) {
              _currentMoney = result['newBalance'] as int;
            }
          });
        }

        // Refresh user data to update shopItems
        await _authService.fetchUser();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']?.toString() ?? "Erreur d'achat"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on Exception catch (e) {
      DebugLogger.log('Error buying item: $e', tag: 'ShopWidget');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de l'achat"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _equipItem(ShopItem item) async {
    if (!item.owned) return;

    if (item.category == 'characters') {
      return;
    }

    try {
      final user = _authService.notifier.value;
      if (user == null) return;

      final result = await _shopService.equipItem(user.id, item.id);

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            for (final i in _allItems) {
              if (i.category == item.category && i.id != item.id) {
                i.equipped = false;
              }
            }
            item.equipped = true;
          });
        }
      }
    } on Exception catch (e) {
      DebugLogger.log('Error equipping item: $e', tag: 'ShopWidget');
    }
  }

  Future<void> _unequipItem(ShopItem item) async {
    if (!item.equipped) return;
    // Les characters ne peuvent pas être déséquipés depuis la boutique
    if (item.category == 'characters') return;

    try {
      final user = _authService.notifier.value;
      if (user == null) return;

      final result = await _shopService.unequipItem(user.id, item.id);

      if (result['success'] == true) {
        if (item.category == 'profilePicture') {
          DebugLogger.log(
            'Refreshing user data after profile picture unequip',
            tag: 'ShopWidget',
          );
          await _authService.fetchUser();
          DebugLogger.log('User data refreshed', tag: 'ShopWidget');
        }

        if (mounted) {
          setState(() {
            item.equipped = false;
          });
        }
      }
    } on Exception catch (e) {
      DebugLogger.log('Error unequipping item: $e', tag: 'ShopWidget');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 900),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C3E50) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentHighlight(context),
            width: 3,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildCategorySidebar(),
                  Expanded(child: _buildItemsArea()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF34495E) : Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Boutique',
            style: TextStyle(
              color: AppColors.accentHighlight(context),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentHighlight(context),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  'lib/assets/icons/money.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_currentMoney',
                  style: const TextStyle(
                    color: Color(0xFF7D4F00),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF34495E) : Colors.grey.shade200,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Catégories',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._categories.map((category) {
            final isSelected = _selectedCategory == category['id'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Material(
                color:
                    isSelected
                        ? AppColors.accentHighlight(context)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    setState(
                      () => _selectedCategory = category['id'] as String,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          category['icon'] as String,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black54),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentHighlight(context),
        ),
      );
    }

    final items = _currentCategoryItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📦', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Aucun article disponible',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette catégorie sera bientôt remplie !',
              style: TextStyle(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _categories.firstWhere(
                      (c) => c['id'] == _selectedCategory,
                    )['name']
                    as String,
                style: TextStyle(
                  color: AppColors.accentHighlight(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => _showCategoryInfo(context),
                  child: Icon(
                    Icons.info_outline,
                    color: AppColors.accentHighlight(context),
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} article${items.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildItemCard(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked =
        (item.levelRequired != null && !item.canPurchase) ||
        (item.challengeRequired != null && !item.canPurchase);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF34495E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              item.equipped
                  ? const Color(0xFF27AE60)
                  : item.owned
                  ? const Color(0xFF3498DB)
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2C3E50) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Padding(
                        padding:
                            item.category == 'banner' ||
                                    item.category == 'profilePicture'
                                ? const EdgeInsets.all(12)
                                : EdgeInsets.zero,
                        child: _buildItemImage(item),
                      ),
                    ),
                  ),
                ),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: Colors.white, size: 48),
                      ),
                    ),
                  ),
                if (item.equipped)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Équipé',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (item.owned && !item.equipped)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Possédé',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (!item.owned)
                  Row(
                    children: [
                      Image.asset(
                        'lib/assets/icons/money.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price}',
                        style: TextStyle(
                          color: AppColors.accentHighlight(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                if (!item.owned ||
                    (item.category != 'characters' && item.category != 'sound'))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLocked) return;
                        if (item.owned && item.category == 'characters') {
                          return;
                        }

                        if (!item.owned && _canAfford(item)) {
                          _buyItem(item);
                        } else if (item.owned &&
                            !item.equipped &&
                            item.category != 'characters') {
                          _equipItem(item);
                        } else if (item.equipped &&
                            item.category != 'characters') {
                          _unequipItem(item);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLocked
                                ? Colors.grey
                                : !item.owned
                                ? (_canAfford(item)
                                    ? const Color(0xFF27AE60)
                                    : Colors.grey)
                                : (item.equipped
                                    ? AppColors.accentHighlight(context)
                                    : const Color(0xFF3498DB)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          isLocked
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.levelRequired != null &&
                                            !item.canPurchase
                                        ? 'Niveau ${item.levelRequired} requis'
                                        : '${item.challengeRequired} Défis requis',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                !item.owned
                                    ? (_canAfford(item)
                                        ? 'Acheter'
                                        : 'Fonds insuffisants')
                                    : (item.equipped
                                        ? 'Déséquiper'
                                        : 'Équiper'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(ShopItem item) {
    final imagePath = item.imagePath;
    final isBanner = item.category == 'banner';
    final isProfilePicture = item.category == 'profilePicture';
    final boxFit =
        (isBanner || isProfilePicture) ? BoxFit.contain : BoxFit.cover;
    final alignment =
        (isBanner || isProfilePicture) ? Alignment.center : Alignment.topCenter;

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: boxFit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) {
          DebugLogger.log(
            'Failed to load network image: $imagePath',
            tag: 'ShopWidget',
          );
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          );
        },
      );
    }

    var assetPath = imagePath;
    if (imagePath.startsWith('assets/')) {
      assetPath = 'lib/$imagePath';
    } else if (!imagePath.startsWith('lib/')) {
      assetPath = 'lib/assets/shop/$imagePath';
    }

    return Image.asset(
      assetPath,
      fit: boxFit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        DebugLogger.log(
          'Failed to load asset: $assetPath, error: $error',
          tag: 'ShopWidget',
        );
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        );
      },
    );
  }
}
