import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  // Resolve API URL with precedence: dotenv -> dart-define -> emulator fallback
  static String get baseUrl {
    final envValue = dotenv.env['API_URL'];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    const defineValue = String.fromEnvironment('API_URL');
    if (defineValue.isNotEmpty) return defineValue;
    return 'http://10.0.2.2:3000';
  }

  final http.Client _http = http.Client();

  Uri _buildUri(String path) {
    final base =
        baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<List<dynamic>> getMaps() async {
    final uri = _buildUri('/api/map');
    final r = await _http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('API error ${r.statusCode}: ${r.body}');
  }

  void dispose() => _http.close();
}
