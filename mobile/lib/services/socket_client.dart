import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile/utils/debug_logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketClient {
  String get baseUrl {
    final envValue = dotenv.env['API_URL'];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    const defineValue = String.fromEnvironment('API_URL');
    if (defineValue.isNotEmpty) return defineValue;
    return 'http://10.0.2.2:3000';
  }

  io.Socket? socket;

  void connect({String namespace = '/game'}) {
    final ns = namespace.startsWith('/') ? namespace : '/$namespace';
    final base =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final uri = '$base$ns';
    socket = io.io(uri, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.on(
      'connect',
      (_) => DebugLogger.log('connected to $uri', tag: 'SocketClient'),
    );
    socket!.on(
      'disconnect',
      (_) => DebugLogger.log('socket disconnected', tag: 'SocketClient'),
    );
    socket!.on(
      'gameEvent',
      (d) => DebugLogger.log('gameEvent: $d', tag: 'SocketClient'),
    );
    socket!.connect();
  }

  void disconnect() => socket?.disconnect();
}
