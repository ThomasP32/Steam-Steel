import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile/common/constants.dart';
import 'package:mobile/common/message.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/chat_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/delete_confirm_dialog.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  OverlayEntry? _overlayEntry;
  late final AnimationController _ctrl;
  final List<dynamic> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  StreamSubscription<AccelerometerEvent>? _accelSub;
  int _selectedReactionIndex = 0;
  String? _lastUserMessage;
  DateTime _lastAutoSend = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<dynamic>? _prevSub;
  StreamSubscription<dynamic>? _newSub;
  StreamSubscription<dynamic>? _deletedSub;
  VoidCallback? _authListener;
  String _userName = 'Guest';
  bool _loading = false;
  String? _autoSendLabel;

  ChatService chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    try {
      _prevSub = SocketService()
          .listen<List<dynamic>>('previousMessages')
          .listen((List<dynamic> data) {
            DebugLogger.log(
              'previousMessages received: ${data.length} items',
              tag: 'ChatWidget',
            );
            final msgs =
                data
                    .whereType<Map<String, dynamic>>()
                    .map<Message>(chatService.messageFromMap)
                    .toList();
            for (var i = msgs.length - 1; i >= 0; i--) {
              final m = msgs[i];
              if (m.author == _userName && (m.text.trim().isNotEmpty)) {
                _lastUserMessage = m.text;
                break;
              }
            }
            if (!mounted) return;
            setState(() {
              _messages
                ..clear()
                ..addAll(msgs);
              _loading = false;
            });
            _overlayEntry?.markNeedsBuild();
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
              DebugLogger.log('newMessage received: $m', tag: 'ChatWidget');
              final msg = chatService.messageFromMap(m);
              if (!mounted) return;
              setState(() => _messages.add(msg));
              _overlayEntry?.markNeedsBuild();
              if (msg.author == _userName && (msg.text.trim().isNotEmpty)) {
                _lastUserMessage = msg.text;
              }
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
      };
      AuthService().notifier.addListener(_authListener!);
    } on Object catch (_) {}

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _accelSub = accelerometerEvents
            .handleError((e) {
              DebugLogger.log(
                'accelerometer stream error: $e',
                tag: 'ChatWidget',
              );
            })
            .listen(_handleAccel);
      } else {
        DebugLogger.log(
          'accelerometer not initialized on this platform',
          tag: 'ChatWidget',
        );
      }
    } on Object catch (e) {
      DebugLogger.log('accelerometer init error: $e', tag: 'ChatWidget');
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
    final msg = {
      'roomName': 'global',
      'message': {
        'author': _userName,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'gameId': null,
      },
    };
    try {
      SocketService().send('message', msg);
      _lastUserMessage = text;
      _inputCtrl.clear();
      _overlayEntry?.markNeedsBuild();
    } on Object catch (_) {}
  }

  void _getMessagesFromDB() {
    try {
      if (!mounted) return;
      setState(() => _loading = true);
      SocketService().send('joinChatRoom', 'global');
    } on Object catch (e) {
      DebugLogger.log('send joinChatRoom failed: $e', tag: 'ChatWidget');
      if (mounted) setState(() => _loading = false);
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _prevSub?.cancel();
    _newSub?.cancel();
    if (_authListener != null) {
      try {
        AuthService().notifier.removeListener(_authListener!);
      } on Object catch (_) {}
    }
    _inputCtrl.dispose();
    _accelSub?.cancel();
    _deletedSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _handleAccel(AccelerometerEvent e) {
    const double threshold = 6;
    final ax = e.x;
    final ay = e.y;
    final az = e.z;

    final now = DateTime.now();
    if (now.difference(_lastAutoSend).inMilliseconds < 600) return;

    const thresholdSq = threshold * threshold;
    final magSq = ax * ax + ay * ay + az * az;

    if (magSq <= thresholdSq) return;

    final absAx = ax.abs();
    final absAy = ay.abs();
    final absAz = az.abs();

    if (absAy >= absAx && absAy >= absAz) {
      final text = _lastUserMessage?.trim();
      if (text != null && text.isNotEmpty) {
        _inputCtrl.text = text;
        _inputCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputCtrl.text.length),
        );
        _overlayEntry?.markNeedsBuild();
        _lastAutoSend = now;
      }
    } else if (absAx >= absAy && absAx >= absAz) {
      final emoji = CHAT_REACTIONS[_selectedReactionIndex];
      _inputCtrl.text = emoji;
      _inputCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: emoji.length),
      );
      _overlayEntry?.markNeedsBuild();
      _lastAutoSend = now;
    }
  }

  void _toggle() {
    if (!_visible) {
      try {
        _overlayEntry = _createOverlayEntry();
        Overlay.of(context).insert(_overlayEntry!);
      } on Object catch (e) {
        DebugLogger.log('overlay insert failed: $e', tag: 'ChatWidget');
      }
      setState(() => _visible = true);
      _ctrl.forward();
      _getMessagesFromDB();
    } else {
      _ctrl.reverse().then((_) {
        try {
          _overlayEntry?.remove();
        } on Object catch (e) {
          DebugLogger.log('overlay remove failed: $e', tag: 'ChatWidget');
        }
        _overlayEntry = null;
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggle,
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _ctrl,
                      curve: Curves.easeOut,
                    ),
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _ctrl,
                        curve: Curves.easeOutBack,
                      ),
                      child: GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.translucent,
                        child: Material(
                          elevation: 24,
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF3B3F46),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(ctx).size.width * 0.95,
                              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                              minWidth: 300,
                              minHeight: 200,
                            ),
                            child: _buildPopupContent(ctx),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupContent(BuildContext ctx) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Global chat',
                      style: TextStyle(
                        color: Color(0xFFC0C0C0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_autoSendLabel != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _autoSendLabel!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    Flexible(
                      child: SizedBox(
                        height: 32,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List<Widget>.generate(
                              CHAT_REACTIONS.length,
                              (idx) {
                                final r = CHAT_REACTIONS[idx];
                                final selected = idx == _selectedReactionIndex;
                                return GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(
                                      () => _selectedReactionIndex = idx,
                                    );
                                    // ensure overlay updates immediately
                                    _overlayEntry?.markNeedsBuild();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          selected
                                              ? Colors.white24
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        r,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFFC0C0C0)),
                onPressed: _toggle,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_messages.isEmpty
                        ? const Center(
                          child: Text(
                            'Aucun message',
                            style: TextStyle(color: Color(0xFFC0C0C0)),
                          ),
                        )
                        : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final raw = _messages[i];
                            final m = chatService.ensureMessage(raw);
                            final time =
                                '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}';
                            final mine = m.author == _userName;
                            final Widget messageCard = Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    mine
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            mine
                                                ? const Color(0xFF2E8B57)
                                                : const Color(0xFF4A4F55),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${m.author} • $time',
                                            style: const TextStyle(
                                              color: Color(0xFFCCCCCC),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            m.text,
                                            style: const TextStyle(
                                              color: Color(0xFFF1F1F1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (!mine) return messageCard;

                            return Dismissible(
                              key: Key(
                                '${m.author}-${m.timestamp.millisecondsSinceEpoch}-${m.text.hashCode}',
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (dir) async {
                                final res = await showDeleteConfirmDialog(
                                  context,
                                );
                                return res ?? false;
                              },
                              onDismissed: (dir) {
                                setState(() => _messages.removeAt(i));
                                try {
                                  SocketService().send('deleteMessage', {
                                    'author': m.author,
                                    'text': m.text,
                                    'timestamp': m.timestamp.toIso8601String(),
                                  });
                                } on Object catch (e) {
                                  DebugLogger.log(
                                    'deleteMessage emit failed: $e',
                                    tag: 'ChatWidget',
                                  );
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.redAccent,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: GestureDetector(
                                onLongPress: () async {
                                  final res = await showDeleteConfirmDialog(
                                    context,
                                  );
                                  if (res ?? false) {
                                    setState(() => _messages.removeAt(i));
                                    try {
                                      await chatService.deleteMessage(m);
                                    } on Object catch (e) {
                                      DebugLogger.log(
                                        'deleteMessage emit failed: $e',
                                        tag: 'ChatWidget',
                                      );
                                    }
                                  }
                                },
                                child: messageCard,
                              ),
                            );
                          },
                        )),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    filled: true,
                    fillColor: Colors.white24,
                  ),
                  maxLength: 250,
                ),
              ),
              IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_visible)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: Container(color: Colors.black54),
            ),
          ),
        Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
              child: Material(
                elevation: 24,
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF3B3F46),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.95,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                    minWidth: 300,
                    minHeight: 200,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Text(
                                    'Global chat',
                                    style: TextStyle(
                                      color: Color(0xFFC0C0C0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: SizedBox(
                                      height: 32,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: List<
                                            Widget
                                          >.generate(CHAT_REACTIONS.length, (
                                            idx,
                                          ) {
                                            final r = CHAT_REACTIONS[idx];
                                            final selected =
                                                idx == _selectedReactionIndex;
                                            return GestureDetector(
                                              onTap: () {
                                                if (!mounted) return;
                                                setState(
                                                  () =>
                                                      _selectedReactionIndex =
                                                          idx,
                                                );
                                                _overlayEntry?.markNeedsBuild();
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      selected
                                                          ? Colors.white24
                                                          : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    r,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFFC0C0C0),
                              ),
                              onPressed: _toggle,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child:
                              _loading
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : (_messages.isEmpty
                                      ? const Center(
                                        child: Text(
                                          'Aucun message',
                                          style: TextStyle(
                                            color: Color(0xFFC0C0C0),
                                          ),
                                        ),
                                      )
                                      : ListView.builder(
                                        itemCount: _messages.length,
                                        itemBuilder: (ctx, i) {
                                          final raw = _messages[i];
                                          final m = chatService.ensureMessage(
                                            raw,
                                          );
                                          final time =
                                              '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}';
                                          final mine = m.author == _userName;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  mine
                                                      ? MainAxisAlignment.end
                                                      : MainAxisAlignment.start,
                                              children: [
                                                Flexible(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          mine
                                                              ? const Color(
                                                                0xFF2E8B57,
                                                              )
                                                              : const Color(
                                                                0xFF4A4F55,
                                                              ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '${m.author} • $time',
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFCCCCCC,
                                                                ),
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          m.text,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFF1F1F1,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  filled: true,
                                  fillColor: Colors.white24,
                                ),
                                maxLength: 250,
                              ),
                            ),
                            IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Square button top-right
        Positioned(
          top: 12,
          right: 12,
          child: SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: _toggle,
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFFC0C0C0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
