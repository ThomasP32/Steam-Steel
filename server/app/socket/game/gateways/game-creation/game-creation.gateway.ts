import { ChallengeService } from '@app/services/challenge/challenge.service';
import { CombatService } from '@app/services/combat/combat.service';
import { CombatCountdownService } from '@app/services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from '@app/services/countdown/game/game-countdown.service';
import { GameCreationService } from '@app/services/game-creation/game-creation.service';
import { GameManagerService } from '@app/services/game-manager/game-manager.service';
import { ItemsManagerService } from '@app/services/items-manager/items-manager.service';
import { JournalService } from '@app/services/journal/journal.service';
import { TIME_LIMIT_DELAY } from '@common/constants';
import { ChallengeEvent } from '@common/events/challenge.events';
import { CombatEvents, CombatFinishedData } from '@common/events/combat.events';
import { CountdownEvents } from '@common/events/countdown.events';
import {
    GameCreationEvents,
    JoinGameData,
    KickPlayerData,
    ToggleGameLockStateData,
    UpdateAudioSettingsData,
} from '@common/events/game-creation.events';
import { GameTurnEvents } from '@common/events/game-turn.events';
import { Game, GameCtf, GameEndReason, Player } from '@common/game';
import { Mode } from '@common/map.types';
import { Inject } from '@nestjs/common';
import { SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { FriendsService } from '../../../../http/services/friends/friends.service';
import { UserService } from '../../../../http/services/user/user.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';
import { ShopGateway } from '../shop/shop.gateway';
import { GameManagerGateway } from '../game-manager/game-manager.gateway';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class GameGateway {
    @WebSocketServer()
    server: Server;

    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameCountdownService) private readonly gameCountdownService: GameCountdownService;
    @Inject(CombatCountdownService) private readonly combatCountdownService: CombatCountdownService;
    @Inject(CombatService) private readonly combatService: CombatService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(UserSocketService) private readonly userSocketSession: UserSocketService;
    @Inject(FriendsService) private readonly friendsService: FriendsService;
    @Inject(UserService) private readonly userService: UserService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(ItemsManagerService) private readonly itemsManagerService: ItemsManagerService;
    @Inject(ShopGateway) private readonly shopGateway: ShopGateway;
    @Inject(GameManagerGateway) private readonly gameManagerGateway: GameManagerGateway;

    @SubscribeMessage(GameCreationEvents.CreateGame)
    async handleCreateGame(client: Socket, newGame: Game): Promise<void> {
        // Clean up any previous game rooms before creating a new one
        await this.cleanupSocketGameRooms(client);
        
        client.join(newGame.id);
        (client as any).currentGameId = newGame.id;
        console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} created and joined game: ${newGame.id}`);
        newGame.hostSocketId = client.id;
        const userId = this.userSocketSession.getUserIdBySocket(client.id);

        if (userId && newGame.settings?.entryFee > 0) {
            const paymentSuccess = await this.gameCreationService.chargeHostForGameCreation(userId, newGame.id, newGame.settings.entryFee);
            if (!paymentSuccess) {
                client.emit(
                    GameCreationEvents.GameCreationError,
                    `Vous n'avez pas assez de monnaie virtuelle pour créer cette partie. Frais d'entrée: ${newGame.settings.entryFee}`,
                );
                return;
            }

            await this.shopGateway.notifyMoneyUpdate(userId);
        }
        this.gameCreationService.addGame(newGame);
        const initialPlayer = newGame.players[0];
        if (initialPlayer) {
            this.challengeService.assignForPlayer(newGame, initialPlayer);
            initialPlayer.wasActivePlayer = true;
        }
        this.server.to(newGame.id).emit(GameCreationEvents.GameCreated, newGame);
        this.server.emit(GameCreationEvents.GameListUpdated);
    }

    @SubscribeMessage(GameCreationEvents.JoinGame)
    async handleJoinGame(client: Socket, data: JoinGameData): Promise<void> {
        // Clean up any previous game rooms before joining a new one
        await this.cleanupSocketGameRooms(client);

        if (this.gameCreationService.doesGameExist(data.gameId)) {
            let game = this.gameCreationService.getGameById(data.gameId);
            if ((game.hasStarted && !game.settings.isDropInOut) || (game.isLocked && !game.hasStarted)) {
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

            let userId: string | undefined;
            if (!data.player.socketId.includes('virtualPlayer')) {
                userId = this.userSocketSession.getUserIdBySocket(client.id);
            }

            const result = await this.gameCreationService.addPlayerToGame(client.id, data.player, data.gameId, userId);
            if (!result.success) {
                client.emit(GameCreationEvents.GameLocked, result.message);
                return;
            }

            if (userId && game.settings?.entryFee > 0 && !game.hasStarted) {
                await this.shopGateway.notifyMoneyUpdate(userId);
            }

            game = result.game!;
            if (this.gameCreationService.isMaxPlayersReached(data.gameId)) {
                this.gameCreationService.lockGame(data.gameId);
            }

            const newPlayer = game.players.find((player) => player.socketId === client.id);
            if (!newPlayer) {
                client.emit(GameCreationEvents.GameNotFound, 'Erreur lors de la connexion au jeu.');
                return;
            }

            const user = await this.userService.findByUsername(newPlayer.name);
            newPlayer.level = user.stats.level ?? 1;

            if (game.hasStarted) {
                const activePlayers = game.players.filter((plyr) => plyr.isActive && !plyr.isObserver);
                let positionInitialized = false;
                for (const tile of game.startTiles) {
                    const isOccupiedTile = activePlayers.some((plyr) => this.gameCreationService.sameCoords(plyr.position, tile.coordinate));
                    if (!isOccupiedTile) {
                        newPlayer.initialPosition = tile.coordinate;
                        newPlayer.position = tile.coordinate;
                        positionInitialized = true;
                        this.handleCtfPlayerStartTile(game, client, tile.coordinate);
                        break;
                    }
                }
                if (!positionInitialized) {
                    for (const player of activePlayers) {
                        const closestInitialPosition = this.combatService.findClosestAvailablePosition(player.initialPosition, game);
                        if (closestInitialPosition) {
                            newPlayer.initialPosition = player.initialPosition;
                            newPlayer.position = closestInitialPosition;
                            positionInitialized = true;
                            this.handleCtfPlayerStartTile(game, client, player.initialPosition);
                            break;
                        }
                    }
                }
            }
            if (game.hasStarted) {
                this.gameCreationService.recalculateTurnOrder(game);
            }
            
            // Join the game room and track current game
            client.join(data.gameId);
            (client as any).currentGameId = data.gameId;
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} joined game: ${data.gameId}`);
            
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
            } else if (!newPlayer.socketId.includes('virtual') && !newPlayer.isEliminated) {
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
    async handleKickPlayer(client: Socket, data: KickPlayerData): Promise<void> {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (!game) {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
            return;
        }

        const kickedPlayer = game.players.find((player) => player.socketId === data.playerId);
        let kickedUserId: string | undefined;

        if (kickedPlayer && !kickedPlayer.socketId.includes('virtualPlayer')) {
            kickedUserId = this.userSocketSession.getUserIdBySocket(data.playerId);
        }

        const { refundAmount } = await this.gameCreationService.handlePlayerKicked(data.gameId, data.playerId, kickedUserId);

        if (refundAmount > 0 && kickedUserId) {
            console.log(`[KickPlayer] Refunding ${refundAmount} to kicked user ${kickedUserId}`);
            await this.shopGateway.notifyMoneyUpdate(kickedUserId);
        }
        game.players = game.players.filter((player) => player.socketId !== data.playerId);
        if (!this.gameCreationService.isMaxPlayersReached(data.gameId)) {
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
    getGames(client: Socket): Game[] {
        const games = this.gameCreationService.getGames();
        client.emit(GameCreationEvents.GetGames, games);
        return games;
    }

    @SubscribeMessage(GameCreationEvents.AccessGame)
    async handleAccessGame(client: Socket, gameId: string): Promise<void> {
        // Clean up any previous game rooms before accessing a new one
        await this.cleanupSocketGameRooms(client);

        if (this.gameCreationService.doesGameExist(gameId)) {
            const game = this.gameCreationService.getGameById(gameId);
            if (game.settings.isFriendsOnly) {
                const userId = this.userSocketSession.getUserIdBySocket(client.id);
                if (userId) {
                    const user = await this.userService.findById(userId);
                    if (user) {
                        const isAuthorized = await this.checkIfPlayerCanJoinFriendsOnlyGame(game, user.username);
                        if (!isAuthorized) {
                            client.emit(GameCreationEvents.GameLocked, "Cette partie est réservée aux amis de l'organisateur.");
                            return;
                        }
                    }
                }
            }
            if (game.hasStarted && !game.settings.isDropInOut) {
                client.emit(GameCreationEvents.GameLocked, "Vous n'avez pas été assez rapide...\nLa partie a déjà commencé.");
                return;
            } else if (game.hasStarted && game.settings.isDropInOut) {
                // Allow access for drop-in/drop-out - detailed capacity checks (including eliminated players)
                // will be done in handleResumeGame where we know the player identity
                client.join(gameId);
                (client as any).currentGameId = gameId;
                console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} joined game (drop-in): ${gameId}`);
                client.emit(GameCreationEvents.GameAccessed, game.id);
                // Sync timer state for drop-in player
                this.syncTimerState(client, gameId);
                return;
            } else if (game.isLocked) {
                client.emit(GameCreationEvents.GameLocked, 'La partie est vérouillée, veuillez réessayer plus tard.');
                return;
            }

            client.join(gameId);
            (client as any).currentGameId = gameId;
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} joined game: ${gameId}`);
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

                const invalidPlayers = game.players.filter((player) => player.turn === undefined || player.turn === null);
                if (invalidPlayers.length > 0) {
                    console.error(
                        `[GameCreationGateway] Game ${roomId} has ${invalidPlayers.length} players with invalid turns:`,
                        invalidPlayers.map((p) => ({ name: p.name, turn: p.turn, socketId: p.socketId })),
                    );
                    client.emit(GameCreationEvents.GameCreationError, "Erreur lors de l'initialisation du jeu. Veuillez réessayer.");
                    return;
                }

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

    @SubscribeMessage(GameCreationEvents.UpdateAudioSettings)
    handleUpdateAudioSettings(client: Socket, data: UpdateAudioSettingsData): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (game && game.hostSocketId === client.id) {
            this.server.to(game.id).emit(GameCreationEvents.AudioSettingsUpdated, {
                musicEnabled: data.musicEnabled,
                sfxEnabled: data.sfxEnabled,
                ...(data.equippedMusic && { equippedMusic: data.equippedMusic }),
            });
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
    async handleLeaveGame(client: Socket, gameId: string): Promise<void> {
        // Defensive cleanup - ensure socket leaves all game rooms
        console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} leaving game: ${gameId}`);
        await this.cleanupSocketGameRooms(client);
        
        let game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            // Game doesn't exist - cleanup already done above
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} - game ${gameId} not found (already cleaned up)`);
            return;
        }
        const userId = this.userSocketSession.getUserIdBySocket(client.id);
        const isHost = this.gameCreationService.isPlayerHost(client.id, game.id);
        if (!game.hasStarted) {
            if (isHost) {
                const { refundedUsers } = await this.gameCreationService.refundAllPlayersInGame(gameId);
                for (const refundedUserId of refundedUsers) {
                    await this.shopGateway.notifyMoneyUpdate(refundedUserId);
                }
                this.server.to(game.id).emit(GameCreationEvents.GameClosed);
                await this.gameCreationService.deleteRoom(game.id);
                this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
                this.gameCountdownService.deleteCountdown(game.id); // Clean up timers if any
                this.combatCountdownService.deleteCountdown(game.id);
                this.server.emit(GameCreationEvents.GameListUpdated);
                return;
            } else {
                const { refundAmount } = await this.gameCreationService.handlePlayerLeaving(client, gameId, userId);

                if (refundAmount > 0 && userId) {
                    await this.shopGateway.notifyMoneyUpdate(userId);
                }
                game.players = game.players.filter((player) => player.socketId !== client.id);
                if (!this.gameCreationService.isMaxPlayersReached(game.id)) {
                    game.isLocked = false;
                    this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
                }
                this.server.to(game.id).emit(GameCreationEvents.PlayerLeft, game.players);
                this.server.to(game.id).emit(GameCreationEvents.CurrentPlayers, game.players);
            }
        } else if (game.players.some((player) => player.socketId === client.id)) {
            const leavingPlayer = game.players.find((player) => player.socketId === client.id);

            if (leavingPlayer?.inventory?.length > 0) {
                this.itemsManagerService.dropInventory(leavingPlayer, gameId);
            }

            // Check if there's an active combat and handle it
            const combat = this.combatService.getCombatByGameId(gameId);
            if (combat && leavingPlayer) {
                const isInCombat = combat.challenger.socketId === client.id || combat.opponent.socketId === client.id;
                if (isInCombat) {
                    // Handle combat termination when player leaves during combat
                    await this.handleCombatPlayerLeft(client, game, leavingPlayer, combat);
                }
            }

            // If player was only an observer (never active participant) and was not eliminated, remove them from the game
            if (!leavingPlayer?.wasActivePlayer && leavingPlayer?.isObserver && !leavingPlayer?.isEliminated) {
                game.players = game.players.filter((player) => player.socketId !== client.id);
            } else {
                game.players = game.players.map((player) => {
                    if (player.socketId === client.id) {
                        // CRITICAL: Invalidate socketId to prevent turn events from being sent to this socket
                        // The socketId is used to send events directly, so we must invalidate it when player leaves
                        const invalidatedSocketId = `DISCONNECTED-${Date.now()}-${client.id}`;
                        console.log(`[GameGateway] Invalidating socketId for ${player.name} in game ${gameId}: ${client.id} -> ${invalidatedSocketId}`);
                        
                        // If game is in elimination mode, set player as eliminated
                        if (game.settings.isFastElimination && !player.isObserver) {
                            return { ...player, isActive: false, isEliminated: true, isObserver: false, socketId: invalidatedSocketId };
                        }
                        return { ...player, isActive: false, isObserver: false, socketId: invalidatedSocketId };
                    }
                    return player;
                });
            }

            if (game.hasStarted && !game.settings.isDropInOut && leavingPlayer?.initialPosition) {
                game.startTiles = game.startTiles.filter(
                    (tile) => tile.coordinate.x !== leavingPlayer.initialPosition.x || tile.coordinate.y !== leavingPlayer.initialPosition.y,
                );
            }

            game.isLocked = false;
            this.server.to(game.id).emit(GameCreationEvents.GameLockToggled, game.isLocked);
            // Room cleanup already done at method start
            this.server.to(game.id).emit(GameCreationEvents.PlayerLeft, game.players);

            // Check if leaving player was in their turn and advance turn if not in combat
            if (game.hasStarted && leavingPlayer) {
                const combat = this.combatService.getCombatByGameId(game.id);
                if (!combat && game.currentTurn === leavingPlayer.turn) {
                    // Player is in their turn and not in combat - automatically finish their turn so next player can play
                    console.log(`[GameGateway] Player ${leavingPlayer.name} left during their turn. Automatically finishing turn.`);
                    this.gameManagerGateway.prepareNextTurn(game.id);
                }
            }

            // Check if game should end after player leaves
            if (game.hasStarted && (game.mode === Mode.Ctf || game.mode === Mode.Classic)) {
                const activeNonObserverCount = game.players.filter((p) => p.isActive && !p.isEliminated && !p.isObserver).length;

                const endResult = this.gameManagerService.checkAfterDisconnect(game.id);
                if (endResult.reason !== 'ongoing') {
                    console.log(`[GameCreation] Game ending after player quit. Reason: ${endResult.reason}`);
                    await this.gameManagerService.handleGameEnd(game.id, endResult, this.server);
                    this.gameCountdownService.deleteCountdown(game.id);
                    this.combatCountdownService.deleteCountdown(game.id);
                    return; // Exit early, game is ended
                }
                if (activeNonObserverCount === 0) {
                    console.log(`[CTF] Last active player quit. Ending game ${game.id}`);
                    this.server.to(game.id).emit(GameCreationEvents.GameEndedNoActivePlayers);
                    this.gameCreationService.deleteRoom(game.id);
                }
            }
            this.server.to(game.id).emit(GameCreationEvents.GameUpdated, game);
        } else {
            // Player not found in game - room cleanup already done at method start
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} not found in game ${gameId} (already cleaned up)`);
            return;
        }
        this.server.emit(GameCreationEvents.GameListUpdated);
    }

    @SubscribeMessage(GameCreationEvents.ResumeGame)
    async handleResumeGame(client: Socket, data: JoinGameData): Promise<void> {
        // Clean up any previous game rooms before resuming
        await this.cleanupSocketGameRooms(client);

        if (this.gameCreationService.doesGameExist(data.gameId)) {
            const game = this.gameCreationService.getGameById(data.gameId);
            if (game.hasStarted) {
                const existingPlayer = game.players.find((plyr) => plyr.name === data.player.name);

                if (!existingPlayer) {
                    // New player (not in game.players) - check capacity before allowing
                    if (this.gameCreationService.isMaxPlayersReached(data.gameId)) {
                        client.emit(
                            GameCreationEvents.GameLocked,
                            'La partie a atteint son nombre de joueur maximal.\n Veuillez réessayez plus tard.',
                        );
                        return;
                    }
                    client.emit(GameCreationEvents.GameNotFound, 'Joueur introuvable dans cette partie.');
                    return;
                }

                // existingPlayer exists - allow them to rejoin regardless of capacity (they already have a slot)

                existingPlayer.socketId = client.id;
                // Only set isActive = true if player is not eliminated and not an observer
                if (!existingPlayer.isEliminated && !existingPlayer.isObserver) {
                    existingPlayer.isActive = true;
                }
                client.join(data.gameId);
                (client as any).currentGameId = data.gameId;
                console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} resumed game: ${data.gameId}`);
                client.emit(GameCreationEvents.GameResumed, game);

                client.emit(GameCreationEvents.YouJoined, { updatedPlayer: existingPlayer, updatedGame: game });
                this.server.to(data.gameId).emit(GameCreationEvents.PlayerJoined, game.players);
                this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);
                this.syncTimerState(client, data.gameId);

                const existingChallenge = this.challengeService.getPlayerChallenge(game.id, existingPlayer.name);
                if (existingChallenge) {
                    client.emit(ChallengeEvent.Updated, existingChallenge);
                }
            }
        } else {
            client.emit(GameCreationEvents.GameNotFound, 'La partie a été fermée.');
        }
    }

    @SubscribeMessage(GameCreationEvents.ObserveGame)
    async handleObserveGame(client: Socket, data: JoinGameData): Promise<void> {
        // Clean up any previous game rooms before observing
        await this.cleanupSocketGameRooms(client);

        if (this.gameCreationService.doesGameExist(data.gameId)) {
            const game = this.gameCreationService.getGameById(data.gameId);
            client.join(game.id);
            (client as any).currentGameId = game.id;
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} joined as observer: ${game.id}`);

            let existingPlayer = game.players.find((plyr) => plyr.name === data.player.name);
            if (existingPlayer) {
                existingPlayer.socketId = client.id;
                // Preserve existing elimination status - don't override it
                existingPlayer.isActive = false;
                existingPlayer.isObserver = true;
            } else {
                // Add new observer player
                data.player.socketId = client.id;
                data.player.isEliminated = false;
                data.player.isActive = false;
                data.player.isObserver = true;
                data.player.wasActivePlayer = false;
                game.players.push(data.player);
            }

            const observerPlayer = game.players.find((plyr) => plyr.name === data.player.name);
            client.emit(GameCreationEvents.YouJoined, { updatedPlayer: observerPlayer, updatedGame: game });
            this.server.to(data.gameId).emit(GameCreationEvents.PlayerJoined, game.players);
            this.server.to(data.gameId).emit(GameCreationEvents.CurrentPlayers, game.players);

            // Emit GameUpdated to ensure all clients have consistent state
            this.server.to(data.gameId).emit(GameCreationEvents.GameUpdated, game);

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

    private handleCtfPlayerStartTile(game: Game, player: Socket, coordinate: { x: number; y: number }): void {
        if (game.mode === Mode.Ctf) {
            const ctfGame = game as GameCtf;
            if (ctfGame.playerStartTiles) {
                const existingEntry = ctfGame.playerStartTiles.find((entry) => entry.socketId === player.id);
                if (!existingEntry) {
                    ctfGame.playerStartTiles.push({
                        socketId: player.id,
                        coordinate: coordinate,
                    });
                }
            }
        }
    }

    /**
     * Removes a socket from all game-related rooms to prevent receiving events from previous games.
     * This is a defensive cleanup that ensures the socket starts fresh when joining a new game.
     */
    private async cleanupSocketGameRooms(client: Socket): Promise<void> {
        const previousGame = (client as any).currentGameId;
        
        // Get all rooms this socket is in
        const rooms = Array.from(client.rooms);
        
        // Filter out the default room (socket.id itself) - keep only game rooms
        const gameRooms = rooms.filter(room => room !== client.id);
        
        if (gameRooms.length > 0) {
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} cleaning up ${gameRooms.length} room(s)${previousGame ? ` (previous game: ${previousGame})` : ''}`);
        }
        
        // Leave all game-related rooms
        for (const room of gameRooms) {
            client.leave(room);
            console.log(`[GameGateway] Socket ${client.id.substring(0, 8)} left room: ${room}`);
        }
        
        // Clear the tracked game ID
        delete (client as any).currentGameId;
    }

    /**
     * Handles combat termination when a player leaves the game during combat.
     * The other player in the combat is declared the winner.
     */
    private async handleCombatPlayerLeft(
        client: Socket,
        game: Game,
        leavingPlayer: Player,
        combat: { challenger: Player; opponent: Player; id: string; currentTurnSocketId: string },
    ): Promise<void> {
        const isChallenger = combat.challenger.socketId === client.id;
        const winner = isChallenger ? combat.opponent : combat.challenger;
        const loser = isChallenger ? combat.challenger : combat.opponent;

        console.log(`[GameGateway] Player ${leavingPlayer.name} left during combat. Winner: ${winner.name}`);

        // Set leaving player as inactive
        loser.isActive = false;

        // Handle elimination mode
        if (game.settings.isFastElimination) {
            loser.isEliminated = true;
            const playerInGame = game.players.find((p) => p.socketId === loser.socketId);
            if (playerInGame) {
                playerInGame.isEliminated = true;
                playerInGame.isActive = false;
            }
        }

        // Update combat stats
        this.combatService.combatWinStatsUpdate(winner, game.id);
        this.combatService.updatePlayersInGame(game);

        // Notify all players in combat room that combat finished by disconnection
        this.server.to(combat.id).emit(CombatEvents.CombatFinishedByDisconnection, winner);

        // Log the event
        this.journalService.logMessage(game.id, `${leavingPlayer.name} a quitté pendant le combat. ${winner.name} gagne par forfait.`, [
            winner.name,
            leavingPlayer.name,
        ]);

        // Delete combat countdown
        this.combatCountdownService.deleteCountdown(game.id);

        // Schedule post-combat cleanup and game flow continuation
        setTimeout(async () => {
            const currentGame = this.gameCreationService.getGameById(game.id);
            if (!currentGame) {
                console.warn(`[GameGateway] handleCombatPlayerLeft setTimeout: Game ${game.id} not found (likely already ended)`);
                return;
            }

            // Emit combat finished event to all players in the game
            const combatFinishedData: CombatFinishedData = { updatedGame: currentGame, winner: winner, loser: loser };
            this.server.to(currentGame.id).emit(CombatEvents.CombatFinished, combatFinishedData);

            // Check if combat resulted in game end
            const endResult = this.gameManagerService.checkAfterCombat(currentGame.id, winner, currentGame.settings.isFastElimination);

            if (endResult.reason !== GameEndReason.Ongoing) {
                this.gameManagerService.handleGameEnd(currentGame.id, endResult, this.server);
                this.combatService.deleteCombat(currentGame.id);
                await this.cleanupCombatRoom(combat.id);
                this.gameCountdownService.deleteCountdown(currentGame.id);
                return;
            }

            // Game continues - handle post-combat flow
            if (currentGame.currentTurn === winner.turn) {
                this.gameCountdownService.resumeCountdown(currentGame.id);
                if (!winner.socketId.includes('virtual')) {
                    // Safety check: Don't emit to invalidated/disconnected socketIds
                    if (!winner.socketId.startsWith('DISCONNECTED-')) {
                        this.server.to(winner.socketId).emit(CombatEvents.ResumeTurnAfterCombatWin);
                        // Check if winner is stuck after combat
                        if (this.gameManagerService.isPlayerStuck(currentGame.id, winner.socketId)) {
                            console.log(`[GameGateway] Player ${winner.name} is stuck after combat. Auto-ending turn.`);
                            this.gameCountdownService.emit(CountdownEvents.Timeout, currentGame.id);
                        }
                    } else {
                        console.log(`[GameGateway] Skipping ResumeTurnAfterCombatWin emission to invalidated socketId: ${winner.socketId} (player: ${winner.name})`);
                        // If winner is disconnected, auto-timeout the turn
                        this.gameCountdownService.emit(CountdownEvents.Timeout, currentGame.id);
                    }
                }
            } else {
                // Not winner's turn, trigger timeout to move to next turn
                this.gameCountdownService.emit(CountdownEvents.Timeout, currentGame.id);
            }

            // Clean up combat
            this.combatService.deleteCombat(currentGame.id);
            await this.cleanupCombatRoom(combat.id);
        }, TIME_LIMIT_DELAY);
    }

    /**
     * Cleans up the combat room by removing all sockets from it.
     */
    private async cleanupCombatRoom(combatRoomId: string): Promise<void> {
        const sockets = await this.server.in(combatRoomId).fetchSockets();
        for (const socket of sockets) {
            socket.leave(combatRoomId);
        }
    }
}
