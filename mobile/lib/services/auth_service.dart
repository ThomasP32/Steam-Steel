import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/common/game.dart';
import 'package:mobile/common/user.dart';
import 'package:mobile/models/user_models.dart' show UserStatus;
import 'package:mobile/services/api_client.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class AuthService {
  factory AuthService() => _instance;
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<User?> notifier = ValueNotifier(null);

  static const _tokenKey = 'authToken';

  Future<String?> get token async => _storage.read(key: _tokenKey);

  final http.Client _client = http.Client();

  Future<void> login(String username, String password) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/login');
    final r = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

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
        // Connect socket after successful login so socket handshake includes token
        try {
          await SocketService().connect();
          // join global chat room by default
          SocketService().send('joinChatRoom', 'global');

          FriendService().updateUserStatus(UserStatus.online);
        } on Object catch (e) {
          DebugLogger.log(
            'SocketService.connect after login failed: $e',
            tag: 'AuthService',
          );
        }
        return;
      }
    }
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['message'] != null) {
        throw Exception(body['message'].toString());
      }
      // some server errors may include an error object
      if (body is Map && body['error'] != null) {
        final err = body['error'];
        if (err is Map && err['message'] != null) {
          throw Exception(err['message'].toString());
        }
        throw Exception(err.toString());
      }
      // If it's a different shape but a string exists, use it
      if (body is String && body.isNotEmpty) {
        throw Exception(body);
      }
    } on FormatException catch (_) {
      // Not JSON — surface raw body if available
      final raw = r.body;
      if (raw.isNotEmpty) throw Exception(raw);
    } on Exception {
      rethrow;
    }

    throw Exception('Login failed ${r.statusCode}');
  }

  Future<void> register(
    String email,
    String password,
    String username,
    ProfilePicture profilePicture,
    String? profilePictureCustom,
  ) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/register');
    final profilePicturePayload = profilePicture.value;

    var profilePictureCustomPayload = profilePictureCustom;
    try {
      if (profilePictureCustom != null && profilePictureCustom.isNotEmpty) {
        final f = File(profilePictureCustom);
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          final b64 = base64Encode(bytes);
          profilePictureCustomPayload = 'data:image/png;base64,$b64';
        }
      }
    } on Object catch (e) {
      DebugLogger.log(
        'Register profilePictureCustom conversion failed: $e',
        tag: 'AuthService',
      );
      profilePictureCustomPayload = profilePictureCustom;
    }

    final r = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'profilePicture': profilePicturePayload,
        'profilePictureCustom': profilePictureCustomPayload,
      }),
    );
    DebugLogger.log(
      'Auth.register response status: ${r.statusCode}',
      tag: 'AuthService',
    );
    DebugLogger.log(
      'Auth.register response body: ${r.body}',
      tag: 'AuthService',
    );
    if (r.statusCode == 200 || r.statusCode == 201) return;

    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['message'] != null) {
        throw Exception(body['message'].toString());
      }
      if (body is Map && body['error'] != null) {
        final err = body['error'];
        if (err is Map && err['message'] != null) {
          throw Exception(err['message'].toString());
        }
        throw Exception(err.toString());
      }
      if (body is String && body.isNotEmpty) {
        throw Exception(body);
      }
    } on FormatException catch (_) {
      final raw = r.body;
      if (raw.isNotEmpty) throw Exception(raw);
    } on Exception {
      rethrow;
    }

    throw Exception('Register failed ${r.statusCode}');
  }

  Future<void> fetchUser() async {
    final t = await token;
    DebugLogger.log('Fetch user with token: $t', tag: 'AuthService');
    if (t == null) return notifier.value = null;
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
          } on Exception catch (_) {}
        }
      } on Exception catch (_) {}
    }

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
          } on Exception catch (_) {}
        }
      } on Exception catch (_) {}
    }

    await logout();
    try {
      final body = jsonDecode(qpResp.body);
      final msg =
          body is Map && body['message'] != null
              ? body['message']
              : 'Fetch user failed';
      throw Exception(msg.toString());
    } on Exception catch (_) {
      throw Exception('Fetch user failed');
    }
  }

  Future<void> logout() async {
    final t = await token;
    if (t != null) {
      try {
        final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/logout?token=$t');
        final r = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        );
        DebugLogger.log(
          'Auth.logout response status: ${r.statusCode}',
          tag: 'AuthService',
        );
        DebugLogger.log(
          'Auth.logout response body: ${r.body}',
          tag: 'AuthService',
        );
      } on Object catch (e) {
        DebugLogger.log('Auth.logout request failed: $e', tag: 'AuthService');
      }
    }
    try {
      SocketService().disconnect();
    } on Object catch (_) {}
    try {
      FriendService().updateUserStatus(UserStatus.offline);
    } catch (_) {}
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

  Future<void> updateAccount({
    required String username,
    required String email,
    ProfilePicture? profilePicture,
    String? profilePictureCustom,
  }) async {
    final t = await token;
    if (t == null) throw Exception('Not authenticated');
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/update');

    var profilePictureCustomPayload = profilePictureCustom;
    try {
      if (profilePictureCustom != null &&
          profilePictureCustom.isNotEmpty &&
          !profilePictureCustom.startsWith('data:') &&
          !profilePictureCustom.startsWith('http')) {
        final f = File(profilePictureCustom);
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          final b64 = base64Encode(bytes);
          profilePictureCustomPayload = 'data:image/png;base64,$b64';
        }
      }
    } on Object catch (e) {
      DebugLogger.log(
        'Update profilePictureCustom conversion failed: $e',
        tag: 'AuthService',
      );
      profilePictureCustomPayload = profilePictureCustom;
    }

    final body = <String, dynamic>{'username': username, 'email': email};

    if (profilePicture != null) {
      body['profilePicture'] = profilePicture.value;
    }

    body['profilePictureCustom'] = profilePictureCustomPayload;

    final r = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
      body: jsonEncode(body),
    );

    if (r.statusCode == 200) {
      final responseBody = jsonDecode(r.body);
      if (responseBody is Map) {
        if (responseBody['success'] == false) {
          final message =
              responseBody['message']?.toString() ?? 'Update failed';
          throw Exception(message);
        }
      }

      await fetchUser();
      return;
    }

    try {
      final responseBody = jsonDecode(r.body);
      if (responseBody is Map && responseBody['message'] != null) {
        throw Exception(responseBody['message'].toString());
      }
    } on Exception {
      if (r.body.isNotEmpty) throw Exception(r.body);
    }
    throw Exception('Update failed ${r.statusCode}');
  }

  Future<void> updateStats({
    required String mode,
    required bool isWin,
    required int duration,
  }) async {
    final t = await token;
    if (t == null) {
      DebugLogger.log(
        'No auth token, skipping stats update',
        tag: 'AuthService',
      );
      return;
    }

    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/stats?token=$t');
    try {
      final r = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode, 'isWin': isWin, 'duration': duration}),
      );

      DebugLogger.log(
        'Auth.updateStats response status: ${r.statusCode}',
        tag: 'AuthService',
      );

      if (r.statusCode == 200) {
        DebugLogger.log('Stats updated successfully', tag: 'AuthService');
        return;
      }

      DebugLogger.log(
        'Stats update failed: ${r.statusCode} - ${r.body}',
        tag: 'AuthService',
      );
    } on Object catch (e) {
      DebugLogger.log('Stats update request failed: $e', tag: 'AuthService');
    }
  }
}
