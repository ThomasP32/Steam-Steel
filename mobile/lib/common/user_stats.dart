class GameStats {
  GameStats({required this.gamesPlayed, required this.gamesWon});

  final int gamesPlayed;
  final int gamesWon;
}

class StatsUser {
  StatsUser({
    required this.classique,
    required this.ctf,
    required this.avgTime,
  });

  final GameStats classique;
  final GameStats ctf;
  final double avgTime;
}
