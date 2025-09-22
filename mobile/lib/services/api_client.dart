import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/services/api_config.dart';

class ApiClient {
  static String get baseUrl {
    return ApiConfig.baseUrl;
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
