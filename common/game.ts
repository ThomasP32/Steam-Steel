import { Coordinate, ItemCategory, Map, Mode } from '@common/map.types';
import { ProfileType } from './constants';

export enum Avatar {
    Avatar1 = 1,
    Avatar2 = 2,
    Avatar3 = 3,
    Avatar4 = 4,
    Avatar5 = 5,
    Avatar6 = 6,
    Avatar7 = 7,
    Avatar8 = 8,
    Avatar9 = 9,
    Avatar10 = 10,
    Avatar11 = 11,
    Avatar12 = 12,
    Avatar13 = 13,
    Avatar14 = 14,
    Avatar15 = 15,
    Avatar16 = 16,
    Avatar17 = 17,
}

export enum ProfilePicture {
    Profile1 = 1,
    Profile2 = 2,
    Profile3 = 3,
    Profile4 = 4,
    Profile5 = 5,
    Profile6 = 6,
    Profile7 = 7,
    Profile8 = 8,
    Profile9 = 9,
    Profile10 = 10,
    Profile11 = 11,
    Profile12 = 12,
    Profile13 = 13,
}

export enum BotName {
    Bot1 = 'AlphaBot',
    Bot2 = 'RoboWarrior',
    Bot3 = 'CyberHawk',
    Bot4 = 'SteelFist',
    Bot5 = 'MechaMage',
    Bot6 = 'IronClad',
    Bot7 = 'TechNinja',
    Bot8 = 'ShadowBot',
    Bot9 = 'RoboKnight',
    Bot10 = 'CyberAssassin',
}

export enum Bonus {
    D4 = 4,
    D6 = 6,
}

export interface Specs {
    life: number;
    evasions: number;
    speed: number;
    attack: number;
    defense: number;
    attackBonus: Bonus;
    defenseBonus: Bonus;
    movePoints: number;
    actions: number;
    nVictories: number;
    nDefeats: number;
    nCombats: number;
    nEvasions: number;
    nLifeTaken: number;
    nLifeLost: number;
    nItemsUsed: number;
}

export interface Player {
    socketId: string;
    name: string;
    avatar: Avatar;
    level: number;
    isActive: boolean;
    isEliminated?: boolean;
    isObserver?: boolean;
    wasActivePlayer?: boolean;
    specs: Specs;
    inventory: ItemCategory[];
    position: Coordinate;
    initialPosition: Coordinate;
    turn: number;
    visitedTiles: Coordinate[];
    profile: ProfileType;
    isGameWinner?: boolean;
}

export interface GameClassic extends Map {
    id: string;
    hostSocketId: string;
    players: Player[];
    currentTurn: number;
    nDoorsManipulated: Coordinate[];
    duration: number;
    nTurns: number;
    lastTurnPlayer?: string;
    debug: boolean;
    isLocked: boolean;
    hasStarted: boolean;
    settings: GameSettings;
}

interface GameSettings {
    isFastElimination: boolean;
    isDropInOut: boolean;
    isFriendsOnly: boolean;
    entryFee: number;
}

export interface GameCtf extends GameClassic {
    mode: Mode.Ctf;
    nPlayersCtf: Player[];
    playerStartTiles?: { socketId: string; coordinate: Coordinate }[];
}

export type Game = GameClassic | GameCtf;

export enum GameEndReason {
    NoWinner_Termination = 'no_winner_termination',
    Victory_Elimination = 'victory_elimination',
    Victory_CombatWins = 'victory_combat_wins',
    Victory_CtfFlag = 'victory_ctf_flag',
    Victory_LastPlayerStanding = 'victory_last_player_standing',
    Ongoing = 'ongoing',
}

export interface GameEndResult {
    reason: GameEndReason;
    winner?: Player;
    moneyRewards?: { [key: string]: number };
}

export interface GameFinishedData {
    updatedGame: Game;
    moneyRewards?: { [socketId: string]: number };
    reason?: GameEndReason;
}

export interface GameFinishedPlayerWonData {
    winner: Player;
    reason: GameEndReason;
}
