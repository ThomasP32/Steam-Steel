import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/common/map_types.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/character_creation_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game_locked_dialog.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({
    this.gameId,
    this.mapName,
    this.gameSettings,
    this.isObserver = false,
    super.key,
  });
  final String? gameId;
  final String? mapName;
  final GameSettings? gameSettings;
  final bool isObserver;

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  String name = '';
  Specs _specs = Specs(
    life: DEFAULT_HP,
    speed: DEFAULT_SPEED,
    attack: DEFAULT_ATTACK,
    defense: DEFAULT_DEFENSE,
    defenseBonus: Bonus.d4,
  );
  String? lifeOrSpeedBonus;
  String? attackOrDefenseBonus;
  bool _isSubmitting = false;
  bool _showBonusError = false;
  bool _showDiceError = false;
  StreamSubscription<dynamic>? _gameLockedSub;
  StreamSubscription<dynamic>? _youJoinedSub;
  StreamSubscription<dynamic>? _currentGameSub;
  StreamSubscription<dynamic>? _gameClosedSub;
  GameSettings? _fetchedSettings;

  String _diceAsset(Bonus bonus) => 'lib/assets/icons/d${bonus.value}.png';
  final CharacterCreationService _creationService = CharacterCreationService();

  @override
  void initState() {
    super.initState();

    _creationService.reset();
    _creationService.initializeOwnedAvatars();

    _loadUserName();
    _listenToGameLocked();
    _listenToYouJoined();
    _listenToGameClosed();

    if ((widget.gameSettings == null || widget.gameId?.isNotEmpty == true) &&
        widget.gameId != null &&
        widget.gameId!.isNotEmpty) {
      _listenToCurrentGame();
      _fetchGameData();
    }

    if (widget.gameId != null && widget.gameId!.isNotEmpty) {
      _creationService.startListening(widget.gameId!);
    }
  }

  Future<void> _loadUserName() async {
    final user = AuthService().notifier.value;
    if (user != null && user.username.isNotEmpty) {
      setState(() {
        name = user.username;
      });
    }
  }

  void _listenToGameClosed() {
    _gameClosedSub = SocketService().listen<dynamic>('gameClosed').listen((_) {
      if (!mounted) return;
      FriendService().updateUserStatus(UserStatus.online);
      if (context.mounted) {
        final isHost =
            widget.mapName != null &&
            widget.mapName!.isNotEmpty &&
            (widget.gameId == null || widget.gameId!.isEmpty);
        context.go('/');
        if (!isHost) {
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(
              message: "L'hôte de la partie a quitté.",
            ),
          );
        }
      }
    });
  }

  void _listenToGameLocked() {
    _gameLockedSub = SocketService().listen<dynamic>('gameLocked').listen((
      message,
    ) async {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      // Afficher le modal
      final action = await showGameLockedDialog(context);

      if (!mounted) return;

      if (action == GameLockedAction.goToMenu) {
        // Retourner au menu principal
        if (mounted) context.go('/');
      } else if (action == GameLockedAction.retry) {
        // Réessayer de joindre la partie
        unawaited(_onSubmit());
      }
    });
  }

  void _listenToCurrentGame() {
    _currentGameSub = SocketService()
        .listen<Map<String, dynamic>>('currentGame')
        .listen((gameData) {
          if (!mounted) return;

          try {
            final settingsMap = gameData['settings'] as Map<String, dynamic>?;
            if (settingsMap != null) {
              setState(() {
                _fetchedSettings = GameSettings(
                  isFastElimination:
                      settingsMap['isFastElimination'] as bool? ?? false,
                  isDropInOut: settingsMap['isDropInOut'] as bool? ?? false,
                  isFriendsOnly: settingsMap['isFriendsOnly'] as bool? ?? false,
                );
              });
            }
          } catch (e) {
            DebugLogger.log(
              'Failed to parse game settings: $e',
              tag: 'CharacterCreation',
            );
          }
        });
  }

  void _fetchGameData() {
    SocketService().send('getGameData', widget.gameId);
  }

  void _listenToYouJoined() {
    _youJoinedSub = SocketService()
        .listen<Map<String, dynamic>>('youJoined')
        .listen((data) {
          if (!mounted) return;

          final updatedPlayer = data['updatedPlayer'] as Map<String, dynamic>?;
          final updatedGame = data['updatedGame'] as Map<String, dynamic>?;

          if (updatedPlayer == null || updatedGame == null) {
            DebugLogger.log('youJoined missing data', tag: 'CharacterCreation');
            setState(() => _isSubmitting = false);
            return;
          }

          try {
            PlayerService().setPlayerFromJson(updatedPlayer);
          } catch (e) {
            DebugLogger.log(
              'Failed to set player: $e',
              tag: 'CharacterCreation',
            );
          }

          final effectiveSettings = widget.gameSettings ?? _fetchedSettings;
          final isEliminated = updatedPlayer['isEliminated'] as bool? ?? false;
          final hasStarted = updatedGame['hasStarted'] as bool? ?? false;
          final isDropInDropOut = effectiveSettings?.isDropInOut ?? false;

          if (isEliminated || (hasStarted && isDropInDropOut)) {
            final gameId = updatedGame['id'] as String?;
            final mapData = updatedGame['map'] as Map<String, dynamic>?;
            final mapName = mapData?['name'] as String? ?? widget.mapName ?? '';

            try {
              GoRouter.of(context).go('/game/$gameId/$mapName');
            } catch (e) {
              DebugLogger.log(
                'Navigation to game failed: $e',
                tag: 'CharacterCreation',
              );
            }
          } else {
            DebugLogger.log(
              'Navigating to waiting room',
              tag: 'CharacterCreation',
            );
            try {
              GoRouter.of(context).go(
                '/${widget.gameId}/waiting-room/player',
                extra: effectiveSettings,
              );
            } catch (e) {
              DebugLogger.log(
                'Navigation to waiting room failed: $e',
                tag: 'CharacterCreation',
              );
            }
          }

          if (mounted) {
            setState(() => _isSubmitting = false);
          }
        });
  }

  void _addBonus(String type) {
    setState(() {
      _specs = _creationService.assignBonus(_specs, type);
      lifeOrSpeedBonus = type;
    });
  }

  void _assignDice(String which) {
    setState(() {
      _specs = _creationService.assignDice(_specs, which);
      attackOrDefenseBonus = which;
    });
  }

  void _onButtonPressed() {
    setState(() {
      _showBonusError = false;
      _showDiceError = false;
    });

    if (lifeOrSpeedBonus == null) {
      setState(() {
        _showBonusError = true;
      });
      return;
    }

    // Validate dice
    if (attackOrDefenseBonus == null) {
      setState(() {
        _showDiceError = true;
      });
      return;
    }

    // All valid, proceed
    _onSubmit();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    var finalSpecs = _specs;
    if (lifeOrSpeedBonus != null) {
      finalSpecs = _creationService.assignBonus(finalSpecs, lifeOrSpeedBonus!);
    }
    if (attackOrDefenseBonus != null) {
      finalSpecs = _creationService.assignDice(
        finalSpecs,
        attackOrDefenseBonus!,
      );
    }

    final userLevel = AuthService().notifier.value?.stats.level ?? 1;

    if (widget.mapName != null &&
        widget.mapName!.isNotEmpty &&
        (widget.gameId == null || widget.gameId!.isEmpty)) {
      final player = Player(
        socketId: SocketService().socketId ?? '',
        name: name.isNotEmpty ? name : 'Hôte',
        avatar: Avatar.values[_creationService.selectedAvatar.value - 1],
        level: userLevel,
        specs: finalSpecs,
        inventory: [],
        position: [Coordinate(0, 0)],
        visitedTiles: [],
      );
      try {
        PlayerService().setPlayer(player);
      } catch (_) {}

      try {
        final encoded = Uri.encodeComponent(widget.mapName!);
        GoRouter.of(
          context,
        ).go('/$encoded/waiting-room/host', extra: widget.gameSettings);
      } on Exception catch (e) {
        DebugLogger.log(
          'Navigation to waiting-room host failed: $e',
          tag: 'CharacterCreation',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
      return;
    }

    if (widget.gameId == null || widget.gameId!.isEmpty) {
      setState(() {
        _isSubmitting = false;
      });
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(message: 'Aucun code de partie fourni'),
      );
      return;
    }

    try {
      if (widget.isObserver) {
        await _creationService.observeGame(
          gameId: widget.gameId!,
          name: name.isNotEmpty ? name : 'Observateur',
          socketId: SocketService().socketId ?? '',
          avatar: _creationService.selectedAvatar.value,
          specs: finalSpecs,
          level: userLevel,
          onSuccess: (player) {
            try {
              PlayerService().setPlayer(player);
            } catch (_) {}

            try {
              GoRouter.of(
                context,
              ).go('/game/${widget.gameId}/${widget.mapName}');
            } on Exception catch (e) {
              DebugLogger.log(
                'Navigation to game screen failed: $e',
                tag: 'CharacterCreation',
              );
            } finally {
              if (mounted) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            }
          },
          onTimeout: () {
            if (!mounted) return;
            setState(() {
              _isSubmitting = false;
            });
            showTopSnackBar(
              Overlay.of(context),
              const CustomSnackBar.error(
                message: 'Impossible de rejoindre la partie en observation',
              ),
            );
          },
        );
      } else {
        await _creationService.joinGame(
          gameId: widget.gameId!,
          name: name.isNotEmpty ? name : 'Joueur',
          socketId: SocketService().socketId ?? '',
          avatar: _creationService.selectedAvatar.value,
          specs: finalSpecs,
          level: userLevel,
          onSuccess: (player) {
            try {
              PlayerService().setPlayer(player);
            } catch (_) {}
          },
          onTimeout: () {
            if (!mounted) return;
            setState(() {
              _isSubmitting = false;
            });
            showTopSnackBar(
              Overlay.of(context),
              const CustomSnackBar.error(
                message: 'Impossible de rejoindre la partie',
              ),
            );
          },
        );
      }
    } on Exception catch (e) {
      DebugLogger.log('Join/observe game failed: $e', tag: 'CharacterCreation');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(
          message: "Erreur lors de l'inscription à la partie",
        ),
      );
    }
  }

  @override
  void dispose() {
    _gameLockedSub?.cancel();
    _youJoinedSub?.cancel();
    _currentGameSub?.cancel();
    _gameClosedSub?.cancel();
    _creationService.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FriendService().updateUserStatus(UserStatus.online);
        if (mounted) context.go('/');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: ThemeBackground(pageId: 'charactercreation'),
            ),
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _buildStatsPanel()),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildCenterPanel()),
                      const SizedBox(width: 16),
                      const Expanded(flex: 3, child: SizedBox()),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: TextButton(
                    onPressed: () {
                      FriendService().updateUserStatus(UserStatus.online);
                      if (mounted) context.go('/');
                    },
                    child: const Text('Retour'),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 18,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [FriendButton(), ChatWidget()],
              ),
            ),
            Positioned(
              top: 90,
              right: 12,
              bottom: 16,
              child: _buildAvatarScrollableBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = AppColors.accentHighlight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Vie', _specs.life, accentColor, showBackground: false),
              _statRow(
                'Rapidité',
                _specs.speed,
                accentColor,
                showBackground: false,
              ),
              _statRow(
                'Attaque',
                _specs.attack,
                accentColor,
                showBackground: false,
              ),
              _statRow(
                'Défense',
                _specs.defense,
                accentColor,
                showBackground: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajoutes un bonus:', style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _addBonus('life'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          lifeOrSpeedBonus == 'life' ? accentColor : null,
                      foregroundColor:
                          lifeOrSpeedBonus == 'life' && !isDark
                              ? Colors.white
                              : null,
                      side: BorderSide(color: accentColor, width: 2),
                    ),
                    child: const Text('Vie'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addBonus('speed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          lifeOrSpeedBonus == 'speed' ? accentColor : null,
                      foregroundColor:
                          lifeOrSpeedBonus == 'speed' && !isDark
                              ? Colors.white
                              : null,
                      side: BorderSide(color: accentColor, width: 2),
                    ),
                    child: const Text('Rapidité'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Attribues un dé à 6 faces:',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildDiceColumn('attack', _specs.attackBonus),
                  const SizedBox(width: 8),
                  _buildDiceColumn('defense', _specs.defenseBonus),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiceColumn(String type, Bonus bonus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentHighlight(context);
    final isSelected = attackOrDefenseBonus == type;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => _assignDice(type),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? accentColor : null,
            foregroundColor: isSelected && !isDark ? Colors.white : null,
            side: BorderSide(color: accentColor, width: 2),
          ),
          child: Text(type == 'attack' ? 'Attaque' : 'Défense'),
        ),
        const SizedBox(height: 6),
        Image.asset(
          _diceAsset(bonus),
          width: 48,
          height: 48,
          fit: BoxFit.contain,
          errorBuilder:
              (_, _, _) =>
                  const Text('d4', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildCenterPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = AppColors.accentHighlight(context);

    return ValueListenableBuilder<int>(
      valueListenable: _creationService.selectedAvatar,
      builder: (context, avatar, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black45
                        : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CHOISIS TON AVATAR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 400,
              height: 500,
              child: Center(
                child: Image.asset(
                  'lib/assets/characters/$avatar.png',
                  width: 350,
                  height: 350,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (ctx, err, stack) => Image.asset(
                        'lib/assets/characters/unlocked.png',
                        width: 120,
                        height: 120,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black45
                        : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name.isEmpty ? 'Aucun nom' : name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _onButtonPressed,
              style: ElevatedButton.styleFrom(
                side: BorderSide(color: accentColor, width: 2),
              ),
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        widget.isObserver
                            ? 'Observer'
                            : (widget.gameId?.isEmpty ?? true
                                ? 'Créer une partie'
                                : 'Rejoindre la partie'),
                      ),
            ),
            if (_showBonusError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Ajoutez le bonus (+2 Vie ou Rapidité)',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_showDiceError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Attribuez un dé (D6 Attaque ou Défense)',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarScrollableBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentHighlight(context);

    return Container(
      width: 440,
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor, width: 2),
      ),
      child: ValueListenableBuilder<Set<int>>(
        valueListenable: _creationService.unavailableAvatars,
        builder: (context, unavailable, _) {
          return ValueListenableBuilder<int>(
            valueListenable: _creationService.selectedAvatar,
            builder: (context, selected, _) {
              return ValueListenableBuilder<Set<int>>(
                valueListenable: _creationService.ownedAvatars,
                builder: (context, owned, _) {
                  return GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(8),
                    children: List.generate(_creationService.totalAvatars, (
                      index,
                    ) {
                      final id = index + 1;
                      final isAvailable = !unavailable.contains(id);
                      final isOwned = owned.contains(id);
                      final canSelect = isAvailable && isOwned;

                      return GestureDetector(
                        onTap:
                            canSelect
                                ? () => _creationService.selectAvatar(id)
                                : null,
                        child: Stack(
                          children: [
                            Opacity(
                              opacity: canSelect ? 1.0 : 0.4,
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color:
                                      id == selected
                                          ? accentColor
                                          : Colors.grey[800],
                                  border: Border.all(
                                    color: accentColor,
                                    width: 3,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Image.asset(
                                    'lib/assets/previewcharacters/${id}_preview.png',
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (ctx, err, stack) => Image.asset(
                                          'lib/assets/characters/unlocked.png',
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isOwned)
                              Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    border: Border.all(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.lock,
                                      color: accentColor,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _statRow(
    String label,
    int value,
    Color color, {
    bool showBackground = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final pct = (value / 6).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackground)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black45
                        : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$label : $value',
                style: TextStyle(color: textColor),
              ),
            )
          else
            Text('$label : $value', style: TextStyle(color: textColor)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct,
            color: color,
            backgroundColor: Colors.grey.shade700,
            minHeight: 15,
          ),
        ],
      ),
    );
  }
}
