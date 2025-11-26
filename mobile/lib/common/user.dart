class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.status = 'offline',
    this.stats = const UserStats(
      classique: GameStats(gamesPlayed: 0, gamesWon: 0),
      ctf: GameStats(gamesPlayed: 0, gamesWon: 0),
      avgTime: 0,
    ),
    this.avatar = '',
    this.avatarCustom,
    this.profilePicture,
    this.profilePictureCustom,
    this.virtualMoney = 0,
    this.shopItems = const [],
  });

  factory User.fromJson(Map<String, dynamic> j) {
    final stats = UserStatsJson.fromJson(j['stats'] ?? <String, dynamic>{});
    final shopItemsList =
        (j['shopItems'] as List<dynamic>?)
            ?.map(
              (item) =>
                  ShopItemOwnership.fromJson(item as Map<String, dynamic>),
            )
            .toList() ??
        [];

    // Parse profilePicture as int
    final profilePictureValue = j['profilePicture'];
    final profilePictureInt =
        profilePictureValue is int
            ? profilePictureValue
            : (profilePictureValue is String
                ? int.tryParse(profilePictureValue)
                : null);

    return User(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      username: j['username']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      status: j['status']?.toString() ?? 'offline',
      avatar: j['avatar']?.toString() ?? '',
      avatarCustom: j['avatarCustom']?.toString(),
      profilePicture: profilePictureInt,
      profilePictureCustom: j['profilePictureCustom']?.toString(),

      stats: stats,
      virtualMoney:
          (j['virtualMoney'] is int)
              ? j['virtualMoney'] as int
              : int.tryParse('${j['virtualMoney']}') ?? 0,
      shopItems: shopItemsList,
    );
  }

  final String id;
  final String username;
  final String email;
  final String status;
  final String avatar;
  final UserStats stats;
  final String? avatarCustom;
  final int? profilePicture;
  final String? profilePictureCustom;
  final int virtualMoney;
  final List<ShopItemOwnership> shopItems;

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? status,
    String? avatar,
    UserStats? stats,
    String? avatarCustom,
    int? profilePicture,
    String? profilePictureCustom,
    int? virtualMoney,
    List<ShopItemOwnership>? shopItems,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      stats: stats ?? this.stats,
      avatarCustom: avatarCustom ?? this.avatarCustom,
      profilePicture: profilePicture ?? this.profilePicture,
      profilePictureCustom: profilePictureCustom ?? this.profilePictureCustom,
      virtualMoney: virtualMoney ?? this.virtualMoney,
      shopItems: shopItems ?? this.shopItems,
    );
  }
}

class ShopItemOwnership {
  const ShopItemOwnership({
    required this.itemId,
    required this.equipped,
    this.purchaseDate,
  });

  factory ShopItemOwnership.fromJson(Map<String, dynamic> j) {
    return ShopItemOwnership(
      itemId: j['itemId']?.toString() ?? '',
      equipped: j['equipped'] as bool? ?? false,
      purchaseDate:
          j['purchaseDate'] != null
              ? DateTime.tryParse(j['purchaseDate'].toString())
              : null,
    );
  }

  final String itemId;
  final bool equipped;
  final DateTime? purchaseDate;
}

class GameStats {
  const GameStats({required this.gamesPlayed, required this.gamesWon});

  final int gamesPlayed;
  final int gamesWon;
}

class UserStats {
  const UserStats({
    required this.classique,
    required this.ctf,
    required this.avgTime,
    this.challengesCompleted = 0,
    this.level = 1,
  });

  final GameStats classique;
  final GameStats ctf;
  final double avgTime;
  final int challengesCompleted;
  final int level;
}

// helpers
extension GameStatsJson on GameStats {
  static GameStats fromJson(dynamic j) {
    if (j is Map) {
      return GameStats(
        gamesPlayed:
            (j['gamesPlayed'] is int)
                ? j['gamesPlayed'] as int
                : int.tryParse('${j['gamesPlayed']}') ?? 0,
        gamesWon:
            (j['gamesWon'] is int)
                ? j['gamesWon'] as int
                : int.tryParse('${j['gamesWon']}') ?? 0,
      );
    }
    return const GameStats(gamesPlayed: 0, gamesWon: 0);
  }
}

extension UserStatsJson on UserStats {
  static UserStats fromJson(dynamic j) {
    if (j is Map<String, dynamic>) {
      return UserStats(
        classique: GameStatsJson.fromJson(
          j['classique'] ?? <String, dynamic>{},
        ),
        ctf: GameStatsJson.fromJson(j['ctf'] ?? <String, dynamic>{}),
        avgTime:
            (j['avgTime'] is num)
                ? (j['avgTime'] as num).toDouble()
                : double.tryParse('${j['avgTime']}') ?? 0.0,
        challengesCompleted:
            (j['challengesCompleted'] is int)
                ? j['challengesCompleted'] as int
                : int.tryParse('${j['challengesCompleted']}') ?? 0,
        level:
            (j['level'] is int)
                ? j['level'] as int
                : int.tryParse('${j['level']}') ?? 1,
      );
    }
    return const UserStats(
      classique: GameStats(gamesPlayed: 0, gamesWon: 0),
      ctf: GameStats(gamesPlayed: 0, gamesWon: 0),
      avgTime: 0,
      challengesCompleted: 0,
      level: 1,
    );
  }
}
