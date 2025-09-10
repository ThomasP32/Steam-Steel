import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/debug_logger.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<Map<String, dynamic>?> notifier = ValueNotifier(null);

  static const _tokenKey = 'authToken';

  Future<String?> get token async => await _storage.read(key: _tokenKey);

  final http.Client _client = http.Client();

  Future<void> login(String email, String password) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/login');
    final r = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    DebugLogger.log(
      'Auth.login response status: ${r.statusCode}',
      tag: 'AuthService',
    );
    DebugLogger.log('Auth.login response body: ${r.body}', tag: 'AuthService');
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final t = body['token'] as String?;
      if (t != null) {
        await _storage.write(key: _tokenKey, value: t);
        DebugLogger.log(
          'Auth.login stored token: ${t.substring(0, 8)}...',
          tag: 'AuthService',
        );
        await fetchUser();
        return;
      }
    }
    throw Exception('Login failed ${r.statusCode}');
  }

  Future<void> register(
    String email,
    String password,
    String username,
    String avatar,
  ) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/register');
    final r = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'avatar': avatar,
      }),
    );
    if (r.statusCode == 200 || r.statusCode == 201) return;
    throw Exception('Register failed ${r.statusCode}');
  }

  Future<void> fetchUser() async {
    final t = await token;
    DebugLogger.log('Fetch user with token: $t', tag: 'AuthService');
    if (t == null) return notifier.value = null;
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/me?token=$t');
    final r = await _client.get(uri);
    if (r.statusCode == 200) {
      notifier.value = jsonDecode(r.body) as Map<String, dynamic>;
      return;
    }
    // if token invalid, clear it
    await logout();
    throw Exception('Fetch user failed ${r.statusCode}');
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    notifier.value = null;
  }

  Future<void> deleteAccount() async {
    final t = await token;
    if (t == null) throw Exception('Not authenticated');
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/delete?token=$t');
    final r = await _client.delete(uri);
    if (r.statusCode == 200) {
      await logout();
      return;
    }
    throw Exception('Delete failed ${r.statusCode}');
  }
}
