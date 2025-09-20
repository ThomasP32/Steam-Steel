import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
// no keyboard-specific imports needed for mobile

typedef OnJoin = void Function(String code);

class JoinGameCode extends StatefulWidget {
  const JoinGameCode({required this.onJoin, super.key, this.length = 4});
  final OnJoin onJoin;
  final int length;

  @override
  State<JoinGameCode> createState() => _JoinGameCodeState();
}

class _JoinGameCodeState extends State<JoinGameCode> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    // Use the shared app-level SocketService. It should be connected at app
    // startup (in main) so widgets only subscribe to events.
    _socketService = SocketService();
    _subs
      ..add(
        _socketService!.listen<void>('gameAccessed').listen((_) {
          // success
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          final code = _controllers.map((c) => c.text).join();
          DebugLogger.log(
            'JoinGameCode: gameAccessed received, code=$code',
            tag: 'JoinGameCode',
          );

          try {
            GoRouter.of(context).go('/$code/choose-character');
          } on Exception catch (e) {
            DebugLogger.log(
              'JoinGameCode: failed to navigate to /$code/choose-character: $e',
              tag: 'JoinGameCode',
            );
          }
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } on Exception catch (e) {
            DebugLogger.log(
              'JoinGameCode: failed to pop dialog: $e',
              tag: 'JoinGameCode',
            );
          }
        }),
      )
      ..add(
        _socketService!.listen<String>('gameNotFound').listen((reason) {
          setState(() {
            _isLoading = false;
          });
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.info(message: 'Partie introuvable'),
          );
          _resetInputs();
        }),
      )
      ..add(
        _socketService!.listen<String>('gameLocked').listen((reason) {
          setState(() {
            _isLoading = false;
          });
          showTopSnackBar(
            Overlay.of(context),
            CustomSnackBar.error(message: 'Partie verrouillée: $reason'),
          );
          _resetInputs();
        }),
      );
  }

  void _resetInputs() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  SocketService? _socketService;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.length, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 48,
                height: 56,
                child: TextField(
                  enabled: !_isLoading,
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (v) {
                    if (_isLoading) return;
                    if (v.isEmpty) {
                      // user deleted; move focus to previous and clear it
                      if (i > 0) {
                        _focusNodes[i - 1].requestFocus();
                        _controllers[i - 1].clear();
                      }
                      return;
                    }

                    // Only keep first character (handle pastes)
                    final ch = v[0];
                    _controllers[i].text = ch;
                    _controllers[i].selection = const TextSelection.collapsed(
                      offset: 1,
                    );
                    if (i + 1 < widget.length) {
                      _focusNodes[i + 1].requestFocus();
                    } else {
                      final code = _controllers.map((c) => c.text).join();
                      // Emit accessGame event (lowercase) to server. Server expects
                      // the gameId as a plain string.
                      setState(() {
                        _isLoading = true;
                      });
                      _socketService?.send('accessGame', code);
                      // waiting for server to emit GameAccessed / GameNotFound / GameLocked
                    }
                  },
                ),
              );
            }),
          ),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color.fromRGBO(0, 0, 0, 0.35),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
