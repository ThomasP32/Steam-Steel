import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/common/message.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/chat_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:mobile/widgets/delete_confirm_dialog.dart';
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
  OverlayEntry? _overlayEntry;
  late final AnimationController _ctrl;
  final List<dynamic> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _listController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

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
    _visible = widget.initiallyVisible;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // If initially visible, show the chat after build
    if (widget.initiallyVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry == null) {
          _showChat();
        }
      });
    }

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
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
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
      };
      AuthService().notifier.addListener(_authListener!);
    } on Object catch (_) {}
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
      _inputCtrl.clear();
      try {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      } on Object catch (_) {}
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

  void _scrollToBottom() {
    try {
      if (_listController.hasClients) {
        final max = _listController.position.maxScrollExtent;
        _listController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } on Object catch (e) {
      DebugLogger.log('scrollToBottom failed: $e', tag: 'ChatWidget');
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
    _listController.dispose();
    _deletedSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _showChat() {
    try {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } on Object catch (e) {
      DebugLogger.log('overlay insert failed: $e', tag: 'ChatWidget');
    }
    setState(() => _visible = true);
    _ctrl.forward().then((_) {
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            FocusScope.of(context).requestFocus(_inputFocusNode);
          } on Object catch (e) {
            DebugLogger.log('requestFocus failed: $e', tag: 'ChatWidget');
          }
        });
      } on Object catch (e) {
        DebugLogger.log('postFrame requestFocus failed: $e', tag: 'ChatWidget');
      }
    });
    _getMessagesFromDB();
  }

  void _hideChat() {
    _ctrl.reverse().then((_) {
      try {
        try {
          _inputFocusNode.unfocus();
        } on Object catch (_) {}
        _overlayEntry?.remove();
      } on Object catch (e) {
        DebugLogger.log('overlay remove failed: $e', tag: 'ChatWidget');
      }
      _overlayEntry = null;
      if (mounted) setState(() => _visible = false);
      widget.onClose?.call();
    });
  }

  void _toggle() {
    if (!_visible) {
      _showChat();
    } else {
      _hideChat();
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
    // Add padding that responds to the keyboard (viewInsets) so the input
    // field is not covered. Using AnimatedPadding provides a smooth transition.
    return AnimatedPadding(
      padding: MediaQuery.of(ctx).viewInsets,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Column(
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
                        'Chat global',
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
                      const Flexible(
                        child: SizedBox(
                          height: 32,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
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
                            controller: _listController,
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) {
                              final raw = _messages[i];
                              final m = chatService.ensureMessage(raw);
                              final time =
                                  '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}:${m.timestamp.second.toString().padLeft(2, '0')}';
                              final mine = m.author == _userName;
                              final Widget messageCard = Padding(
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
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color:
                                              mine
                                                  ? const Color(0xFF2E8B57)
                                                  : const Color(0xFF4A4F55),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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

                              return GestureDetector(
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
                    focusNode: _inputFocusNode,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_visible) {
          _toggle();
          return false;
        }
        return true;
      },
      child: Stack(
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
                scale: CurvedAnimation(
                  parent: _ctrl,
                  curve: Curves.easeOutBack,
                ),
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
                              const Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'Chat global',
                                      style: TextStyle(
                                        color: Color(0xFFC0C0C0),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: SizedBox(
                                        height: 32,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    mine
                                                        ? MainAxisAlignment.end
                                                        : MainAxisAlignment
                                                            .start,
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
                                  focusNode: _inputFocusNode,
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
          if (widget.showToggleButton)
            Positioned(
              top: 18,
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
      ),
    );
  }
}
