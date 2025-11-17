import 'dart:async';

import 'package:mobile/services/socket_client.dart';
import 'package:mobile/utils/debug_logger.dart';

class SocketService {
  Future<T> emitWithAck<T>(String event, [dynamic data]) {
    final completer = Completer<T>();
    final socket = _client.socket;

    if (socket == null) {
      completer.completeError(Exception('Socket not connected'));
      return completer.future;
    }

    socket.emitWithAck(
      event,
      data,
      ack: (dynamic response) {
        try {
          completer.complete(response as T);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

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
    // { changed code }
    // Previously this code may have returned something like `return _controllers[event]!.stream as Stream<T>;`
    // which caused a runtime cast of the Stream object and produced the `_BroadcastStream<dynamic>` error.
    // Instead, map elements to T so the Stream object stays a Stream<dynamic> internally.
    final controller = _controllers.putIfAbsent(
      event,
      StreamController<dynamic>.broadcast,
    );
    return controller.stream.map<T>((dynamic e) {
      // perform a checked cast at element level; if it fails it will throw at the moment of use,
      // but avoids casting the Stream object itself which produced the original runtime error.
      return e as T;
    });
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    disconnect();
  }
}
