import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/common/message.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late final AnimationController _ctrl;
  late final Animation<Offset> _offsetAnim;
  final List<dynamic> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  StreamSubscription<dynamic>? _prevSub;
  StreamSubscription<dynamic>? _newSub;
  VoidCallback? _authListener;
  String _userName = 'Guest';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
                    .map<Message>(_messageFromMap)
                    .toList();
            if (!mounted) return;
            setState(() {
              _messages
                ..clear()
                ..addAll(msgs);
              _loading = false;
            });
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
              final msg = _messageFromMap(m);
              if (!mounted) return;
              setState(() => _messages.add(msg));
            } on Object catch (e) {
              DebugLogger.log('newMessage parse error: $e', tag: 'ChatWidget');
            }
          });
    } on Object catch (e) {
      DebugLogger.log('newMessage listener init error: $e', tag: 'ChatWidget');
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

  Message _ensureMessage(dynamic raw) {
    if (raw is Message) return raw;
    if (raw is Map<String, dynamic>) return _messageFromMap(raw);
    // fallback
    return Message(
      author: 'User',
      text: raw?.toString() ?? '',
      timestamp: DateTime.now(),
      roomType: 'global',
    );
  }

  Message _messageFromMap(Map<String, dynamic> m) {
    // timestamp handling
    DateTime ts;
    final raw = m['timestamp'];
    if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      ts = DateTime.now();
    }

    final author =
        (m['author'] as String?) ??
        (m['user']?['username'] as String?) ??
        'User';
    final text = (m['text'] as String?) ?? '';
    final roomType = (m['roomType'] as String?) ?? 'global';
    final roomId = m['roomId'] as String?;
    final gameId = m['gameId'] as String?;
    final channel = m['channel'] as String?;

    return Message(
      author: author,
      text: text,
      timestamp: ts,
      roomType: roomType,
      roomId: roomId,
      gameId: gameId,
      channel: channel,
    );
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
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
    } on Object catch (_) {}
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
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _visible = !_visible;
      if (_visible) {
        _ctrl.forward();
        // request previous messages from server (DB)
        _requestPreviousMessages();
      } else {
        _ctrl.reverse();
      }
    });
  }

  void _requestPreviousMessages() {
    try {
      DebugLogger.log('sending joinChatRoom -> global', tag: 'ChatWidget');
      if (!mounted) return;
      setState(() => _loading = true);
      SocketService().send('joinChatRoom', 'global');
    } on Object catch (e) {
      DebugLogger.log('send joinChatRoom failed: $e', tag: 'ChatWidget');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Slide-up panel
        Positioned(
          right: 12,
          bottom: 0,
          width:
              MediaQuery.of(context).size.width * 0.85 > 380
                  ? 380
                  : MediaQuery.of(context).size.width * 0.9,
          child: SlideTransition(
            position: _offsetAnim,
            child: Material(
              elevation: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              color: const Color(0xFF3B3F46),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
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
                          const Text(
                            'Global chat',
                            style: TextStyle(
                              color: Color(0xFFC0C0C0),
                              fontWeight: FontWeight.bold,
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
                                        final m = _ensureMessage(raw);
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
                                                  padding: const EdgeInsets.all(
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
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFFCCCCCC,
                                                          ),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        m.text,
                                                        style: const TextStyle(
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
