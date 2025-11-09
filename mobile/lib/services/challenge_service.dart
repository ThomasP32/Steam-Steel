import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/common/challenge.dart';
import 'package:mobile/common/events/challenge_events.dart';
import 'package:mobile/services/socket_service.dart';

class ChallengeService {
  factory ChallengeService() => _instance;
  ChallengeService._internal();
  static final ChallengeService _instance = ChallengeService._internal();

  final ValueNotifier<PublicChallengeView?> challengeNotifier = ValueNotifier(
    null,
  );
  StreamSubscription<dynamic>? _challengeSubscription;

  void initialize() {
    _listenToChallengeEvents();
  }

  void _listenToChallengeEvents() {
    _challengeSubscription?.cancel();

    _challengeSubscription = SocketService()
        .listen<dynamic>(ChallengeEvent.updated.value)
        .listen((data) {
          if (data is Map<String, dynamic>) {
            final challenge = PublicChallengeView.fromJson(data);
            challengeNotifier.value = challenge;
          }
        });
  }

  void reset() {
    challengeNotifier.value = null;
    _challengeSubscription?.cancel();
  }

  void dispose() {
    _challengeSubscription?.cancel();
    challengeNotifier.dispose();
  }
}
