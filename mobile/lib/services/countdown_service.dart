import 'dart:async';

import 'package:mobile/services/socket_service.dart';

class CountdownService {
  factory CountdownService() => _instance;
  CountdownService._privateConstructor();
  static final CountdownService _instance =
      CountdownService._privateConstructor();

  final SocketService _socketService = SocketService();
  final StreamController<dynamic> _countdownController =
      StreamController<dynamic>.broadcast();

  Stream<dynamic> get countdownStream => _countdownController.stream;
  dynamic _currentCountdown = 30;

  dynamic get currentCountdown => _currentCountdown;

  StreamSubscription<int>? _secondPassedSub;
  StreamSubscription<dynamic>? _combatStartedSub;

  void initialize() {
    _secondPassedSub = _socketService.listen<int>('secondPassed').listen((
      data,
    ) {
      _currentCountdown = data;
      _countdownController.add(data);
    });

    _combatStartedSub = _socketService
        .listen<dynamic>('combatStartedSignal')
        .listen((_) {
          _currentCountdown = '--';
          _countdownController.add('--');
        });
  }

  void dispose() {
    _secondPassedSub?.cancel();
    _combatStartedSub?.cancel();
    _countdownController.close();
  }
}
