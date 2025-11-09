import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
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
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    maps.map<Widget>((map) {
                                      final name =
                                          map['name'] as String? ?? 'Unknown';
                                      final desc =
                                          map['description'] as String? ?? '';
                                      final image =
                                          map['imagePreview'] as String?;
                                      final size =
                                          (map['mapSize'] ?? 0)
                                              as Map<String, dynamic>?;
                                      final width =
                                          (size != null && size['x'] != null)
                                              ? (size['x'] as int)
                                              : 0;
                                      final players = getMapPlayers(width);
                                      final isSelected = selectedMap == name;

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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                      BorderRadius.circular(8),
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
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
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
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Mode: ${map['mode'] ?? ''}',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
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
                                                            style:
                                                                const TextStyle(
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
            const Positioned(top: 18, right: 12, child: ChatWidget()),
          ],
        ),
      ),
    );
  }
}
