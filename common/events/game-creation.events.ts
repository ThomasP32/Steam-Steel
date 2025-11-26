import { Player } from '@common/game';

export enum GameCreationEvents {
    GameClosed = 'gameClosed',
    GameEndedNoActivePlayers = 'gameEndedNoActivePlayers',
    PlayerLeft = 'playerLeft',
    CreateGame = 'createGame',
    GameCreated = 'gameCreated',
    GameCreationError = 'gameCreationError',
    JoinGame = 'joinGame',
    GameLocked = 'gameLocked',
    GameUpdated = 'GameUpdated',
    GameListUpdated = 'gameListUpdated',

    YouJoined = 'youJoined',
    PlayerJoined = 'playerJoined',
    CurrentPlayers = 'currentPlayers',
    GameNotFound = 'gameNotFound',

    GetPlayers = 'getPlayers',
    KickPlayer = 'kickPlayer',
    PlayerKicked = 'playerKicked',

    GetGames = 'getGames',
    GetGameData = 'getGameData',
    CurrentGame = 'currentGame',

    AccessGame = 'accessGame',
    GameAccessed = 'gameAccessed',
    GameResumed = 'gameResumed',

    InitializeGame = 'initializeGame',
    GameInitialized = 'gameInitialized',

    ToggleGameLockState = 'toggleGameLockState',
    GameLockToggled = 'gameLockToggled',

    GameAlreadyStarted = 'gameAlreadyStarted',

    IfStartable = 'ifStartable',
    IsStartable = 'isStartable',

    LeaveGame = 'leaveGame',
    ResumeGame = 'resumeGame',
    ObserveGame = 'observeGame',

    UpdateAudioSettings = 'updateAudioSettings',
    AudioSettingsUpdated = 'audioSettingsUpdated',
}

export interface KickPlayerData {
    gameId: string;
    playerId: string;
}

export interface JoinGameData {
    player: Player;
    gameId: string;
}

export interface ToggleGameLockStateData {
    isLocked: boolean;
    gameId: string;
}

export interface UpdateAudioSettingsData {
    gameId: string;
    musicEnabled: boolean;
    sfxEnabled: boolean;
    equippedMusic?: string;
}
