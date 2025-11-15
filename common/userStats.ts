export interface StatsUser {
    classique: { gamesPlayed: number; gamesWon: number };
    ctf: { gamesPlayed: number; gamesWon: number };
    avgTime: number;
    challengesCompleted: number;
    level: number;
}