class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.stats = const UserStats(
      classique: GameStats(gamesPlayed: 0, gamesWon: 0),
      ctf: GameStats(gamesPlayed: 0, gamesWon: 0),
      avgTime: 0,
    ),
    this.avatar = '',
    this.avatarCustom,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    final stats = UserStatsJson.fromJson(j['stats'] ?? <String, dynamic>{});
    return User(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      username: j['username']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      avatar: j['avatar']?.toString() ?? '',
      avatarCustom: j['avatarCustom']?.toString(),
      stats: stats,
    );
  }

  final String id;
  final String username;
  final String email;
  final String avatar;
  final UserStats stats;
  final String? avatarCustom;
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
  });

  final GameStats classique;
  final GameStats ctf;
  final double avgTime;
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
      );
    }
    return const UserStats(
      classique: GameStats(gamesPlayed: 0, gamesWon: 0),
      ctf: GameStats(gamesPlayed: 0, gamesWon: 0),
      avgTime: 0,
    );
  }
}
