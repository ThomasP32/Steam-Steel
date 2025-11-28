import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/audio_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game/game_options_modal_widget.dart';
import 'package:mobile/widgets/money_widget.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';

class GameCreationScreen extends StatefulWidget {
  const GameCreationScreen({super.key});

  @override
  State<GameCreationScreen> createState() => _GameCreationScreenState();
}

class _GameCreationScreenState extends State<GameCreationScreen> {
  final ApiClient _api = ApiClient();

  List<dynamic> maps = [];
  String? selectedMap;
  bool loading = true;
  bool userError = false;
  bool gameChoiceError = false;
  bool showGameOptionsModal = false;
  Map<String, bool> gameSettings = {
    'isFastElimination': false,
    'isDropInOut': false,
    'isFriendsOnly': false,
  };

  // Filtres et tri
  String? sortBy; // 'name', 'players', 'mode', ou null (pas de filtre)
  String sortOrder = 'asc'; // 'asc', 'desc'

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadMaps() async {
    setState(() {
      loading = true;
      userError = false;
      gameChoiceError = false;
    });
    try {
      final result = await _api.getMaps();
      setState(() {
        maps = result;
      });
    } on Exception catch (e) {
      DebugLogger.log('Failed to load maps: $e', tag: 'GameCreationScreen');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void selectMap(String name) {
    setState(() {
      selectedMap = name;
      userError = false;
      gameChoiceError = false;
      showGameOptionsModal = true;
    });
  }

  void closeGameOptionsModal() {
    setState(() {
      showGameOptionsModal = false;
      selectedMap = null;
    });
  }

  void onGameOptionsNext({
    required bool isFastElimination,
    required bool isDropInOut,
    required bool isFriendsOnly,
    required int entryFee,
  }) {
    final settings = GameSettings(
      isFastElimination: isFastElimination,
      isDropInOut: isDropInOut,
      isFriendsOnly: isFriendsOnly,
      entryFee: entryFee,
    );

    setState(() {
      showGameOptionsModal = false;
    });

    if (selectedMap != null && mounted) {
      final encoded = Uri.encodeComponent(selectedMap!);
      AudioService().stopMusic();
      context.go('/create-game/$encoded/choose-character', extra: settings);
    }
  }

  int getMapPlayers(int width) {
    if (width <= 10) return 2;
    if (width <= 15) return 4;
    return 6;
  }

  void toggleSort(String newSortBy) {
    setState(() {
      if (sortBy == newSortBy) {
        // Si on clique sur le même filtre actif, on le désactive complètement
        sortBy = null;
        sortOrder = 'asc';
      } else {
        // Nouveau filtre, ordre ascendant par défaut
        sortBy = newSortBy;
        sortOrder = 'asc';
      }
    });
  }

  void toggleOrder() {
    // Ne rien faire si aucun filtre n'est actif
    if (sortBy == null) return;

    setState(() {
      sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    });
  }

  List<dynamic> get sortedMaps {
    // Si aucun filtre n'est actif, retourner la liste originale
    if (sortBy == null) {
      return maps;
    }

    final sorted = List<dynamic>.from(maps)..sort((a, b) {
      var comparison = 0;

      switch (sortBy) {
        case 'name':
          final nameA = (a['name'] as String? ?? '').toLowerCase();
          final nameB = (b['name'] as String? ?? '').toLowerCase();
          comparison = nameA.compareTo(nameB);
        case 'players':
          final sizeA = a['mapSize'] as Map<String, dynamic>?;
          final sizeB = b['mapSize'] as Map<String, dynamic>?;
          final playersA = getMapPlayers((sizeA?['x'] as int?) ?? 0);
          final playersB = getMapPlayers((sizeB?['x'] as int?) ?? 0);
          comparison = playersA.compareTo(playersB);
        case 'mode':
          final modeA = (a['mode'] as String? ?? '').toLowerCase();
          final modeB = (b['mode'] as String? ?? '').toLowerCase();
          comparison = modeA.compareTo(modeB);
      }

      return sortOrder == 'asc' ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildImage(String? imagePreview) {
    if (imagePreview == null || imagePreview.isEmpty) {
      return Container(color: Colors.grey[300]);
    }
    try {
      if (imagePreview.startsWith('data:image')) {
        final parts = imagePreview.split(',');
        final base64Str = parts.length > 1 ? parts[1] : parts[0];
        final bytes = base64Decode(base64Str);
        return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
      }
      final maybeBytes = base64Decode(imagePreview);
      return Image.memory(Uint8List.fromList(maybeBytes), fit: BoxFit.cover);
    } on Exception catch (e) {
      DebugLogger.log('Failed to decode image: $e', tag: 'GameCreationScreen');
      return Image.network(
        imagePreview,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(color: Colors.grey[300]);
        },
      );
    }
  }

  Widget _buildFilterButton(String label, String value) {
    final isActive = sortBy == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87);

    return ElevatedButton(
      onPressed: () => toggleSort(value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isActive
                ? AppColors.accentHighlight(context)
                : Colors.grey.withValues(alpha: 0.5),
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return WillPopScope(
      onWillPop: () async {
        // If keyboard is open, close it first
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          return false;
        }

        // If modal is showing, close it
        if (showGameOptionsModal) {
          closeGameOptionsModal();
          return false;
        }

        // Otherwise navigate to home
        if (mounted) {
          context.go('/');
        }
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: ThemeBackground(pageId: 'gamecreation'),
            ),
            Stack(
              children: [
                Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: SizedBox(
                          height: kToolbarHeight,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => context.go('/'),
                                  child: const Text('Retour'),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'CHOISIS TON JEU',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          loading
                              ? const Center(child: CircularProgressIndicator())
                              : RefreshIndicator(
                                onRefresh: _loadMaps,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Section Filtrer par
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Filtrer par :',
                                              style: TextStyle(
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildFilterButton('Nom', 'name'),
                                            const SizedBox(width: 8),
                                            _buildFilterButton(
                                              'Nombre de joueurs',
                                              'players',
                                            ),
                                            const SizedBox(width: 8),
                                            _buildFilterButton('Mode', 'mode'),
                                            const SizedBox(width: 8),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color:
                                                    sortBy != null
                                                        ? AppColors.accentHighlight(
                                                          context,
                                                        ).withValues(alpha: 0.8)
                                                        : Colors.grey
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                onPressed:
                                                    sortBy != null
                                                        ? toggleOrder
                                                        : null,
                                                icon: Image.asset(
                                                  sortOrder == 'asc'
                                                      ? 'lib/assets/icons/sort-asc.png'
                                                      : 'lib/assets/icons/sort-desc.png',
                                                  width: 18,
                                                  height: 18,
                                                  color:
                                                      sortBy != null
                                                          ? Colors.white
                                                          : (isDark
                                                              ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  )
                                                              : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  )),
                                                ),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 36,
                                                      minHeight: 36,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Liste des cartes
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children:
                                            sortedMaps.map<Widget>((map) {
                                              final name =
                                                  map['name'] as String? ??
                                                  'Unknown';
                                              final desc =
                                                  map['description']
                                                      as String? ??
                                                  '';
                                              final image =
                                                  map['imagePreview']
                                                      as String?;
                                              final size =
                                                  (map['mapSize'] ?? 0)
                                                      as Map<String, dynamic>?;
                                              final width =
                                                  (size != null &&
                                                          size['x'] != null)
                                                      ? (size['x'] as int)
                                                      : 0;
                                              final players = getMapPlayers(
                                                width,
                                              );
                                              final isSelected =
                                                  selectedMap == name;

                                              final cardTextColor =
                                                  isDark
                                                      ? AppColors.textDark
                                                      : AppColors.textLight;
                                              final cardTextSecondary =
                                                  isDark
                                                      ? AppColors.textDark
                                                          .withValues(
                                                            alpha: 0.7,
                                                          )
                                                      : AppColors.textLight
                                                          .withValues(
                                                            alpha: 0.54,
                                                          );

                                              return GestureDetector(
                                                onTap: () => selectMap(name),
                                                child: Container(
                                                  width:
                                                      (() {
                                                        final screenW =
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width;
                                                        return screenW > 800
                                                            ? 240.0
                                                            : screenW / 2 -
                                                                24.0;
                                                      })(),
                                                  height:
                                                      (() {
                                                        final screenW =
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width;
                                                        return screenW > 800
                                                            ? 240.0
                                                            : screenW / 2 -
                                                                24.0;
                                                      })(),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          isSelected
                                                              ? AppColors.accentHighlight(
                                                                context,
                                                              )
                                                              : Colors
                                                                  .transparent,
                                                      width: 3,
                                                    ),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                    color: Colors.white,
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child: _buildImage(
                                                            image,
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 8,
                                                        top: 8,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                isDark
                                                                    ? Colors
                                                                        .black45
                                                                    : Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.75,
                                                                        ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            players == 2
                                                                ? '$players joueurs'
                                                                : '2 à $players joueurs',
                                                            style: TextStyle(
                                                              color:
                                                                  cardTextColor,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 0,
                                                        left: 0,
                                                        right: 0,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isDark
                                                                          ? Colors
                                                                              .black45
                                                                          : Colors.white.withValues(
                                                                            alpha:
                                                                                0.75,
                                                                          ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  name,
                                                                  style: TextStyle(
                                                                    color:
                                                                        cardTextColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isDark
                                                                          ? Colors
                                                                              .black45
                                                                          : Colors.white.withValues(
                                                                            alpha:
                                                                                0.75,
                                                                          ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  'Taille: ${width}x${size?['y'] ?? width}',
                                                                  style: TextStyle(
                                                                    color:
                                                                        cardTextSecondary,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isDark
                                                                          ? Colors
                                                                              .black45
                                                                          : Colors.white.withValues(
                                                                            alpha:
                                                                                0.75,
                                                                          ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  'Mode: ${map['mode'] ?? ''}',
                                                                  style: TextStyle(
                                                                    color:
                                                                        cardTextSecondary,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (desc
                                                                  .isNotEmpty)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        top: 4,
                                                                      ),
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color:
                                                                          isDark
                                                                              ? Colors.black45
                                                                              : Colors.white.withValues(
                                                                                alpha:
                                                                                    0.75,
                                                                              ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            4,
                                                                          ),
                                                                    ),
                                                                    child: Text(
                                                                      desc,
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style: TextStyle(
                                                                        color:
                                                                            cardTextColor,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          if (userError)
                            const Text(
                              'Aucun jeu selectionné. Sélectionnez un jeu.',
                              style: TextStyle(color: Colors.red),
                            ),
                          if (gameChoiceError)
                            const Text(
                              "Le jeu n'est plus disponible.",
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showGameOptionsModal && selectedMap != null)
                  GameOptionsModalWidget(
                    selectedMapName: selectedMap!,
                    onClose: closeGameOptionsModal,
                    onNext: onGameOptionsNext,
                  ),
                const Positioned(
                  top: 18,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: MoneyWidget(),
                      ),
                      SizedBox(width: 8),
                      FriendButton(),
                      ChatWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
