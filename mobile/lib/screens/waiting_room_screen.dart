import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/game.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/audio_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/game_service.dart';
import 'package:mobile/services/player_service.dart';
import 'package:mobile/services/shop_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/services/waiting_room_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/chat_widget.dart';
import 'package:mobile/widgets/friends/friend_button.dart';
import 'package:mobile/widgets/game/challenges_widget.dart';
import 'package:mobile/widgets/money_widget.dart';
import 'package:mobile/widgets/theme/theme_widget.dart';
import 'package:mobile/widgets/waiting_room/profile_modal_widget.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    this.gameId,
    this.mapName,
    this.gameSettings,
    super.key,
  });

  final String? gameId;
  final String? mapName;
  final GameSettings? gameSettings;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  final _service = WaitingRoomService();
  final _gameService = GameService();
  final _playerService = PlayerService();
  final _authService = AuthService();
  final _shopService = ShopService();
  late AnimationController _gearController;

  StreamSubscription<dynamic>? _closedSub;
  StreamSubscription<dynamic>? _gameInitializedSub;
  StreamSubscription<dynamic>? _playerKickedSub;
  StreamSubscription<int>? _moneyUpdatesSub;

  VoidCallback? _playerListener;
  String _playerName = '';
  final Map<String, String> _playerBanners = {};

  @override
  void initState() {
    super.initState();
    FriendService().updateUserStatus(UserStatus.inGame);

    final local = _playerService.notifier.value;
    if (local.name.isNotEmpty) {
      _playerName = local.name;
    }

    _playerListener = () {
      final p = _playerService.notifier.value;
      if (mounted && p.name.isNotEmpty && p.name != _playerName) {
        setState(() => _playerName = p.name);
      }
    };
    _playerService.notifier.addListener(_playerListener!);

    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _service.initialize(widget.gameId, widget.mapName, widget.gameSettings);

    _listenToGameClosed();
    _listenToGameInitialized();
    _listenToPlayerKicked();
    _listenToMoneyUpdates();
    _listenToAudioSettings();
    _loadPlayerBanners();

    _service.players.addListener(_loadPlayerBanners);
  }

  void _listenToGameClosed() {
    _closedSub = SocketService().listen<dynamic>('gameClosed').listen((_) {
      if (!mounted) return;
      FriendService().updateUserStatus(UserStatus.online);
      if (context.mounted) {
        final isHost = _service.isHost.value;
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

  void _listenToGameInitialized() {
    _gameInitializedSub = SocketService()
        .listen<dynamic>('gameInitialized')
        .listen((data) async {
          if (!mounted) return;

          if (data is Map<String, dynamic>) {
            _gameService.updateFromJson(data);

            final players = data['players'] as List<dynamic>?;
            if (players != null && players.isNotEmpty) {
              final currentSocketId = SocketService().socketId;
              final myPlayerData =
                  players.firstWhere(
                        (p) =>
                            (p as Map<String, dynamic>)['socketId'] ==
                            currentSocketId,
                        orElse: () => null,
                      )
                      as Map<String, dynamic>?;
              if (myPlayerData != null) {
                _playerService.setPlayerFromJson(myPlayerData);
              }
            }
          }

          if (!mounted) return;

          if (_service.isHost.value) {
            SocketService().send('startGame', _service.gameId.value);
          }

          if (!mounted) return;

          final gameId = _service.gameId.value;
          final rawMapName = _service.mapName.value;
          final encodedMapName = Uri.encodeComponent(rawMapName);

          if (context.mounted) {
            context.go('/game/$gameId/$encodedMapName');
          }
        });
  }

  void _listenToPlayerKicked() {
    _playerKickedSub = SocketService().listen<dynamic>('playerKicked').listen((
      _,
    ) async {
      if (!mounted) return;
      FriendService().updateUserStatus(UserStatus.online);
      try {
        if (widget.gameId != null) {
          await ChannelService().removeGameChannel(widget.gameId!);
        }
        SocketService().disconnect();
        await SocketService().connect();
        if (!mounted) return;
        if (context.mounted) {
          await AudioService().stopMusic();
          context.go('/');
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(
              message: 'Vous avez été expulsé de la partie',
            ),
          );
        }
      } on Exception catch (e) {
        DebugLogger.log(
          'Error handling player kicked: $e',
          tag: 'WaitingRoomScreen',
        );
      }
    });
  }

  void _listenToMoneyUpdates() {
    _moneyUpdatesSub = _shopService.moneyUpdates.listen((newMoney) async {
      if (!mounted) return;

      try {
        await _authService.fetchUser();
      } on Exception catch (e) {
        DebugLogger.log(
          'Error refreshing user info after money update: $e',
          tag: 'WaitingRoomScreen',
        );
      }
    });
  }

  void _listenToAudioSettings() {
    _service.hostMusicEnabled.addListener(_applyHostAudioSettings);
    _service.hostSfxEnabled.addListener(_applyHostAudioSettings);
  }

  void _applyHostAudioSettings() {
    if (!mounted) return;
    if (_service.isHost.value) return;

    final audioService =
        AudioService()..setHostControlledSettings(
          musicEnabled: _service.hostMusicEnabled.value,
          sfxEnabled: _service.hostSfxEnabled.value,
        );
  }

  Future<void> _loadPlayerBanners() async {
    final players = _service.players.value;
    if (players.isEmpty) return;

    for (final player in players) {
      if (player.socketId.startsWith('virtualPlayer')) continue;

      try {
        final userItems = await _shopService.getUserItemsByUsername(
          player.name,
        );
        final equippedBanner = userItems.firstWhere(
          (item) =>
              item['equipped'] == true &&
              (item['itemId'] as String).startsWith('banner_'),
          orElse: () => {},
        );

        if (equippedBanner.isNotEmpty) {
          final bannerId = equippedBanner['itemId'] as String;
          final bannerNumber = bannerId.replaceAll('banner_', '');
          final bannerPath = 'lib/assets/banner/$bannerNumber.png';
          if (mounted) {
            setState(() {
              _playerBanners[player.name] = bannerPath;
            });
          }
        }
      } catch (e) {
        DebugLogger.log(
          'Error loading banner for ${player.name}: $e',
          tag: 'WaitingRoomScreen',
        );
      }
    }
  }

  void _onInviteAllFriends() {
    final gameId = _service.gameId.value;
    final gameName = _service.mapName.value;
    if (gameId.isNotEmpty && gameName.isNotEmpty) {
      FriendService().inviteAllOnlineFriends(gameId, gameName);
      if (mounted && context.mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(
            message: 'Invitations envoyées à vos amis en ligne',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    FriendService().updateUserStatus(UserStatus.online);

    if (_playerListener != null) {
      _playerService.notifier.removeListener(_playerListener!);
    }
    _service.players.removeListener(_loadPlayerBanners);
    _service.hostMusicEnabled.removeListener(_applyHostAudioSettings);
    _service.hostSfxEnabled.removeListener(_applyHostAudioSettings);
    _gearController.dispose();
    _closedSub?.cancel();
    _gameInitializedSub?.cancel();
    _playerKickedSub?.cancel();
    _moneyUpdatesSub?.cancel();
    _service.reset();

    AudioService().clearHostControl();
    unawaited(AudioService().stopMusic());

    final gameId = widget.gameId ?? _service.gameId.value;
    if (gameId.isNotEmpty) {
      ChannelService().removeGameChannel(gameId);
    }

    super.dispose();
  }

  Widget _buildPlayerRow(Player p) {
    final idx = (p.avatar.index + 1).clamp(1, 17);
    final isAI = p.socketId.startsWith('virtualPlayer');
    final isSelected = _service.selectedPlayerSocketId.value == p.socketId;
    final isFirstPlayer =
        _service.players.value.isNotEmpty &&
        _service.players.value[0].socketId == p.socketId;
    final canKick = _service.isHost.value && !isFirstPlayer;
    final bannerPath = _playerBanners[p.name];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border:
            isFirstPlayer
                ? Border.all(
                  color: AppColors.accentHighlight(context),
                  width: 2,
                )
                : null,
        image:
            bannerPath != null
                ? DecorationImage(
                  image: AssetImage(bannerPath),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child: ListTile(
        selected: isSelected,
        onTap:
            canKick
                ? () {
                  _service.selectedPlayerSocketId.value =
                      isSelected ? null : p.socketId;
                }
                : null,
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade900,
          radius: 22,
          child: Image.asset(
            'lib/assets/previewcharacters/${idx}_preview.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                p.name.isNotEmpty ? p.name : 'Joueur',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isAI) ...[
              const SizedBox(width: 8),
              Image.asset(
                'lib/assets/level-badges/level-${p.level}.png',
                width: 30,
                height: 30,
                errorBuilder:
                    (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
            if (isAI) ...[
              const SizedBox(width: 8),
              Image.asset('lib/assets/icons/robot.png', width: 30, height: 30),
            ],
          ],
        ),
        trailing:
            isSelected && canKick
                ? ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _service.kickPlayer(p.socketId),
                  child: const Text('Exclure'),
                )
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioService = AudioService();

    return WillPopScope(
      onWillPop: () async {
        FriendService().updateUserStatus(UserStatus.online);
        await AudioService().stopMusic();
        final gameId = widget.gameId ?? _service.gameId.value;
        if (gameId.isNotEmpty) {
          await ChannelService().removeGameChannel(gameId);
        }
        _service.leaveGame();
        GoRouter.of(context).go('/');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: ThemeBackground(pageId: 'waitingroom'),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftPanel(isDark),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                _buildGameDetails(isDark),
                                const SizedBox(height: 12),
                                _buildPlayersList(isDark),
                                const SizedBox(height: 12),
                                _buildBottomSection(isDark),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [FriendButton(), SizedBox(width: 8), ChatWidget()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(bool isDark) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentHighlight(context),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentHighlight(
                      context,
                    ).withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade900,
                child: ValueListenableBuilder(
                  valueListenable: _playerService.notifier,
                  builder: (context, player, _) {
                    final idx = (player.avatar.index + 1).clamp(1, 17);
                    return Image.asset(
                      'lib/assets/previewcharacters/${idx}_preview.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _playerName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mon argent:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                MoneyWidget(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const ChallengesWidget(isCompact: true),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: _service.isHost,
            builder: (context, isHost, _) {
              if (!isHost) return const SizedBox.shrink();
              return _buildAudioControls(isDark);
            },
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                FriendService().updateUserStatus(UserStatus.online);
                final gameId = widget.gameId ?? _service.gameId.value;
                if (gameId.isNotEmpty) {
                  ChannelService().removeGameChannel(gameId);
                }
                _service.leaveGame();
                AudioService().stopMusic();
                GoRouter.of(context).go('/');
              },
              style: ElevatedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.accentHighlight(context),
                  width: 3,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.exit_to_app, size: 18),
              label: const Text('Quitter', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameDetails(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: _service.gameId,
      builder: (context, gameId, _) {
        return ValueListenableBuilder(
          valueListenable: _service.mapName,
          builder: (context, mapName, _) {
            return ValueListenableBuilder(
              valueListenable: _service.isLocked,
              builder: (context, isLocked, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.isHost,
                  builder: (context, isHost, _) {
                    return ValueListenableBuilder(
                      valueListenable: _service.players,
                      builder: (context, players, _) {
                        return ValueListenableBuilder(
                          valueListenable: _service.maxPlayers,
                          builder: (context, maxPlayers, _) {
                            return ValueListenableBuilder(
                              valueListenable: _service.entryFee,
                              builder: (context, entryFee, _) {
                                return Column(
                                  children: [
                                    if (isHost) ...[
                                      Center(
                                        child: GestureDetector(
                                          onTap:
                                              isHost &&
                                                      !(isLocked &&
                                                          players.length ==
                                                              maxPlayers)
                                                  ? () => _service.toggleLock(
                                                    !isLocked,
                                                  )
                                                  : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isLocked
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    isLocked
                                                        ? Colors.red.shade900
                                                        : Colors.green.shade900,
                                                width: 3,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  isLocked
                                                      ? 'Fermée'
                                                      : 'Ouverte',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      ValueListenableBuilder(
                                        valueListenable: _service.gameSettings,
                                        builder: (context, settings, _) {
                                          if (!settings.isFriendsOnly) {
                                            return const SizedBox.shrink();
                                          }
                                          return ValueListenableBuilder(
                                            valueListenable: _service.isLocked,
                                            builder: (context, isLocked, _) {
                                              return SizedBox(
                                                child: ElevatedButton.icon(
                                                  onPressed:
                                                      isLocked
                                                          ? null
                                                          : _onInviteAllFriends,
                                                  icon: const Icon(
                                                    Icons.group,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Inviter tous mes amis en ligne',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    disabledBackgroundColor:
                                                        Colors.grey,
                                                    disabledForegroundColor:
                                                        Colors.white70,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ] else ...[
                                      // Non-host view: show read-only status
                                      Column(
                                        children: [
                                          Text(
                                            'La partie est',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accentHighlight(
                                                context,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            isLocked ? 'fermée' : 'ouverte',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? Colors.black.withValues(
                                                        alpha: 0.6,
                                                      )
                                                      : Colors.white.withValues(
                                                        alpha: 0.75,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    AppColors.accentHighlight(
                                                      context,
                                                    ),
                                                width: 2,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  'Code',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  gameId,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? Colors.black.withValues(
                                                        alpha: 0.6,
                                                      )
                                                      : Colors.white.withValues(
                                                        alpha: 0.75,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    AppColors.accentHighlight(
                                                      context,
                                                    ),
                                                width: 2,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  'Carte',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  mapName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (entryFee > 0) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFD700),
                                                    Color(0xFFFFED4E),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFFC107,
                                                  ),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFFD700,
                                                    ).withValues(alpha: 0.5),
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    "Frais d'entrée",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF7D4F00),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Image.asset(
                                                        'lib/assets/icons/money.png',
                                                        width: 16,
                                                        height: 16,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return const Icon(
                                                            Icons
                                                                .monetization_on,
                                                            size: 16,
                                                            color: Color(
                                                              0xFF7D4F00,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$entryFee',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF7D4F00,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlayersList(bool isDark) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.accentHighlight(context),
            width: 2,
          ),
          color:
              isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.75),
        ),
        child: ValueListenableBuilder(
          valueListenable: _service.players,
          builder: (context, players, _) {
            return ValueListenableBuilder(
              valueListenable: _service.isHost,
              builder: (context, isHost, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.maxPlayers,
                  builder: (context, maxPlayers, _) {
                    return ValueListenableBuilder(
                      valueListenable: _service.isLocked,
                      builder: (context, isLocked, _) {
                        if (players.isEmpty) {
                          return const Center(child: Text('Aucun joueur'));
                        }

                        final showAddButton =
                            isHost && players.length < maxPlayers && !isLocked;

                        return ListView.builder(
                          itemCount:
                              showAddButton
                                  ? players.length + 1
                                  : players.length,
                          itemBuilder: (ctx, i) {
                            if (i < players.length) {
                              return ValueListenableBuilder(
                                valueListenable:
                                    _service.selectedPlayerSocketId,
                                builder: (context, _, _) {
                                  return _buildPlayerRow(players[i]);
                                },
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: ElevatedButton(
                                onPressed: _onAddVirtualPlayer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentHighlight(
                                    context,
                                  ),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Icon(Icons.add, size: 24),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: _service.isHost,
          builder: (context, isHost, _) {
            return ValueListenableBuilder(
              valueListenable: _service.players,
              builder: (context, players, _) {
                return ValueListenableBuilder(
                  valueListenable: _service.isLocked,
                  builder: (context, isLocked, _) {
                    if (isHost) {
                      if (players.length > 1 && isLocked) {
                        return ElevatedButton(
                          onPressed: _service.initializeGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentHighlight(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Commencer la partie'),
                        );
                      } else if (players.length > 1) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Vérouillez la salle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentHighlight(context),
                            ),
                          ),
                        );
                      }
                    }

                    return Row(
                      children: [
                        RotationTransition(
                          turns: _gearController,
                          child: const Image(
                            image: AssetImage('lib/assets/icons/gear.png'),
                            width: 50,
                            height: 50,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'En attente...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentHighlight(context),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: _service.players,
          builder: (context, players, _) {
            return ValueListenableBuilder(
              valueListenable: _service.maxPlayers,
              builder: (context, maxPlayers, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${players.length}/$maxPlayers',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAudioControls(bool isDark) {
    final audioService = AudioService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Musique:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: audioService.musicEnabledNotifier,
              builder: (context, enabled, _) {
                return SizedBox(
                  width: 35,
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.buttonBackgroundDark
                              : AppColors.buttonBackgroundLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      final newValue = !enabled;
                      audioService.musicEnabled = newValue;
                      _service.updateAudioSettings(
                        musicEnabled: newValue,
                        sfxEnabled: audioService.sfxEnabled,
                      );
                      setState(() {});
                    },
                    child: Icon(
                      enabled ? Icons.music_note : Icons.music_off,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.buttonTextDark
                              : AppColors.buttonTextLight,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder<String>(
          valueListenable: audioService.equippedMusicNotifier,
          builder: (context, selectedMusic, _) {
            final user = _authService.notifier.value;
            final ownsMinecraft =
                user?.shopItems.any((item) => item.itemId == 'sound_1') ??
                false;

            final musicItems = <DropdownMenuItem<String>>[
              const DropdownMenuItem(
                value: 'music2.mp3',
                child: Text(
                  'Défaut',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ];

            if (ownsMinecraft) {
              musicItems.add(
                const DropdownMenuItem(
                  value: 'minecraft.mp3',
                  child: Text(
                    'Minecraft',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              );
            }

            return SizedBox(
              width: double.infinity,
              child: DropdownButton<String>(
                value: selectedMusic,
                isExpanded: true,
                items: musicItems,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    audioService.setEquippedMusic(newValue);
                    _service.updateAudioSettings(
                      musicEnabled: audioService.musicEnabled,
                      sfxEnabled: audioService.sfxEnabled,
                      equippedMusic: newValue,
                    );
                  }
                },
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Effets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'sonores:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: audioService.sfxEnabledNotifier,
              builder: (context, enabled, _) {
                return SizedBox(
                  width: 35,
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.buttonBackgroundDark
                              : AppColors.buttonBackgroundLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      final newValue = !enabled;
                      audioService.sfxEnabled = newValue;
                      _service.updateAudioSettings(
                        musicEnabled: audioService.musicEnabled,
                        sfxEnabled: newValue,
                      );
                      setState(() {});
                    },
                    child: Icon(
                      enabled ? Icons.volume_up : Icons.volume_off,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.buttonTextDark
                              : AppColors.buttonTextLight,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _onAddVirtualPlayer() async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => ProfileModalWidget(
            activePlayers: _service.players.value,
            onSubmit: _service.addVirtualPlayer,
          ),
    );
  }
}
