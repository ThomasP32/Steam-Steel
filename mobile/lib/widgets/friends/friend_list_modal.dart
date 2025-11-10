import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/models/user_models.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/friend_service.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class FriendListModal extends StatefulWidget {
  const FriendListModal({super.key});

  @override
  State<FriendListModal> createState() => _FriendListModalState();
}

class _FriendListModalState extends State<FriendListModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FriendService _friendService = FriendService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _searchQuery = '';
  bool _isLoading = false;
  bool _isAddingFriend = false;
  bool _isFriendsSectionExpanded = true;
  bool _isOtherUsersSectionExpanded = true;
  Set<String> _sentRequests = {};
  Map<String, DateTime> _recentlySentRequests = {};

  List<Friend> _friends = [];
  List<FriendRequest> _friendRequests = [];
  List<User> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _setupEventListeners();
  }

  Future<void> _initializeData() async {
    await _loadSentRequests();
    await _cleanupOldTimestamps();
    await _loadAllUsers();
    await _loadFriends();
    await _loadFriendRequests();
  }

  Future<void> _cleanupOldTimestamps() async {
    final now = DateTime.now();
    var needsSave = false;

    _recentlySentRequests.removeWhere((username, timestamp) {
      if (now.difference(timestamp).inSeconds > 10) {
        needsSave = true;
        return true;
      }
      return false;
    });

    if (needsSave && mounted) {
      await _saveSentRequests();
    }
  }

  Future<void> _loadAllUsers({bool forceRefresh = false}) async {
    try {
      final users = await _friendService.getAllUsers(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() => _allUsers = users);
        print('Utilisateurs chargés: ${users.length}');
      }
    } catch (e) {
      if (mounted) {
        print('Erreur lors du chargement des utilisateurs: $e');
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors du chargement des utilisateurs',
          ),
        );
      }
    }
  }

  List<User> getFilteredOtherUsers() {
    final currentUsername = AuthService().notifier.value?.username;
    final nonFriends =
        _allUsers
            .where(
              (user) =>
                  user.username != currentUsername &&
                  !_friends.any((friend) => friend.username == user.username),
            )
            .toList();

    if (_searchQuery.isEmpty) return nonFriends;

    return nonFriends
        .where(
          (user) =>
              user.username.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<Friend> getFilteredFriends() {
    return _friends;
  }

  Future<void> _addFriend(String username) async {
    if (_isAddingFriend || _sentRequests.contains(username)) return;

    setState(() {
      _isAddingFriend = true;
    });

    try {
      await _loadAllUsers(forceRefresh: true);

      final userExists = _allUsers.any((user) => user.username == username);
      if (!userExists) {
        if (mounted) {
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(
              message: 'Utilisateur destinataire non trouvé',
            ),
          );
        }
        return;
      }

      await _friendService.addFriend(username);
      if (mounted) {
        setState(() {
          _sentRequests.add(username);
          _recentlySentRequests[username] = DateTime.now();
        });
        await _saveSentRequests();
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.success(message: 'Demande d\'ami envoyée à $username'),
        );
      }
    } catch (e) {
      if (e.toString().contains('201')) {
        if (mounted) {
          setState(() {
            _sentRequests.add(username);
            _recentlySentRequests[username] = DateTime.now();
          });
          await _saveSentRequests();
          showTopSnackBar(
            Overlay.of(context),
            CustomSnackBar.success(
              message: 'Demande d\'ami envoyée à $username',
            ),
          );
        }
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        if (mounted) {
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(
              message: 'Utilisateur destinataire non trouvé',
            ),
          );
          await _loadAllUsers(forceRefresh: true);
        }
      } else {
        print('Erreur lors de l\'envoi de la demande: $e');
        if (mounted) {
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(
              message: 'Erreur lors de l\'envoi de la demande',
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        await _loadFriendRequests();
        await _loadFriends();
        setState(() {
          _isAddingFriend = false;
        });
      }
    }
  }

  String getPendingRequestStatus(String username) {
    final request = _friendRequests.firstWhere(
      (req) => req.from == username || req.to == username,
      orElse:
          () => FriendRequest(
            from: '',
            to: '',
            status: 'none',
            avatar: null,
            avatarCustom: null,
          ),
    );

    if (request.status == 'rejected') return '';
    if (request.from == username) return 'Demande reçue';
    if (request.to == username) return 'Demande envoyée';
    return '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _friendService
      ..removeOnFriendAddedListener(_handleFriendAdded)
      ..removeOnFriendRemovedListener(_handleFriendRemoved)
      ..removeOnFriendRequestReceivedListener(_handleFriendRequestReceived)
      ..removeOnFriendRequestAcceptedListener(_handleFriendRequestAccepted)
      ..removeOnFriendRequestRejectedListener(_handleFriendRequestRejected)
      ..removeOnFriendListUpdatedListener(_handleFriendListUpdated)
      ..removeOnFriendRequestsListUpdatedListener(
        _handleFriendRequestsListUpdated,
      )
      ..removeOnFriendStatusUpdateListener(_handleFriendStatusUpdate)
      ..removeOnAllUsersUpdatedListener(_handleAllUsersUpdated);
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final friends = await _friendService.getFriends();
      if (mounted) {
        setState(() => _friends = friends);
      }
    } catch (e) {
      print('Erreur lors du chargement des amis: $e');
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors du chargement des amis',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    if (!mounted) return;
    try {
      final requests = await _friendService.getFriendRequests();
      if (mounted) {
        final currentUsername = AuthService().notifier.value?.username;
        final now = DateTime.now();

        final serverSentRequests =
            requests
                .where(
                  (req) =>
                      req.from == currentUsername && req.status != 'rejected',
                )
                .map((req) => req.to)
                .toSet();

        final existingUsernames = _allUsers.map((u) => u.username).toSet();

        setState(() {
          _friendRequests = requests;

          _sentRequests.removeWhere((username) {
            return !existingUsernames.contains(username) &&
                !serverSentRequests.contains(username);
          });

          _sentRequests.addAll(serverSentRequests);

          _recentlySentRequests.removeWhere((username, timestamp) {
            return now.difference(timestamp).inSeconds > 60;
          });
        });
        await _saveSentRequests();
      }
    } catch (e) {
      print('Erreur lors du chargement des demandes: $e');
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors du chargement des demandes',
          ),
        );
      }
    }
  }

  Future<void> _loadSentRequests() async {
    try {
      final currentUsername = AuthService().notifier.value?.username;
      if (currentUsername == null) return;

      final key = 'sent_friend_requests_$currentUsername';
      final stored = await _storage.read(key: key);

      if (stored != null) {
        final decoded = json.decode(stored) as Map<String, dynamic>;
        setState(() {
          _sentRequests = Set<String>.from(
            decoded['requests'] as List<dynamic>? ?? [],
          );

          final timestampsMap =
              decoded['timestamps'] as Map<String, dynamic>? ?? {};
          _recentlySentRequests = timestampsMap.map(
            (username, timestampStr) =>
                MapEntry(username, DateTime.parse(timestampStr as String)),
          );
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des demandes envoyées: $e');
    }
  }

  Future<void> _saveSentRequests() async {
    try {
      final currentUsername = AuthService().notifier.value?.username;
      if (currentUsername == null) return;

      final key = 'sent_friend_requests_$currentUsername';

      final data = {
        'requests': _sentRequests.toList(),
        'timestamps': _recentlySentRequests.map(
          (username, timestamp) =>
              MapEntry(username, timestamp.toIso8601String()),
        ),
      };

      final encoded = json.encode(data);
      await _storage.write(key: key, value: encoded);
    } catch (e) {
      print('Erreur lors de la sauvegarde des demandes envoyées: $e');
    }
  }

  void _setupEventListeners() {
    _friendService
      ..addOnFriendAddedListener(_handleFriendAdded)
      ..addOnFriendRemovedListener(_handleFriendRemoved)
      ..addOnFriendRequestReceivedListener(_handleFriendRequestReceived)
      ..addOnFriendRequestAcceptedListener(_handleFriendRequestAccepted)
      ..addOnFriendRequestRejectedListener(_handleFriendRequestRejected)
      ..addOnFriendListUpdatedListener(_handleFriendListUpdated)
      ..addOnFriendRequestsListUpdatedListener(_handleFriendRequestsListUpdated)
      ..addOnFriendStatusUpdateListener(_handleFriendStatusUpdate)
      ..addOnAllUsersUpdatedListener(_handleAllUsersUpdated);
  }

  void _handleAllUsersUpdated(List<User> users) {
    if (!mounted) return;

    final currentUsernames = users.map((u) => u.username).toSet();
    final requestsToRemove =
        _sentRequests
            .where((username) => !currentUsernames.contains(username))
            .toList();

    final updatedFriendRequests =
        _friendRequests.where((req) {
          return currentUsernames.contains(req.from) &&
              currentUsernames.contains(req.to);
        }).toList();

    if (requestsToRemove.isNotEmpty ||
        updatedFriendRequests.length != _friendRequests.length) {
      setState(() {
        for (final username in requestsToRemove) {
          _sentRequests.remove(username);
        }
        _friendRequests = updatedFriendRequests;
        _allUsers = users;
      });
      _saveSentRequests();
    } else {
      setState(() {
        _allUsers = users;
      });
    }
  }

  void _handleFriendStatusUpdate(String username, UserStatus status) {
    if (!mounted) return;

    final friendIndex = _friends.indexWhere((f) => f.username == username);
    if (friendIndex != -1) {
      setState(() {
        _friends[friendIndex] = _friends[friendIndex].copyWith(status: status);
      });
    }
  }

  void _handleFriendAdded(Friend friend) {
    if (!mounted) return;
    if (!_friends.any((f) => f.username == friend.username)) {
      setState(() => _friends = [..._friends, friend]);
    }
  }

  void _handleFriendRemoved(String username) {
    if (!mounted) return;
    setState(() {
      _friends.removeWhere((friend) => friend.username == username);
    });
  }

  void _handleFriendRequestReceived(FriendRequest request) {
    if (!mounted) return;
    if (!_friendRequests.any(
      (r) => r.from == request.from && r.to == request.to,
    )) {
      setState(() => _friendRequests = [..._friendRequests, request]);
    }
  }

  void _handleFriendRequestAccepted(Friend friend) {
    if (!mounted) return;
    setState(() {
      _friends = [..._friends, friend];
      _friendRequests.removeWhere((req) => req.from == friend.username);
      _sentRequests.remove(friend.username);
    });
    _saveSentRequests();
  }

  void _handleFriendRequestRejected(String username) {
    if (!mounted) return;
    setState(() {
      _friendRequests.removeWhere((req) => req.from == username);
      _sentRequests.remove(username);
    });
    _saveSentRequests();
  }

  void _handleFriendListUpdated(List<Friend> friends) {
    if (!mounted) return;

    final friendUsernames = friends.map((f) => f.username).toSet();
    final oldFriendUsernames = _friends.map((f) => f.username).toSet();
    final removedFriends = oldFriendUsernames.difference(friendUsernames);
    for (final username in removedFriends) {
      _sentRequests.remove(username);
    }

    setState(() {
      _friends = friends;
    });

    _saveSentRequests();
  }

  void _handleFriendRequestsListUpdated(List<FriendRequest> requests) {
    if (!mounted) return;

    final currentUsername = AuthService().notifier.value?.username;
    final actualSentRequests =
        requests
            .where(
              (req) => req.from == currentUsername && req.status != 'rejected',
            )
            .map((req) => req.to)
            .toSet();
    final requestsToRemove =
        _sentRequests.where((username) {
          return !actualSentRequests.contains(username);
        }).toList();

    if (requestsToRemove.isNotEmpty) {
      setState(() {
        for (final username in requestsToRemove) {
          _sentRequests.remove(username);
        }
        _friendRequests = requests;
      });
      _saveSentRequests();
    } else {
      setState(() {
        _friendRequests = requests;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFF2E3136),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildFriendsTab(), _buildRequestsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2124),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFF3B3F46), width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Amis (${_friends.length})'),
                Tab(text: 'Demandes (${_friendRequests.length})'),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final otherUsers = getFilteredOtherUsers();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: const InputDecoration(
              hintText: 'Rechercher un utilisateur...',
              hintStyle: TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
            ),
            style: const TextStyle(fontSize: 12),
            onTap: () {
              setState(() {
                _isFriendsSectionExpanded = false;
                _isOtherUsersSectionExpanded = true;
              });
            },
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                if (value.isNotEmpty) {
                  _isFriendsSectionExpanded = false;
                  _isOtherUsersSectionExpanded = true;
                }
              });
              if (value.isNotEmpty) {
                _loadAllUsers(forceRefresh: true);
                _loadFriendRequests();
              }
            },
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isFriendsSectionExpanded = !_isFriendsSectionExpanded;
                  });
                  _searchFocusNode.unfocus();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2124),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF3B3F46), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFriendsSectionExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mes Amis (${getFilteredFriends().length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isFriendsSectionExpanded) ...[
                if (getFilteredFriends().isEmpty)
                  _buildEmptyState('Aucun ami')
                else
                  ...getFilteredFriends().map(_buildFriendItem),
              ],

              InkWell(
                onTap: () {
                  setState(() {
                    _isOtherUsersSectionExpanded =
                        !_isOtherUsersSectionExpanded;
                  });
                  _searchFocusNode.unfocus();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2124),
                    border: Border(
                      top: BorderSide(color: Color(0xFF3B3F46), width: 1),
                      bottom: BorderSide(color: Color(0xFF3B3F46), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOtherUsersSectionExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Autres Utilisateurs (${otherUsers.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOtherUsersSectionExpanded) ...[
                if (otherUsers.isEmpty)
                  _buildEmptyState('Aucun autre utilisateur')
                else
                  ...otherUsers.map(
                    (user) => DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF3B3F46),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListTile(
                        title: Text(
                          user.username,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing:
                            getPendingRequestStatus(user.username).isEmpty &&
                                    !_sentRequests.contains(user.username)
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.person_add,
                                    color: Color(0xFF2E8B57),
                                  ),
                                  onPressed:
                                      _isAddingFriend
                                          ? null
                                          : () => _addFriend(user.username),
                                )
                                : null,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    if (_friendRequests.isEmpty) {
      return _buildEmptyState('Aucune demande d\'ami en attente');
    }

    return ListView.builder(
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return _buildRequestItem(request);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(child: Text(message, style: const TextStyle(fontSize: 10))),
    );
  }

  Widget _buildFriendItem(Friend friend) {
    return ListTile(
      leading: _buildAvatarWidget(friend.avatar, friend.username),
      title: Text(friend.username, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        _getStatusText(friend.status),
        style: TextStyle(color: _getStatusColor(friend.status), fontSize: 10),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove, color: Colors.red),
        onPressed: () => _removeFriend(friend),
      ),
    );
  }

  Widget _buildAvatarWidget(int? avatarId, String username) {
    if (avatarId != null && avatarId >= 1 && avatarId <= 12) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        backgroundImage: AssetImage(
          'lib/assets/previewcharacters/${avatarId}_preview.png',
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF2C3E50),
      child: Text(username[0].toUpperCase()),
    );
  }

  Widget _buildRequestItem(FriendRequest request) {
    return ListTile(
      leading: _buildAvatarWidget(request.avatar, request.from),
      title: Text(request.from, style: const TextStyle(fontSize: 12)),
      subtitle: const Text(
        'Souhaite être votre ami',
        style: TextStyle(fontSize: 10),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () => _acceptRequest(request),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _rejectRequest(request),
          ),
        ],
      ),
    );
  }

  String _getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'En ligne';
      case UserStatus.offline:
        return 'Hors ligne';
      case UserStatus.inGame:
        return 'En jeu';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.offline:
        return Colors.grey;
      case UserStatus.inGame:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    try {
      await _friendService.removeFriend(friend.username);
      setState(() {
        _sentRequests.remove(friend.username);
      });
      await _saveSentRequests();
      await _loadFriends();
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.success(
            message: '${friend.username} a été retiré de vos amis',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors de la suppression de l\'ami',
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await _friendService.acceptFriendRequest(request.from);
      await _loadFriendRequests();
      await _loadFriends();
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.success(
            message: 'Vous êtes maintenant ami avec ${request.from}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors de l\'acceptation de la demande',
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      await _friendService.rejectFriendRequest(request.from);
      await _loadFriendRequests();
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(
            message: 'Demande d\'ami de ${request.from} refusée',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(
            message: 'Erreur lors du refus de la demande',
          ),
        );
      }
    }
  }
}
