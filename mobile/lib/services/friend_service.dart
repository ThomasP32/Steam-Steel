import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/common/user.dart';
import 'package:mobile/models/user_models.dart' hide User;
import 'package:mobile/services/api_config.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/socket_service.dart';
import 'package:mobile/utils/debug_logger.dart';

class FriendService {
  factory FriendService() => _instance;
  FriendService._() {
    _initializeSocket();
  }
  static final FriendService _instance = FriendService._();

  final _socketService = SocketService();

  List<Friend> _cachedFriends = [];
  List<FriendRequest> _cachedRequests = [];
  List<User> _cachedAllUsers = [];

  Future<Map<String, String>> get _headers async {
    final token = await AuthService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  final List<void Function(Friend)> _onFriendAddedListeners = [];
  final List<void Function(String)> _onFriendRemovedListeners = [];
  final List<void Function(FriendRequest)> _onFriendRequestReceivedListeners =
      [];
  final List<void Function(Friend)> _onFriendRequestAcceptedListeners = [];
  final List<void Function(String)> _onFriendRequestRejectedListeners = [];
  final List<void Function(List<Friend>)> _onFriendListUpdatedListeners = [];
  final List<void Function(List<FriendRequest>)>
  _onFriendRequestsListUpdatedListeners = [];
  final List<void Function(String, UserStatus)> _onFriendStatusUpdateListeners =
      [];
  final List<void Function(List<User>)> _onAllUsersUpdatedListeners = [];

  void addOnFriendAddedListener(void Function(Friend) listener) {
    if (_onFriendAddedListeners.isEmpty) {
      _initializeSocket();
    }
    _onFriendAddedListeners.add(listener);
  }

  void removeOnFriendAddedListener(void Function(Friend) listener) {
    _onFriendAddedListeners.remove(listener);
  }

  void addOnFriendRemovedListener(void Function(String) listener) {
    _onFriendRemovedListeners.add(listener);
  }

  void removeOnFriendRemovedListener(void Function(String) listener) {
    _onFriendRemovedListeners.remove(listener);
  }

  void addOnFriendRequestReceivedListener(
    void Function(FriendRequest) listener,
  ) {
    _onFriendRequestReceivedListeners.add(listener);
  }

  void removeOnFriendRequestReceivedListener(
    void Function(FriendRequest) listener,
  ) {
    _onFriendRequestReceivedListeners.remove(listener);
  }

  void addOnFriendRequestAcceptedListener(void Function(Friend) listener) {
    _onFriendRequestAcceptedListeners.add(listener);
  }

  void removeOnFriendRequestAcceptedListener(void Function(Friend) listener) {
    _onFriendRequestAcceptedListeners.remove(listener);
  }

  void addOnFriendRequestRejectedListener(void Function(String) listener) {
    _onFriendRequestRejectedListeners.add(listener);
  }

  void removeOnFriendRequestRejectedListener(void Function(String) listener) {
    _onFriendRequestRejectedListeners.remove(listener);
  }

  void addOnFriendListUpdatedListener(void Function(List<Friend>) listener) {
    _onFriendListUpdatedListeners.add(listener);
  }

  void removeOnFriendListUpdatedListener(void Function(List<Friend>) listener) {
    _onFriendListUpdatedListeners.remove(listener);
  }

  void addOnFriendRequestsListUpdatedListener(
    void Function(List<FriendRequest>) listener,
  ) {
    _onFriendRequestsListUpdatedListeners.add(listener);
  }

  void removeOnFriendRequestsListUpdatedListener(
    void Function(List<FriendRequest>) listener,
  ) {
    _onFriendRequestsListUpdatedListeners.remove(listener);
  }

  void addOnFriendStatusUpdateListener(
    void Function(String, UserStatus) listener,
  ) {
    _onFriendStatusUpdateListeners.add(listener);
  }

  void removeOnFriendStatusUpdateListener(
    void Function(String, UserStatus) listener,
  ) {
    _onFriendStatusUpdateListeners.remove(listener);
  }

  void addOnAllUsersUpdatedListener(void Function(List<User>) listener) {
    _onAllUsersUpdatedListeners.add(listener);
  }

  void removeOnAllUsersUpdatedListener(void Function(List<User>) listener) {
    _onAllUsersUpdatedListeners.remove(listener);
  }

  Future<void> _initializeSocket() async {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService
        .listen<Map<String, dynamic>>('friendStatusUpdate')
        .listen(_handleFriendStatusUpdate);
    _socketService
        .listen<Map<String, dynamic>>('friendAdded')
        .listen(_handleFriendAdded);
    _socketService
        .listen<Map<String, dynamic>>('friendRemoved')
        .listen(_handleFriendRemoved);
    _socketService
        .listen<Map<String, dynamic>>('friendRequestReceived')
        .listen(_handleFriendRequestReceived);
    _socketService
        .listen<Map<String, dynamic>>('friendRequestAccepted')
        .listen(_handleFriendRequestAccepted);
    _socketService
        .listen<Map<String, dynamic>>('friendRequestRejected')
        .listen(_handleFriendRequestRejected);
    _socketService
        .listen<Map<String, dynamic>>('friendListUpdated')
        .listen(_handleFriendListUpdated);
    _socketService
        .listen<Map<String, dynamic>>('friendRequestsUpdated')
        .listen(_handleFriendRequestsUpdated);
  }

  void _handleFriendStatusUpdate(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final username = data['username'] as String?;
    final statusStr = data['status'] as String?;
    if (username != null && statusStr != null) {
      final status = _parseStatus(statusStr);
      DebugLogger.log(
        'Status mis à jour pour $username: $statusStr',
        tag: 'FriendService',
      );

      for (final listener in _onFriendStatusUpdateListeners) {
        listener(username, status);
      }
    }
  }

  UserStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return UserStatus.online;
      case 'offline':
        return UserStatus.offline;
      case 'ingame':
        return UserStatus.inGame;
      default:
        return UserStatus.unknown;
    }
  }

  void _handleFriendAdded(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    try {
      final friend = Friend.fromJson(data);

      if (!_cachedFriends.any((f) => f.username == friend.username)) {
        _cachedFriends.add(friend);
      }

      for (final listener in _onFriendAddedListeners) {
        listener(friend);
      }
    } catch (_) {
      // Silently fail
    }
  }

  void _handleFriendRemoved(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final username = data['username'] as String?;
    if (username != null) {
      _cachedFriends.removeWhere((friend) => friend.username == username);

      for (final listener in _onFriendRemovedListeners) {
        listener(username);
      }
    }
  }

  void _handleFriendRequestReceived(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    try {
      final request = FriendRequest.fromJson(data);
      for (final listener in _onFriendRequestReceivedListeners) {
        listener(request);
      }
    } catch (e) {
      DebugLogger.log(
        'Erreur lors du traitement de friendRequestReceived: $e',
        tag: 'FriendService',
      );
    }
  }

  void _handleFriendRequestAccepted(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    try {
      final friend = Friend.fromJson(data);
      for (final listener in _onFriendRequestAcceptedListeners) {
        listener(friend);
      }
    } catch (e) {
      DebugLogger.log(
        'Erreur lors du traitement de friendRequestAccepted: $e',
        tag: 'FriendService',
      );
    }
  }

  void _handleFriendRequestRejected(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final username = data['username'] as String?;
    if (username != null) {
      for (final listener in _onFriendRequestRejectedListeners) {
        listener(username);
      }
    }
  }

  void _handleFriendListUpdated(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    try {
      final friendsList = data['friends'] as List?;
      if (friendsList != null) {
        final friends =
            friendsList
                .whereType<Map<String, dynamic>>()
                .map(Friend.fromJson)
                .toList();

        _cachedFriends = friends;

        getAllUsers()
            .then((users) {
              for (final listener in _onAllUsersUpdatedListeners) {
                listener(users);
              }
            })
            .catchError((e) {
              DebugLogger.log(
                'Erreur lors du rechargement des utilisateurs: $e',
                tag: 'FriendService',
              );
            });

        for (final listener in _onFriendListUpdatedListeners) {
          listener(friends);
        }
      }
    } catch (e) {
      DebugLogger.log(
        'Erreur lors du traitement de friendListUpdated: $e',
        tag: 'FriendService',
      );
    }
  }

  void _handleFriendRequestsUpdated(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    try {
      final requestsList = data['friendRequests'] as List?;
      if (requestsList != null) {
        final requests =
            requestsList
                .whereType<Map<String, dynamic>>()
                .map(FriendRequest.fromJson)
                .toList();

        _cachedRequests = requests;

        getAllUsers()
            .then((users) {
              for (final listener in _onAllUsersUpdatedListeners) {
                listener(users);
              }
            })
            .catchError((e) {
              DebugLogger.log(
                'Erreur lors du rechargement des utilisateurs: $e',
                tag: 'FriendService',
              );
            });

        for (final listener in _onFriendRequestsListUpdatedListeners) {
          listener(requests);
        }
      }
    } catch (e) {
      DebugLogger.log(
        'Erreur lors du traitement de friendRequestsUpdated: $e',
        tag: 'FriendService',
      );
    }
  }

  Future<Map<String, dynamic>> _processResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
  }

  Uri _buildUri(String path) {
    final base =
        ApiConfig.baseUrl.endsWith('/')
            ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
            : ApiConfig.baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  Future<List<Friend>> getFriends() async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final response = await http.get(_buildUri('/api/friends/$token'));

      final data = await _processResponse(response);

      if (data['success'] as bool && data['friends'] != null) {
        return _cachedFriends =
            (data['friends'] as List)
                .map(
                  (friend) => Friend.fromJson(friend as Map<String, dynamic>),
                )
                .toList();
      }
      return _cachedFriends;
    } catch (e) {
      if (_cachedFriends.isNotEmpty) return _cachedFriends;
      throw Exception('Erreur lors du chargement des amis: $e');
    }
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final response = await http.get(
        _buildUri('/api/friends/requests/$token'),
      );

      final data = await _processResponse(response);

      if (data['success'] as bool && data['friendRequests'] != null) {
        return _cachedRequests =
            (data['friendRequests'] as List)
                .map(
                  (request) =>
                      FriendRequest.fromJson(request as Map<String, dynamic>),
                )
                .toList();
      }
      return _cachedRequests;
    } catch (e) {
      if (_cachedRequests.isNotEmpty) return _cachedRequests;
      throw Exception("Erreur lors du chargement des demandes d'ami: $e");
    }
  }

  Future<bool> addFriend(String username) async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final headers = await _headers;
      final response = await http.post(
        _buildUri('/api/friends/add'),
        headers: headers,
        body: json.encode({'username': username, 'token': token}),
      );

      final data = await _processResponse(response);
      return (data['success'] as bool?) ?? false;
    } catch (e) {
      throw Exception("Erreur lors de l'ajout d'ami: $e");
    }
  }

  Future<bool> acceptFriendRequest(String username) async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final headers = await _headers;
      final response = await http.post(
        _buildUri('/api/friends/accept/$username'),
        headers: headers,
        body: json.encode({'token': token}),
      );

      final data = await _processResponse(response);
      return (data['success'] as bool?) ?? false;
    } catch (e) {
      throw Exception("Erreur lors de l'acceptation de la demande: $e");
    }
  }

  Future<bool> rejectFriendRequest(String username) async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final headers = await _headers;
      final response = await http.post(
        _buildUri('/api/friends/reject/$username'),
        headers: headers,
        body: json.encode({'token': token}),
      );

      final data = await _processResponse(response);
      return (data['success'] as bool?) ?? false;
    } catch (e) {
      throw Exception('Erreur lors du refus de la demande: $e');
    }
  }

  Future<bool> removeFriend(String username) async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final headers = await _headers;
      final response = await http.delete(
        _buildUri('/api/friends/remove/$username'),
        headers: headers,
        body: json.encode({'token': token}),
      );

      final data = await _processResponse(response);
      return (data['success'] as bool?) ?? false;
    } catch (e) {
      throw Exception("Erreur lors de la suppression de l'ami: $e");
    }
  }

  Future<List<User>> getAllUsers({bool forceRefresh = false}) async {
    try {
      final token = await AuthService().token;
      if (token == null) throw Exception('Non authentifié');

      final headers = await _headers;
      final response = await http.get(
        _buildUri('/api/auth/users/search?q='),
        headers: headers,
      );

      final data = await _processResponse(response);

      if (data['success'] as bool && data['users'] != null) {
        return _cachedAllUsers =
            (data['users'] as List).map((user) {
              final userMap = user as Map<String, dynamic>;
              final level =
                  (userMap['level'] is int)
                      ? userMap['level'] as int
                      : int.tryParse('${userMap['level']}') ?? 1;

              return User(
                id: '',
                username: userMap['username'] as String,
                email: '',
                stats: UserStats(
                  classique: const GameStats(gamesPlayed: 0, gamesWon: 0),
                  ctf: const GameStats(gamesPlayed: 0, gamesWon: 0),
                  avgTime: 0,
                  level: level,
                ),
              );
            }).toList();
      }
      return _cachedAllUsers;
    } catch (e) {
      if (_cachedAllUsers.isNotEmpty) return _cachedAllUsers;
      throw Exception('Erreur lors du chargement des utilisateurs: $e');
    }
  }

  void updateUserStatus(UserStatus status) {
    try {
      final statusString =
          status == UserStatus.online
              ? 'online'
              : status == UserStatus.offline
              ? 'offline'
              : 'ingame';

      _socketService.send('updateUserStatus', {'status': statusString});

      final currentUser = AuthService().notifier.value;
      if (currentUser != null) {
        AuthService().notifier.value = currentUser.copyWith(
          status: statusString,
        );
      }

      DebugLogger.log(
        'Updated user status to: $statusString',
        tag: 'FriendService',
      );
    } catch (e) {
      DebugLogger.log('Error updating user status: $e', tag: 'FriendService');
    }
  }

  void inviteAllOnlineFriends(String gameId, String gameName) {
    try {
      if (_socketService.socketId == null) {
        return;
      }

      final payload = {'gameId': gameId, 'gameName': gameName};

      _socketService.send('inviteAllOnlineFriends', payload);
    } catch (e) {
      DebugLogger.log('Error inviting friends: $e', tag: 'FriendService');
    }
  }

  void acceptGameInvitation(String gameId, String inviterUsername) {
    try {
      final payload = {'gameId': gameId, 'inviterUsername': inviterUsername};
      _socketService.send('gameInvitationAccepted', payload);
    } catch (e) {
      DebugLogger.log('Error accepting invitation: $e', tag: 'FriendService');
    }
  }

  void rejectGameInvitation(String gameId, String inviterUsername) {
    try {
      final payload = {'gameId': gameId, 'inviterUsername': inviterUsername};
      _socketService.send('gameInvitationRejected', payload);
    } catch (e) {
      DebugLogger.log('Error rejecting invitation: $e', tag: 'FriendService');
    }
  }

  List<Friend> getOnlineFriends() {
    return _cachedFriends
        .where(
          (friend) =>
              friend.status == UserStatus.online ||
              friend.status == UserStatus.inGame,
        )
        .toList();
  }

  List<Friend> getCachedFriends() {
    return List.from(_cachedFriends);
  }

  void dispose() {}
}
