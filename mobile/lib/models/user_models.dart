enum UserStatus { online, offline, inGame, unknown }

class User {
  const User({required this.username});
  final String username;
}

class Friend {
  Friend({
    required this.username,
    this.status = UserStatus.unknown,
    this.avatar,
    this.avatarCustom,
    this.profilePicture,
    this.profilePictureCustom,
  });
  factory Friend.fromJson(Map<String, dynamic> json) {
    final avatarValue = json['avatar'];
    final profilePictureValue = json['profilePicture'];
    return Friend(
      username: json['username'] as String,
      status: _parseStatus(json['status'] as String?),
      avatar:
          avatarValue is int
              ? avatarValue
              : (avatarValue is String ? int.tryParse(avatarValue) : null),
      avatarCustom: json['avatarCustom'] as String?,
      profilePicture:
          profilePictureValue is int
              ? profilePictureValue
              : (profilePictureValue is String
                  ? int.tryParse(profilePictureValue)
                  : null),
      profilePictureCustom: json['profilePictureCustom'] as String?,
    );
  }
  final String username;
  final UserStatus status;
  final int? avatar;
  final String? avatarCustom;
  final int? profilePicture;
  final String? profilePictureCustom;

  Friend copyWith({
    String? username,
    UserStatus? status,
    int? avatar,
    String? avatarCustom,
    int? profilePicture,
    String? profilePictureCustom,
  }) {
    return Friend(
      username: username ?? this.username,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      avatarCustom: avatarCustom ?? this.avatarCustom,
      profilePicture: profilePicture ?? this.profilePicture,
      profilePictureCustom: profilePictureCustom ?? this.profilePictureCustom,
    );
  }

  static UserStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
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
}

class FriendRequest {
  FriendRequest({
    required this.from,
    required this.to,
    required this.status,
    this.avatar,
    this.avatarCustom,
    this.profilePicture,
    this.profilePictureCustom,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final avatarValue = json['avatar'];
    final profilePictureValue = json['profilePicture'];
    return FriendRequest(
      from: json['from'] as String,
      to: json['to'] as String,
      status: json['status'] as String,
      avatar:
          avatarValue is int
              ? avatarValue
              : (avatarValue is String ? int.tryParse(avatarValue) : null),
      avatarCustom: json['avatarCustom'] as String?,
      profilePicture:
          profilePictureValue is int
              ? profilePictureValue
              : (profilePictureValue is String
                  ? int.tryParse(profilePictureValue)
                  : null),
      profilePictureCustom: json['profilePictureCustom'] as String?,
    );
  }
  final String from;
  final String to;
  final String status;
  final int? avatar;
  final String? avatarCustom;
  final int? profilePicture;
  final String? profilePictureCustom;
}
