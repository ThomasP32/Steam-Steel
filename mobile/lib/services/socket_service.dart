import 'dart:async';

import 'package:mobile/services/socket_client.dart';
import 'package:mobile/utils/debug_logger.dart';

class SocketService {
  factory SocketService() => _instance;
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();

  final SocketClient _client = SocketClient();
  final Map<String, StreamController<dynamic>> _controllers = {};

  Future<void> connect() async {
    await _client.connect();
    final socket = _client.socket;

    if (socket == null) return;

    socket.onAny((dynamic a, [dynamic b]) {
      String? eventName;
      dynamic eventData;
      if (b != null) {
        eventName = a?.toString();
        eventData = b;
      } else {
        if (a is List && a.isNotEmpty) {
          eventName = a[0]?.toString();
          if (a.length > 1) eventData = a[1];
        } else if (a is Map<String, dynamic>) {
          eventName = a['event']?.toString();
          eventData = a['data'];
        } else if (a is String) {
          eventName = a;
        } else {
          eventName = a?.toString();
        }
      }
      if (eventName == null) return;
      DebugLogger.log(
        'socket event: $eventName -> $eventData',
        tag: 'SocketService',
      );
      final ctrl = _controllers[eventName];
      ctrl?.add(eventData);
    });
  }

  void disconnect() => _client.disconnect();

  String? get socketId => _client.socket?.id;

  void send(String event, [dynamic data]) {
    final socket = _client.socket;
    DebugLogger.log(
      'SocketService.send: $event -> $data',
      tag: 'SocketService',
    );
    if (socket == null) {
      DebugLogger.log(
        'SocketService.send: socket is null, cannot emit',
        tag: 'SocketService',
      );
      return;
    }
    socket.emit(event, data);
  }

  Stream<T> listen<T>(String event) {
    if (!_controllers.containsKey(event)) {
      _controllers[event] = StreamController<T>.broadcast();
    }
    return _controllers[event]!.stream as Stream<T>;
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    disconnect();
  }
}
