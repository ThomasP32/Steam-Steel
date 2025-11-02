import { GameCreationService } from '@app/services/game-creation/game-creation.service';
import { GameCreationEvents, JoinGameData, KickPlayerData, ToggleGameLockStateData } from '@common/events/game-creation.events';
import { Game } from '@common/game';
import { Mode } from '@common/map.types';
import { Inject } from '@nestjs/common';
import { SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { FriendsService } from '../../../../http/services/friends/friends.service';
import { UserService } from '../../../../http/services/user/user.service';
import { JournalService } from '../../../../services/journal/journal.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class GameGateway {
    @WebSocketServer()
    server: Server;

    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(UserSocketService) private readonly userSocketSession: UserSocketService;
    @Inject(FriendsService) private readonly friendsService: FriendsService;
    @Inject(UserService) private readonly userService: UserService;

    @SubscribeMessage(GameCreationEvents.CreateGame)
    handleCreateGame(client: Socket, newGame: Game): void {
        client.join(newGame.id);
        newGame.hostSocketId = client.id;
        this.gameCreationService.addGame(newGame);
        this.server.to(newGame.id).emit(GameCreationEvents.GameCreated, newGame);
    }

    @SubscribeMessage(GameCreationEvents.JoinGame)
    async handleJoinGame(client: Socket, data: JoinGameData): Promise<void> {
        if (this.gameCreationService.doesGameExist(data.gameId)) {
            let game = this.gameCreationService.getGameById(data.gameId);
            if (game.isLocked) {
                client.emit(GameCreationEvents.GameLocked, 'La partie est vérouillée, veuillez réessayer plus tard.');
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

            game = this.gameCreationService.addPlayerToGame(data.player, data.gameId);
            if (this.gameCreationService.isMaxPlayersReached(game.players, data.gameId)) {
                this.gameCreationService.lockGame(data.gameId);
            }
            const newPlayer = game.players.filter((player) => player.socketId === client.id)[0];
            client.emit(GameCreationEvents.YouJoined, newPlayer);
            this.server.to(data.gameId).emit(GameCreationEvents.PlayerJoined, game.players);
            this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée');
        }
    }

    @SubscribeMessage(GameCreationEvents.GetPlayers)
    getAvailableAvatars(client: Socket, gameId: string): void {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            client.emit(
                GameCreationEvents.CurrentPlayers,
                game.players.filter((player) => player.isActive),
            );
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée');
        }
    }

    @SubscribeMessage(GameCreationEvents.KickPlayer)
    handleKickPlayer(client: Socket, data: KickPlayerData): void {
        if (data.playerId.includes('virtualPlayer')) {
            const game = this.gameCreationService.getGameById(data.gameId);
            game.players = game.players.filter((player) => player.socketId !== data.playerId);
            if (!this.gameCreationService.isMaxPlayersReached(game.players, data.gameId)) {
                game.isLocked = false;
            }
            this.server.to(data.gameId).emit(GameCreationEvents.PlayerLeft, game.players);
            return;
        }
        this.server.to(data.playerId).emit(GameCreationEvents.PlayerKicked);
    }

    @SubscribeMessage(GameCreationEvents.GetGameData)
    getGame(client: Socket, gameId: string): void {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            client.emit(GameCreationEvents.CurrentGame, game);
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée');
        }
    }

    @SubscribeMessage(GameCreationEvents.AccessGame)
    async handleAccessGame(client: Socket, gameId: string): Promise<void> {
        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);

            if (game.hasStarted) {
                client.emit(GameCreationEvents.GameLocked, "Vous n'avez pas été assez rapide...\nLa partie a déjà commencé.");
                return;
            } else if (game.isLocked) {
                client.emit(GameCreationEvents.GameLocked, 'La partie est vérouillée, veuillez réessayer plus tard.');
                return;
            }

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

            client.join(gameId);
            client.emit(GameCreationEvents.GameAccessed);
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
                        socket.emit(GameCreationEvents.GameAlreadyStarted, "La partie a commencée. Vous serez redirigé à la page d'acceuil");
                        socket.leave(roomId);
                    }
                });
                this.server.to(roomId).emit(GameCreationEvents.GameInitialized, game);
            }
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
        if (!game.hasStarted) {
            if (this.gameCreationService.isPlayerHost(client.id, game.id)) {
                this.server.to(game.id).emit(GameCreationEvents.GameClosed);
                this.gameCreationService.deleteRoom(game.id);
                return;
            }
        }
        if (game.players.some((player) => player.socketId === client.id)) {
            game = this.gameCreationService.handlePlayerLeaving(client, gameId);
            client.leave(gameId);
            client.leave(gameId + '-combat');
            this.server.to(game.id).emit(GameCreationEvents.PlayerLeft, game.players);

            // Check if this is CTF mode and no active non-observer players remain
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
}
