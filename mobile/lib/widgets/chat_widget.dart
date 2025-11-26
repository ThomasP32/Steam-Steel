import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/common/message.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/channel_service.dart';
import 'package:mobile/services/chat_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/channel_manager_widget.dart';
import 'package:mobile/widgets/profile_picture_widget.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    super.key,
    this.initiallyVisible = false,
    this.showToggleButton = true,
    this.onClose,
  });

  final bool initiallyVisible;
  final bool showToggleButton;
  final VoidCallback? onClose;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late final AnimationController _ctrl;
  final List<dynamic> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _listController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  StreamSubscription<dynamic>? _prevSub;
  StreamSubscription<dynamic>? _newSub;
  StreamSubscription<dynamic>? _deletedSub;
  StreamSubscription<dynamic>? _activeChannelSub;
  VoidCallback? _authListener;
  String _userName = 'Guest';
  bool _loading = false;

  ChatService chatService = ChatService();
  final ChannelService _channelService = ChannelService();
  final FriendService _friendService = FriendService();
  VoidCallback? _closeDropdownsCallback;

  List<Friend> _friends = [];
  void Function(String, UserStatus)? _statusUpdateListener;
  void Function(Friend)? _friendAddedListener;

  @override
  void initState() {
    super.initState();
    _visible = widget.initiallyVisible;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _inputFocusNode.addListener(() {
      _overlayEntry?.markNeedsBuild();

      if (_inputFocusNode.hasFocus) {
        _closeDropdownsCallback?.call();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _scrollToBottom();
        });
      }
    });

    try {
      _prevSub = SocketService()
          .listen<List<dynamic>>('previousMessages')
          .listen((List<dynamic> data) {
            final msgs =
                data
                    .whereType<Map<String, dynamic>>()
                    .map<Message>(chatService.messageFromMap)
                    .toList()
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

            if (!mounted) return;
            setState(() {
              final serverList = msgs;
              final serverIds = <String>{};
              for (final m in serverList) {
                serverIds.add(
                  m.id ?? m.timestamp.millisecondsSinceEpoch.toString(),
                );
              }

              final existing =
                  _messages.map((r) => chatService.ensureMessage(r)).toList();

              final localOnly =
                  existing.where((e) {
                    final key =
                        e.id ?? e.timestamp.millisecondsSinceEpoch.toString();
                    return !serverIds.contains(key);
                  }).toList();

              final toAppend = localOnly;
              _messages
                ..clear()
                ..addAll(serverList)
                ..addAll(toAppend);

              _loading = false;
            });
            _overlayEntry?.markNeedsBuild();
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          });
    } on Object catch (e) {
      DebugLogger.log(
        'previousMessages listener init error: $e',
        tag: 'ChatWidget',
      );
    }

    try {
      _newSub = SocketService()
          .listen<Map<String, dynamic>>('newMessage')
          .listen((m) {
            try {
              final msg = chatService.messageFromMap(m);
              if (!mounted) return;
              setState(() {
                _messages
                  ..removeWhere((raw) {
                    final cand = chatService.ensureMessage(raw);
                    final candId =
                        cand.id ??
                        cand.timestamp.millisecondsSinceEpoch.toString();
                    final msgId =
                        msg.id ??
                        msg.timestamp.millisecondsSinceEpoch.toString();
                    return candId == msgId;
                  })
                  ..add(msg);
              });
              _overlayEntry?.markNeedsBuild();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            } on Object catch (e) {
              DebugLogger.log('newMessage parse error: $e', tag: 'ChatWidget');
            }
          });
    } on Object catch (e) {
      DebugLogger.log('newMessage listener init error: $e', tag: 'ChatWidget');
    }

    try {
      _deletedSub = SocketService()
          .listen<Map<String, dynamic>>('messageDeleted')
          .listen((p) {
            try {
              DebugLogger.log('messageDeleted received: $p', tag: 'ChatWidget');
              final messageId =
                  (p['messageId'] as String?) ?? (p['id'] as String?);
              if (messageId == null) {
                final author = p['author'] as String?;
                final text = p['text'] as String?;
                final tsStr = p['timestamp'] as String?;
                DateTime? ts;
                if (tsStr != null) ts = DateTime.tryParse(tsStr)?.toLocal();
                if (!mounted) return;
                setState(() {
                  _messages.removeWhere((raw) {
                    final cand = chatService.ensureMessage(raw);
                    if (author != null && cand.author != author) return false;
                    if (text != null && cand.text != text) return false;
                    if (ts != null && cand.timestamp != ts) return false;
                    return true;
                  });
                });
                _overlayEntry?.markNeedsBuild();
                return;
              }
              if (!mounted) return;
              setState(() {
                _messages.removeWhere((raw) {
                  final cand = chatService.ensureMessage(raw);
                  return (cand.id != null && cand.id == messageId) ||
                      (cand.timestamp.millisecondsSinceEpoch.toString() ==
                          messageId);
                });
              });
              _overlayEntry?.markNeedsBuild();
            } on Object catch (e) {
              DebugLogger.log(
                'messageDeleted parse error: $e',
                tag: 'ChatWidget',
              );
            }
          });
    } on Object catch (e) {
      DebugLogger.log(
        'messageDeleted listener init error: $e',
        tag: 'ChatWidget',
      );
    }

    try {
      final user = AuthService().notifier.value;
      if (user != null) _userName = user.username;
      _authListener = () {
        final u = AuthService().notifier.value;
        if (!mounted) return;
        setState(() => _userName = u?.username ?? 'Guest');

        _overlayEntry?.markNeedsBuild();
      };
      AuthService().notifier.addListener(_authListener!);
    } on Object catch (_) {}

    _loadFriends();
    _statusUpdateListener = (username, status) {
      if (!mounted) return;

      _loadFriends().then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _overlayEntry?.markNeedsBuild();
        });
      });
    };
    _friendService.addOnFriendStatusUpdateListener(_statusUpdateListener!);

    _friendAddedListener = (friend) {
      if (!mounted) return;
      setState(() {
        if (!_friends.any((f) => f.username == friend.username)) {
          _friends.add(friend);
        }
      });
      _overlayEntry?.markNeedsBuild();
      DebugLogger.log(
        'Friend added: ${friend.username}, overlay refreshed',
        tag: 'ChatWidget',
      );
    };
    _friendService.addOnFriendAddedListener(_friendAddedListener!);

    _channelService.init();

    if (widget.initiallyVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showOverlay();
        }
      });
    }
  }

  Future<void> _loadFriends() async {
    DebugLogger.log('Starting to load friends...', tag: 'ChatWidget');
    try {
      final friends = await _friendService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
      });
      DebugLogger.log(
        'Loaded ${_friends.length} friends: ${_friends.map((f) => f.username).join(", ")}',
        tag: 'ChatWidget',
      );
    } catch (e) {
      DebugLogger.log('Error loading friends: $e', tag: 'ChatWidget');
    }
  }

  Friend? _getFriendInfo(String username) {
    try {
      final friend = _friends.firstWhere((f) => f.username == username);
      DebugLogger.log(
        'Found friend info for $username: avatar=${friend.avatar}, status=${friend.status}',
        tag: 'ChatWidget',
      );
      return friend;
    } catch (e) {
      DebugLogger.log(
        'No friend info found for $username (not a friend or list not loaded)',
        tag: 'ChatWidget',
      );
      return null;
    }
  }

  String _getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'En ligne';
      case UserStatus.offline:
        return 'Hors ligne';
      case UserStatus.inGame:
        return 'En jeu';
      case UserStatus.unknown:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.offline:
        return Colors.grey;
      case UserStatus.inGame:
        return Colors.orange;
      case UserStatus.unknown:
        return Colors.grey;
    }
  }

  UserStatus _parseUserStatus(String? status) {
    if (status == null) return UserStatus.unknown;
    switch (status.toLowerCase()) {
      case 'online':
        return UserStatus.online;
      case 'offline':
        return UserStatus.offline;
      case 'ingame':
        return UserStatus.inGame;
      default:
        return UserStatus.unknown;
    }
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      try {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.info(message: 'Le message est vide'),
        );
      } on Object catch (_) {}
      return;
    }

    final activeChannel = _channelService.activeChannel;
    final roomName = activeChannel?.name ?? 'global';

    final msg = {
      'roomName': roomName,
      'message': {
        'author': _userName,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'gameId': null,
      },
    };
    try {
      SocketService().send('message', msg);
      _inputCtrl.clear();
      try {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      } on Object catch (_) {}
    } on Object catch (_) {}
  }

  void _getMessagesFromDB() {
    final activeChannel = _channelService.activeChannel;
    final channelName = activeChannel?.name ?? 'global';
    DebugLogger.log(
      'Getting messages from DB for channel: $channelName',
      tag: 'ChatWidget',
    );
    _loadChannelMessages(channelName);
  }

  void _loadChannelMessages(String channelName) {
    try {
      if (!mounted) return;

      DebugLogger.log(
        'Loading messages for channel: $channelName',
        tag: 'ChatWidget',
      );

      setState(() {
        _loading = true;
        _messages.clear();
      });
      _overlayEntry?.markNeedsBuild();

      SocketService().send('joinChatRoom', channelName);

      DebugLogger.log(
        'Sent joinChatRoom event for: $channelName',
        tag: 'ChatWidget',
      );
    } on Object catch (e) {
      DebugLogger.log('send joinChatRoom failed: $e', tag: 'ChatWidget');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    try {
      if (_listController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_listController.hasClients) {
            _listController.jumpTo(_listController.position.maxScrollExtent);
          }
        });
      }
    } on Object catch (e) {
      DebugLogger.log('scrollToBottom failed: $e', tag: 'ChatWidget');
    }
  }

  @override
  void dispose() {
    _prevSub?.cancel();
    _newSub?.cancel();
    _deletedSub?.cancel();
    _activeChannelSub?.cancel();
    _hideOverlay();
    if (_authListener != null) {
      try {
        AuthService().notifier.removeListener(_authListener!);
      } on Object catch (_) {}
    }
    if (_statusUpdateListener != null) {
      _friendService.removeOnFriendStatusUpdateListener(_statusUpdateListener!);
    }
    if (_friendAddedListener != null) {
      _friendService.removeOnFriendAddedListener(_friendAddedListener!);
    }
    _inputCtrl.dispose();
    _listController.dispose();
    _inputFocusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null || !mounted) return;

    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlayContent());

    Overlay.of(context).insert(_overlayEntry!);

    setState(() {
      _visible = true;
    });

    _activeChannelSub ??= _channelService.activeChannel$.listen((channel) {
      if (channel != null && mounted && _overlayEntry != null) {
        DebugLogger.log(
          'Active channel changed to: ${channel.name}, loading messages',
          tag: 'ChatWidget',
        );
        _loadChannelMessages(channel.name);
      }
    });

    _loadFriends();

    _getMessagesFromDB();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }

  void _hideOverlay() {
    if (mounted) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      setState(() {
        _visible = false;
      });
      _inputFocusNode.unfocus();
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    widget.onClose?.call();
  }

  void _toggle() {
    if (_visible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  Widget _buildOverlayContent() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;

        final isDesktop =
            Theme.of(context).platform == TargetPlatform.macOS ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.windows;

        final shouldPushUp = _inputFocusNode.hasFocus;
        final bottomOffset = shouldPushUp ? keyboardHeight : 0.0;

        return MediaQuery(
          data:
              isDesktop
                  ? mediaQuery
                  : mediaQuery.copyWith(
                    viewInsets: EdgeInsets.zero,
                    padding: mediaQuery.padding.copyWith(bottom: 0),
                  ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
              ),

              Positioned(
                top: 0,
                right: 0,
                bottom: bottomOffset,
                width: mediaQuery.size.width / 3,
                child: Material(
                  elevation: 24,
                  color:
                      isDark
                          ? const Color(0xFF2E3136)
                          : Colors.white.withValues(alpha: 0.95),
                  child: _buildChatPanel(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showToggleButton) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 18, right: 12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark
                        ? AppColors.buttonBackgroundDark
                        : AppColors.buttonBackgroundLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: _toggle,
              child: Icon(
                Icons.chat_bubble_outline,
                color:
                    isDark
                        ? AppColors.buttonTextDark
                        : AppColors.buttonTextLight,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildChatPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2124) : Colors.grey.shade200,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF2E3136) : Colors.grey.shade300,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Clavardage',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Press Start 2P',
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _toggle,
                iconSize: 20,
              ),
            ],
          ),
        ),

        Builder(
          builder: (context) {
            return ChannelManagerWidget(
              userName: _userName,
              onRegisterCloseCallback: (callback) {
                _closeDropdownsCallback = callback;
              },
              onDropdownOpened: _inputFocusNode.unfocus,
            );
          },
        ),

        StreamBuilder(
          stream: _channelService.activeChannel$,
          builder: (context, snapshot) {
            final activeChannel = snapshot.data;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2124) : Colors.grey.shade200,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark ? const Color(0xFF2E3136) : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'Salon actuel: ${activeChannel?.name ?? 'global'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Press Start 2P',
                  color: AppColors.accentHighlight(context),
                ),
              ),
            );
          },
        ),

        Divider(
          color: isDark ? const Color(0xFF3B3F46) : Colors.grey.shade300,
          height: 1,
        ),

        Expanded(
          child: GestureDetector(
            onTap: _inputFocusNode.unfocus,
            child: Container(
              padding: const EdgeInsets.all(12),
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_messages.isEmpty
                          ? Center(
                            child: Text(
                              'Aucun message',
                              style: TextStyle(
                                color:
                                    isDark
                                        ? const Color(0xFFC0C0C0)
                                        : Colors.grey.shade600,
                                fontFamily: 'Press Start 2P',
                                fontSize: 10,
                              ),
                            ),
                          )
                          : ListView.builder(
                            controller: _listController,
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) {
                              final raw = _messages[i];
                              final m = chatService.ensureMessage(raw);
                              final time =
                                  '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}:${m.timestamp.second.toString().padLeft(2, '0')}';
                              final mine = m.author == _userName;
                              final friendInfo = _getFriendInfo(m.author);
                              final isFriend = friendInfo != null;
                              final currentUser =
                                  mine ? AuthService().notifier.value : null;

                              if (!mine) {
                                DebugLogger.log(
                                  'Message from ${m.author}: isFriend=$isFriend, friendInfo=$friendInfo, authorAvatar=${m.authorAvatar}, authorAvatarCustom=${m.authorAvatarCustom}',
                                  tag: 'ChatWidget',
                                );
                              }

                              return Align(
                                alignment:
                                    mine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (m.author == '[supprimé]')
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[700],
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        )
                                      else
                                        ProfilePictureWidget(
                                          size: 32,
                                          username: m.author,
                                          avatar:
                                              mine
                                                  ? (currentUser?.avatar !=
                                                              null &&
                                                          currentUser!
                                                              .avatar
                                                              .isNotEmpty
                                                      ? int.tryParse(
                                                        currentUser.avatar,
                                                      )
                                                      : null)
                                                  : (isFriend
                                                      ? friendInfo.avatar
                                                      : m.authorAvatar),
                                          avatarCustom:
                                              mine
                                                  ? currentUser?.avatarCustom
                                                  : (isFriend
                                                      ? friendInfo.avatarCustom
                                                      : m.authorAvatarCustom),
                                          profilePicture:
                                              mine
                                                  ? currentUser?.profilePicture
                                                  : (isFriend
                                                      ? friendInfo
                                                          .profilePicture
                                                      : m.authorProfilePicture),
                                          profilePictureCustom:
                                              mine
                                                  ? currentUser
                                                      ?.profilePictureCustom
                                                  : (isFriend
                                                      ? friendInfo
                                                          .profilePictureCustom
                                                      : m.authorProfilePictureCustom),
                                          status:
                                              mine
                                                  ? _parseUserStatus(
                                                    currentUser?.status,
                                                  )
                                                  : (isFriend
                                                      ? friendInfo.status
                                                      : null),
                                          showStatusIndicator: mine || isFriend,
                                        ),
                                      const SizedBox(width: 8),
                                      // Message
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width /
                                                4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(0xFF3B3F46)
                                                    : Colors.grey.shade300,
                                            border:
                                                mine
                                                    ? Border.all(
                                                      color:
                                                          AppColors.accentHighlight(
                                                            context,
                                                          ),
                                                      width: 2,
                                                    )
                                                    : null,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Statut au-dessus du pseudonyme pour tous
                                              if (mine &&
                                                  currentUser?.status !=
                                                      null) ...[
                                                Text(
                                                  _getStatusText(
                                                    _parseUserStatus(
                                                      currentUser?.status,
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                      _parseUserStatus(
                                                        currentUser?.status,
                                                      ),
                                                    ),
                                                    fontSize: 7,
                                                    fontFamily:
                                                        'Press Start 2P',
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                              ] else if (!mine && isFriend) ...[
                                                Text(
                                                  _getStatusText(
                                                    friendInfo.status,
                                                  ),
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                      friendInfo.status,
                                                    ),
                                                    fontSize: 7,
                                                    fontFamily:
                                                        'Press Start 2P',
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                              ],
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    m.author,
                                                    style: TextStyle(
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 10,
                                                      fontFamily:
                                                          'Press Start 2P',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    time,
                                                    style: TextStyle(
                                                      color: (isDark
                                                              ? Colors.white
                                                              : Colors.black)
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      fontSize: 8,
                                                      fontFamily:
                                                          'Press Start 2P',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                m.text,
                                                style: TextStyle(
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                  fontSize: 10,
                                                  fontFamily: 'Press Start 2P',
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
                            },
                          )),
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2124) : Colors.grey.shade200,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF2E3136) : Colors.grey.shade300,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _inputFocusNode,
                  enableInteractiveSelection: true,
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontFamily: 'Press Start 2P',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 10,
                      fontFamily: 'Press Start 2P',
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2E3136) : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLength: 250,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: Icon(
                  Icons.send,
                  color: AppColors.accentHighlight(context),
                ),
                iconSize: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
