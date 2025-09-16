import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile/services/auth_service.dart';
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

  Future<void> connect({String namespace = '/game'}) async {
    final ns = namespace.startsWith('/') ? namespace : '/$namespace';
    final base =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final uri = '$base$ns';
    final token = await AuthService().token;
    DebugLogger.log(
      'SocketClient.connect using token: ${token == null ? 'null' : '${token.substring(0, 8)}...'}',
      tag: 'SocketClient',
    );
    final opts = <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    };
    if (token != null) {
      opts['auth'] = {'token': token};
    }
    socket = io.io(uri, opts);
    socket!.on(
      'connect',
      (_) => DebugLogger.log(
        'connected to $uri, SocketId = ${socket?.id} ',
        tag: 'SocketClient',
      ),
    );
    socket!.on(
      'disconnect',
      (_) => DebugLogger.log(
        'socket disconnected, SocketId = ${socket?.id}',
        tag: 'SocketClient',
      ),
    );
    socket!.on(
      'gameEvent',
      (d) => DebugLogger.log('gameEvent: $d', tag: 'SocketClient'),
    );
    socket!.connect();
  }

  void disconnect() => socket?.disconnect();
}
