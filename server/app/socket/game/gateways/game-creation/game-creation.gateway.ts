import { ChallengeService } from '@app/services/challenge/challenge.service';
import { CombatService } from '@app/services/combat/combat.service';
import { CombatCountdownService } from '@app/services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from '@app/services/countdown/game/game-countdown.service';
import { GameCreationService } from '@app/services/game-creation/game-creation.service';
import { ChallengeEvent } from '@common/events/challenge.events';
import { CountdownEvents } from '@common/events/countdown.events';
import { GameCreationEvents, JoinGameData, KickPlayerData, ToggleGameLockStateData } from '@common/events/game-creation.events';
import { GameTurnEvents } from '@common/events/game-turn.events';
import { Game, GameEndReason } from '@common/game';
import { Mode } from '@common/map.types';
import { Inject } from '@nestjs/common';
import { SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { FriendsService } from '../../../../http/services/friends/friends.service';
import { UserService } from '../../../../http/services/user/user.service';
import { GameManagerService } from '../../../../services/game-manager/game-manager.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class GameGateway {
    @WebSocketServer()
    server: Server;

    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(GameCountdownService) private readonly gameCountdownService: GameCountdownService;
    @Inject(CombatCountdownService) private readonly combatCountdownService: CombatCountdownService;
    @Inject(CombatService) private readonly combatService: CombatService;
    @Inject(UserSocketService) private readonly userSocketSession: UserSocketService;
    @Inject(FriendsService) private readonly friendsService: FriendsService;
    @Inject(UserService) private readonly userService: UserService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;

    @SubscribeMessage(GameCreationEvents.CreateGame)
    handleCreateGame(client: Socket, newGame: Game): void {
        client.join(newGame.id);
        newGame.hostSocketId = client.id;
        this.gameCreationService.addGame(newGame);
        const initialPlayer = newGame.players[0];
        if(initialPlayer){
            this.challengeService.assignForPlayer(newGame, initialPlayer);
        }
        this.server.to(newGame.id).emit(GameCreationEvents.GameCreated, newGame);
        this.server.emit(GameCreationEvents.GameListUpdated);
    }

    @SubscribeMessage(GameCreationEvents.JoinGame)
    async handleJoinGame(client: Socket, data: JoinGameData): Promise<void> {
        if (this.gameCreationService.doesGameExist(data.gameId)) {
            let game = this.gameCreationService.getGameById(data.gameId);
            if ((game.isLocked && !game.settings.isDropInOut) || (game.isLocked && game.settings.isDropInOut && !game.hasStarted)) {
                client.emit(GameCreationEvents.GameLocked, 'La partie est vérrouillée, veuillez réessayer plus tard.');
                return;
            }

            if (game.settings.isFriendsOnly) {
                const isVirtualPlayer = data.player.socketId.includes('virtualPlayer');
                if (!isVirtualPlayer) {
                    const isAuthorized = await this.checkIfPlayerCanJoinFriendsOnlyGame(game, data.player.name);
                    if (!isAuthorized) {
                        client.emit(GameCreationEvents.GameLocked, 'Cette partie est réservée aux amis du créateur.');
                        return;
                    }
                }
            }

            game = this.gameCreationService.addPlayerToGame(client.id, data.player, data.gameId);
            if (this.gameCreationService.isMaxPlayersReached(game.players, data.gameId)) {
                this.gameCreationService.lockGame(data.gameId);
            }
            
            const newPlayer = game.players.find((player) => player.socketId === client.id);
            if (!newPlayer) {
                client.emit(GameCreationEvents.GameNotFound, 'Erreur lors de la connexion au jeu.');
                return;
            }
            newPlayer.isObservationMode = false;
            if (game.hasStarted) {
                const activePlayers = game.players.filter((plyr) => plyr.isActive);
                newPlayer.turn = activePlayers.length - 1;
                let positionInitialized = false;
                for (const tile of game.startTiles) {
                    const isOccupiedTile = activePlayers.some((plyr) => this.gameCreationService.sameCoords(plyr.position, tile.coordinate));
                    if (!isOccupiedTile) {
                        newPlayer.initialPosition = tile.coordinate;
                        newPlayer.position = tile.coordinate;
                        positionInitialized = true;
                        break;
                    }
                }
                if (!positionInitialized) {
                    for (const player of activePlayers) {
                        const closestInitialPosition = this.combatService.findClosestAvailablePosition(player.initialPosition, game);
                        if (closestInitialPosition) {
                            newPlayer.initialPosition = closestInitialPosition;
                            newPlayer.position = closestInitialPosition;
                            positionInitialized = true;
                            break;
                        }
                    }
                }
            }
            client.emit(GameCreationEvents.YouJoined, { updatedPlayer: newPlayer, updatedGame: game });
            this.server.to(data.gameId).emit(GameCreationEvents.PlayerJoined, game.players);
            this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);
            this.server.to(data.gameId).emit(GameCreationEvents.GameUpdated, game);
            this.server.emit(GameCreationEvents.GameListUpdated);

            // Send current timer state if game has started
            if (game.hasStarted) {
                this.syncTimerState(client, game.id);
            }

            const existingChallenge = this.challengeService.getPlayerChallenge(game.id, newPlayer.name);
            if (existingChallenge) {
                client.emit(ChallengeEvent.Updated, existingChallenge);
            } else if (!newPlayer.socketId.includes('virtual') && !newPlayer.isObservationMode) {
                this.challengeService.assignForPlayer(game, newPlayer);
            }
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    @SubscribeMessage(GameCreationEvents.GetPlayers)
    getAvailableAvatars(client: Socket, gameId: string): void {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            client.emit(GameCreationEvents.CurrentPlayers, game.players);
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    @SubscribeMessage(GameCreationEvents.KickPlayer)
    handleKickPlayer(client: Socket, data: KickPlayerData): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        game.players = game.players.filter((player) => player.socketId !== data.playerId);
        game.participants = [...game.players];
        if (!this.gameCreationService.isMaxPlayersReached(game.players, data.gameId)) {
            game.isLocked = false;
            this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
        }
        this.server.to(data.gameId).emit(GameCreationEvents.PlayerLeft, game.players);
        this.server.to(data.playerId).emit(GameCreationEvents.PlayerKicked);
        this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);
        this.server.emit(GameCreationEvents.GameListUpdated);
    }

    @SubscribeMessage(GameCreationEvents.GetGameData)
    getGame(client: Socket, gameId: string): void {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            client.emit(GameCreationEvents.CurrentGame, game);
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    @SubscribeMessage(GameCreationEvents.GetGames)
    getGames(client: Socket): void {
        const games = this.gameCreationService.getGames();
        client.emit(GameCreationEvents.GetGames, games);
    }

    @SubscribeMessage(GameCreationEvents.AccessGame)
    async handleAccessGame(client: Socket, gameId: string): Promise<void> {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            if (game.settings.isFriendsOnly) {
                const userId = this.userSocketSession.getUserIdBySocket(client.id);
                if (userId) {
                    const user = await this.userService.findById(userId);
                    if (user) {
                        const isAuthorized = await this.checkIfPlayerCanJoinFriendsOnlyGame(game, user.username);
                        if (!isAuthorized) {
                            client.emit(GameCreationEvents.GameLocked, 'Cette partie est réservée aux amis du créateur.');
                            return;
                        }
                    }
                }
            }
            if (game.hasStarted && !game.settings.isDropInOut) {
                client.emit(GameCreationEvents.GameLocked, "Vous n'avez pas été assez rapide...\nLa partie a déjà commencé.");
                return;
            } else if (game.hasStarted && game.settings.isDropInOut) {
                if (game.settings.isFastElimination) {
                    if (this.gameCreationService.isMaxPlayersReached(game.participants, game.id)) {
                        client.emit(
                            GameCreationEvents.GameLocked,
                            'La partie a atteint son nombre de joueur maximal.\n Veuillez réessayez plus tard.',
                        );
                        return;
                    }
                } else {
                    const activePlayers = game.players.filter((plyr) => plyr.isActive);
                    if (this.gameCreationService.isMaxPlayersReached(activePlayers, gameId)) {
                        client.emit(
                            GameCreationEvents.GameLocked,
                            'La partie a atteint son nombre de joueur maximal.\n Veuillez réessayez plus tard.',
                        );
                        return;
                    }
                }
                client.join(gameId);
                client.emit(GameCreationEvents.GameAccessed, game.id);
                // Sync timer state for drop-in player
                this.syncTimerState(client, gameId);
                return;
            } else if (game.isLocked) {
                client.emit(GameCreationEvents.GameLocked, 'La partie est vérouillée, veuillez réessayer plus tard.');
                return;
            }

            client.join(gameId);
            client.emit(GameCreationEvents.GameAccessed, game.id);
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'Le code est invalide, veuillez réessayer.');
        }
    }

    @SubscribeMessage(GameCreationEvents.InitializeGame)
    async handleInitGame(client: Socket, roomId: string): Promise<void> {
        if (this.gameCreationService.doesGameExist(roomId)) {
            const game = this.gameCreationService.getGameById(roomId);
            if (game && client.id === game.hostSocketId) {
                this.gameCreationService.initializeGame(roomId);
                const sockets = await this.server.in(roomId).fetchSockets();
                sockets.forEach((socket) => {
                    if (game.players.every((player) => player.socketId !== socket.id)) {
                        socket.emit(GameCreationEvents.GameAlreadyStarted, "La partie a commencée. Vous serez redirigé à la page d'acceuil.");
                        socket.leave(roomId);
                    }
                });
                this.server.to(roomId).emit(GameCreationEvents.GameInitialized, game);
            }
            this.server.emit(GameCreationEvents.GameListUpdated);
        } else {
            client.emit(GameCreationEvents.GameNotFound);
        }
    }

    @SubscribeMessage(GameCreationEvents.ToggleGameLockState)
    handleToggleGameLockState(client: Socket, data: ToggleGameLockStateData): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (game && game.hostSocketId === client.id) {
            game.isLocked = data.isLocked;
            this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
            this.server.emit(GameCreationEvents.GameListUpdated);
        }
    }

    @SubscribeMessage(GameCreationEvents.IfStartable)
    isStartable(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (game && client.id === game.hostSocketId) {
            if (this.gameCreationService.isGameStartable(gameId)) {
                client.emit(GameCreationEvents.IsStartable);
            } else {
                return;
            }
        }
    }

    @SubscribeMessage(GameCreationEvents.LeaveGame)
    handleLeaveGame(client: Socket, gameId: string): void {
        let game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            return;
        }
        if (!game.hasStarted) {
            if (this.gameCreationService.isPlayerHost(client.id, game.id)) {
                this.server.to(game.id).emit(GameCreationEvents.GameClosed);
                this.gameCreationService.deleteRoom(game.id);
                this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
                this.gameCountdownService.deleteCountdown(game.id); // Clean up timers if any
                this.combatCountdownService.deleteCountdown(game.id);
                return;
            } else {
                game.players = game.players.filter((player) => player.socketId !== client.id);
                if (!this.gameCreationService.isMaxPlayersReached(game.players, game.id)) {
                    game.isLocked = false;
                    this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
                }
                game.participants = [...game.players];
                this.server.to(game.id).emit(GameCreationEvents.PlayerLeft, game.players);
                this.server.to(game.id).emit(GameCreationEvents.CurrentPlayers, game.players);
            }
        } else if (game.players.some((player) => player.socketId === client.id)) {
            const leavingPlayer = game.players.find((player) => player.socketId === client.id);
            game.players = game.players.map((player) => {
                return player.socketId === client.id ? { ...player, isActive: false } : player;
            });

            if (game.hasStarted && leavingPlayer?.initialPosition) {
                game.startTiles = game.startTiles.filter(
                    (tile) => tile.coordinate.x !== leavingPlayer.initialPosition.x || tile.coordinate.y !== leavingPlayer.initialPosition.y,
                );
            }

            game.isLocked = false;
            this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
            client.leave(gameId);
            client.leave(gameId + '-combat');
            this.server.to(game.id).emit(GameCreationEvents.PlayerLeft, game.players);
            this.server.to(game.id).emit(GameCreationEvents.GameUpdated, game);
            if (game.hasStarted && game.mode === Mode.Ctf) {
                const activeNonObserverCount = game.players.filter((p) => p.isActive && p.isObservationMode !== true).length;

                if (activeNonObserverCount === 0) {
                    console.log(`[CTF] Last active player quit. Ending game ${game.id}`);
                    this.server.to(game.id).emit(GameCreationEvents.GameEndedNoActivePlayers);
                    this.gameCreationService.deleteRoom(game.id);
                }
            }
        } else {
            return;
        }
        this.server.emit(GameCreationEvents.GameListUpdated);
    }

    @SubscribeMessage(GameCreationEvents.ResumeGame)
    handleResumeGame(client: Socket, gameId: string): void {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            if (game.hasStarted) {
                if (!game.settings.isFastElimination) {
                    const activePlayers = game.players.filter((plyr) => plyr.isActive);
                    if (this.gameCreationService.isMaxPlayersReached(activePlayers, gameId)) {
                        client.emit(
                            GameCreationEvents.GameLocked,
                            'La partie a atteint son nombre de joueur maximal.\n Veuillez réessayez plus tard.',
                        );
                        return;
                    }
                }
                client.join(gameId);
                client.emit(GameCreationEvents.GameResumed, game);
                // Sync timer state for resuming player
                this.syncTimerState(client, gameId);
            }
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    @SubscribeMessage(GameCreationEvents.ObserveGame)
    handleObserveGame(client: Socket, data: JoinGameData): void {
        if (this.gameCreationService.doesGameExist(data.gameId)) {
            const game = this.gameCreationService.getGameById(data.gameId);
            client.join(game.id);

            let existingPlayer = game.players.find((plyr) => plyr.name === data.player.name);
            if (existingPlayer) {
                existingPlayer.socketId = data.player.socketId;
                existingPlayer.isObservationMode = true;
                existingPlayer.isActive = false;
            } else {
                // Add new observer player
                data.player.isObservationMode = true;
                data.player.isActive = false;
                game.players.push(data.player);
            }

            const observerPlayer = game.players.find((plyr) => plyr.name === data.player.name);
            client.emit(GameCreationEvents.YouJoined, { updatedPlayer: observerPlayer, updatedGame: game });
            this.server.to(data.gameId).emit(GameCreationEvents.PlayerJoined, game.players);
            this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);

            // Send current turn information to observer if game has started
            if (game.hasStarted) {
                const currentPlayer = game.players.find((p) => p.turn === game.currentTurn);
                if (currentPlayer) {
                    client.emit(GameTurnEvents.PlayerTurn, currentPlayer.name);
                    // Send delay = 0 to hide the turn overlay and show the game board
                    client.emit(CountdownEvents.Delay, 0);
                }
                // Sync timer state for observer
                this.syncTimerState(client, game.id);
            }
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    private async checkIfPlayerCanJoinFriendsOnlyGame(game: Game, playerUsername: string): Promise<boolean> {
        try {
            const hostSocketId = game.hostSocketId;
            const hostUserId = this.userSocketSession.getUserIdBySocket(hostSocketId);

            if (!hostUserId) {
                return false;
            }

            const hostUser = await this.userService.findById(hostUserId);
            if (!hostUser) {
                return false;
            }

            if (hostUser.username === playerUsername) {
                return true;
            }

            const hostFriends = await this.friendsService.getFriends(hostUserId);
            const isFriend = hostFriends.some((friend) => friend.username === playerUsername);

            return isFriend;
        } catch (error) {
            console.error('Error checking friend status:', error);
            return false;
        }
    }

    private syncTimerState(client: Socket, gameId: string): void {
        // Sync game countdown timer
        if (this.gameCountdownService.hasActiveCountdown(gameId)) {
            const currentCountdown = this.gameCountdownService.getCurrentCountdown(gameId);
            if (currentCountdown !== undefined) {
                client.emit(CountdownEvents.SecondPassed, currentCountdown);
            }
        }

        // Sync combat countdown timer if active
        if (this.combatCountdownService.hasActiveCountdown(gameId)) {
            const currentCombatCountdown = this.combatCountdownService.getCurrentCountdown(gameId);
            if (currentCombatCountdown !== undefined) {
                client.emit(CountdownEvents.CombatSecondPassed, currentCombatCountdown);
            }
        }
    }
}
