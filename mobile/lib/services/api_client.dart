import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/models/channel.dart';
import 'package:mobile/services/api_config.dart';
import 'package:mobile/services/auth_service.dart';

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
    final token = await AuthService().token;
    if (token == null) throw Exception('No auth token available');
    final uri = _buildUri('/api/map/user/visible?token=$token');
    final r = await _http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('API error ${r.statusCode}: ${r.body}');
  }

  Future<List<Channel>> getChannels() async {
    final uri = _buildUri('/api/channels');
    final r = await _http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode == 200) {
      final responseBody = jsonDecode(r.body) as Map<String, dynamic>;
      final data = responseBody['channels'] as List<dynamic>;
      return data
          .map((json) => Channel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('API error ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> createChannel(
    String name,
    String creator,
  ) async {
    final token = await AuthService().token;
    final uri = _buildUri('/api/channels?token=$token');
    final r = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'creator': creator, 'isPublic': true}),
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${r.statusCode}: ${r.body}');
  }

  Future<Map<String, dynamic>> deleteChannel(String name) async {
    final token = await AuthService().token;
    final uri = _buildUri('/api/channels/$name?token=$token');
    final r = await _http.delete(uri);
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${r.statusCode}: ${r.body}');
  }

  void dispose() => _http.close();
}
