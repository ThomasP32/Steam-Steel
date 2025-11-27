import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/common/events/friends_events.dart';
import 'package:mobile/common/events/game_creation_events.dart';
import 'package:mobile/router/app_router.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/widgets/game/game_invitation_modal_widget.dart';

class GameInvitationListener extends StatefulWidget {
  const GameInvitationListener({required this.child, super.key});

  final Widget child;

  @override
  State<GameInvitationListener> createState() => _GameInvitationListenerState();
}

class _GameInvitationListenerState extends State<GameInvitationListener> {
  StreamSubscription<dynamic>? _invitationSub;
  StreamSubscription<dynamic>? _gameAccessedSub;
  GameInvitation? _currentInvitation;
  int _userMoney = 0;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _invitationSub = SocketService()
        .listen<dynamic>(FriendsEvents.gameInvitationReceived)
        .listen(_handleInvitationReceived);

    _gameAccessedSub = SocketService()
        .listen<dynamic>(GameCreationEvents.gameAccessed)
        .listen(_handleGameAccessed);
  }

  void _handleInvitationReceived(dynamic data) {
    if (!mounted) {
      return;
    }

    if (data is Map<String, dynamic>) {
      final invitation = GameInvitation.fromJson(data);
      final user = AuthService().notifier.value;
      setState(() {
        _currentInvitation = invitation;
        _userMoney = user?.virtualMoney ?? 0;
      });
    }
  }

  void _handleGameAccessed(dynamic data) {
    if (!mounted) return;

    String? gameId;
    if (data is String) {
      gameId = data;
    } else if (data is int) {
      gameId = data.toString();
    } else if (data is Map) {
      final gameIdValue = data['gameId'];
      gameId =
          gameIdValue is int ? gameIdValue.toString() : gameIdValue as String?;
    }

    if ((gameId == null || gameId.isEmpty) && _currentInvitation != null) {
      gameId = _currentInvitation!.gameId;
    }

    if (gameId != null && gameId.isNotEmpty && _currentInvitation != null) {
      setState(() {
        _currentInvitation = null;
      });
      AppRouter.router.go('/$gameId/choose-character');
    }
  }

  void _onAccept() {
    if (_currentInvitation == null) return;

    final gameId = _currentInvitation!.gameId;
    final inviterUsername = _currentInvitation!.inviterUsername;

    FriendService().acceptGameInvitation(gameId, inviterUsername);

    Future.delayed(const Duration(milliseconds: 100), () {
      SocketService().send(GameCreationEvents.accessGame, gameId);
    });
  }

  void _onReject() {
    if (_currentInvitation == null) return;

    FriendService().rejectGameInvitation(
      _currentInvitation!.gameId,
      _currentInvitation!.inviterUsername,
    );

    setState(() {
      _currentInvitation = null;
    });
  }

  void _onClose() {
    setState(() {
      _currentInvitation = null;
    });
  }

  @override
  void dispose() {
    _invitationSub?.cancel();
    _gameAccessedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentInvitation != null)
          GameInvitationModalWidget(
            invitation: _currentInvitation!,
            userMoney: _userMoney,
            onAccept: _onAccept,
            onReject: _onReject,
            onClose: _onClose,
          ),
      ],
    );
  }
}
