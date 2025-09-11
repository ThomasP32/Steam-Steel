import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/common/user.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/utils/debug_logger.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<User?> notifier = ValueNotifier(null);

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
    // Try to parse server message for better error reporting
    try {
      final body = jsonDecode(r.body);
      final msg =
          body is Map && body['message'] != null
              ? body['message']
              : 'Login failed ${r.statusCode}';
      throw Exception(msg.toString());
    } catch (_) {
      throw Exception('Login failed ${r.statusCode}');
    }
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
    // Try Authorization header first (standard), then fallback to query param for backward compatibility
    final headerUri = Uri.parse('${ApiClient.baseUrl}/api/auth/me');
    final headerResp = await _client.get(
      headerUri,
      headers: {'Authorization': 'Bearer $t'},
    );
    DebugLogger.log(
      'Auth.fetchUser headerResp status: ${headerResp.statusCode}',
      tag: 'AuthService',
    );
    DebugLogger.log(
      'Auth.fetchUser headerResp body: ${headerResp.body}',
      tag: 'AuthService',
    );
    if (headerResp.statusCode == 200) {
      try {
        final parsed = jsonDecode(headerResp.body);
        if (parsed is Map &&
            parsed['success'] == true &&
            parsed['user'] != null) {
          try {
            final userMap = Map<String, dynamic>.from(parsed['user'] as Map);
            notifier.value = User.fromJson(userMap);
            return;
          } catch (_) {
            // ignore and fallback
          }
        }
        // otherwise continue to fallback
      } catch (_) {
        // ignore and fallback
      }
    }

    // Fallback to query param
    final qpUri = Uri.parse('${ApiClient.baseUrl}/api/auth/me?token=$t');
    final qpResp = await _client.get(qpUri);
    DebugLogger.log(
      'Auth.fetchUser qpResp status: ${qpResp.statusCode}',
      tag: 'AuthService',
    );
    DebugLogger.log(
      'Auth.fetchUser qpResp body: ${qpResp.body}',
      tag: 'AuthService',
    );
    if (qpResp.statusCode == 200) {
      try {
        final parsed = jsonDecode(qpResp.body);
        if (parsed is Map &&
            parsed['success'] == true &&
            parsed['user'] != null) {
          try {
            final userMap = Map<String, dynamic>.from(parsed['user'] as Map);
            notifier.value = User.fromJson(userMap);
            return;
          } catch (_) {
            // ignore
          }
        }
      } catch (_) {
        // ignore
      }
    }

    // if token invalid or not accepted, clear it
    await logout();
    // Try to surface a meaningful message from server
    try {
      final body = jsonDecode(qpResp.body);
      final msg =
          body is Map && body['message'] != null
              ? body['message']
              : 'Fetch user failed';
      throw Exception(msg.toString());
    } catch (_) {
      throw Exception('Fetch user failed');
    }
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
