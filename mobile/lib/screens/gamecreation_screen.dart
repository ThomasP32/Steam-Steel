import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game/game_options_modal_widget.dart';

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
    required bool isFriendsOnly,
  }) {
    final settings = GameSettings(
      isFastElimination: isFastElimination,
      isFriendsOnly: isFriendsOnly,
    );

    setState(() {
      showGameOptionsModal = false;
    });

    if (selectedMap != null && mounted) {
      final encoded = Uri.encodeComponent(selectedMap!);
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

    final sorted = List<dynamic>.from(maps);

    sorted.sort((a, b) {
      int comparison = 0;

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
    return ElevatedButton(
      onPressed: () => toggleSort(value),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isActive ? Colors.orange : Colors.grey.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/backgrounds/backgroundcombat.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
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
                          const Center(
                            child: Text(
                              'CHOISIS TON JEU',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Filtrer par :',
                                          style: TextStyle(
                                            color: Colors.white,
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
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                sortBy != null
                                                    ? Colors.orange.withValues(
                                                      alpha: 0.8,
                                                    )
                                                    : Colors.grey.withValues(
                                                      alpha: 0.3,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                      : Colors.white.withValues(
                                                        alpha: 0.3,
                                                      ),
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(
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
                                              map['description'] as String? ??
                                              '';
                                          final image =
                                              map['imagePreview'] as String?;
                                          final size =
                                              (map['mapSize'] ?? 0)
                                                  as Map<String, dynamic>?;
                                          final width =
                                              (size != null &&
                                                      size['x'] != null)
                                                  ? (size['x'] as int)
                                                  : 0;
                                          final players = getMapPlayers(width);
                                          final isSelected =
                                              selectedMap == name;

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
                                                        : screenW / 2 - 24.0;
                                                  })(),
                                              height:
                                                  (() {
                                                    final screenW =
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width;
                                                    return screenW > 800
                                                        ? 240.0
                                                        : screenW / 2 - 24.0;
                                                  })(),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      isSelected
                                                          ? Colors.orange
                                                          : Colors.transparent,
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
                                                      child: _buildImage(image),
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
                                                        color: Colors.black45,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        players == 2
                                                            ? '$players joueurs'
                                                            : '2 à $players joueurs',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: const BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.black54,
                                                            Colors.transparent,
                                                          ],
                                                          begin:
                                                              Alignment
                                                                  .bottomCenter,
                                                          end:
                                                              Alignment
                                                                  .topCenter,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            name,
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                          const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                  top: 4,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Taille: ${width}x${size?['y'] ?? width}',
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .white70,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            'Mode: ${map['mode'] ?? ''}',
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .white70,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          if (desc.isNotEmpty)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 4,
                                                                  ),
                                                              child: Text(
                                                                desc,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  fontSize: 12,
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
                mainAxisSize: MainAxisSize.min,
                children: [FriendButton(), ChatWidget()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
