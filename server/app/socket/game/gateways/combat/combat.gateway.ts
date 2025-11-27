import { CombatService } from '@app/services/combat/combat.service';
import { Combat } from '@common/combat';
import { EVASION_SUCCESS_RATE, TIME_LIMIT_DELAY } from '@common/constants';
import {
    CombatEvents,
    CombatFinishedByEvasionData,
    CombatFinishedData,
    PlayerEnteredObservationModeData,
    StartCombatData,
} from '@common/events/combat.events';
import { CountdownEvents } from '@common/events/countdown.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { ItemDroppedData, ItemsEvents } from '@common/events/items.events';
import { Game, GameEndReason, Player } from '@common/game';
import { Inject } from '@nestjs/common';
import { OnGatewayDisconnect, OnGatewayInit, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChallengeService } from '../../../../services/challenge/challenge.service';
import { CombatCountdownService } from '../../../../services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from '../../../../services/countdown/game/game-countdown.service';
import { GameCreationService } from '../../../../services/game-creation/game-creation.service';
import { GameManagerService } from '../../../../services/game-manager/game-manager.service';
import { ItemsManagerService } from '../../../../services/items-manager/items-manager.service';
import { JournalService } from '../../../../services/journal/journal.service';
import { VirtualGameManagerService } from '../../../../services/virtual-game-manager/virtual-game-manager.service';
import { GameManagerGateway } from '../game-manager/game-manager.gateway';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class CombatGateway implements OnGatewayInit, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    @Inject(ItemsManagerService) private readonly itemsManagerService: ItemsManagerService;
    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(VirtualGameManagerService) private readonly virtualGameManager: VirtualGameManagerService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(GameManagerGateway) private readonly gameManagerGateway: GameManagerGateway;

    constructor(
        private readonly combatService: CombatService,
        private readonly gameCountdownService: GameCountdownService,
        private readonly combatCountdownService: CombatCountdownService,
    ) {
        this.combatService = combatService;
        this.combatCountdownService = combatCountdownService;
        this.gameCountdownService = gameCountdownService;
    }

    afterInit() {
        this.combatCountdownService.setServer(this.server);
        this.combatService.setServer(this.server);
        this.combatCountdownService.on('timeout', (gameId: string) => {
            this.attackOnTimeOut(gameId);
        });
    }

    @SubscribeMessage(CombatEvents.StartCombat)
    async startCombat(client: Socket, data: StartCombatData): Promise<void> {
        try {
            const validation = this.validateCombatStart(data);
            if (!validation) {
                return;
            }

            const { game, player } = validation;

            const combat = this.combatService.createCombat(data.gameId, player, data.opponent);
            this.itemsManagerService.checkForAmulet(player, data.opponent);
            await client.join(combat.id);

            const opponentSocketSetup = await this.setupOpponentSocket(data, combat.id);

            if (opponentSocketSetup) {
                await this.addObserversToCombat(game, combat.id);
                this.initializeCombat(data, combat, player, client.id);
            }
        } catch (error) {
            console.error(`[CombatGateway] Error starting combat:`, error);
            this.gameManagerService.logGameStateDebug(data.gameId, 'StartCombatError');
            this.cleanupFailedCombat(data.gameId, undefined);
        }
    }

    @SubscribeMessage(CombatEvents.Attack)
    attack(client: Socket, gameId: string): void {
        this.attackOnTimeOut(gameId);
    }

    @SubscribeMessage(CombatEvents.StartEvasion)
    async startEvasion(client: Socket, gameId: string): Promise<void> {
        const combat = this.combatService.getCombatByGameId(gameId);
        if (!combat || client.id !== combat.currentTurnSocketId) {
            return;
        }

        const evadingPlayer: Player = combat.challenger.socketId === client.id ? combat.challenger : combat.opponent;
        const otherPlayer: Player = combat.challenger.socketId === evadingPlayer.socketId ? combat.opponent : combat.challenger;

        if (evadingPlayer.specs.evasions === 0) {
            return;
        }

        evadingPlayer.specs.nEvasions++;
        evadingPlayer.specs.evasions--;
        const evasionSuccess = Math.random() < EVASION_SUCCESS_RATE;

        if (evasionSuccess) {
            this.handleEvasionSuccess(evadingPlayer, otherPlayer, gameId, combat);
        } else {
            this.handleEvasionFailure(evadingPlayer, gameId, combat.id);
        }
    }

    attackOnTimeOut(gameId: string) {
        try {
            const combat = this.combatService.getCombatByGameId(gameId);
            if (!combat) {
                console.warn(`[CombatGateway] attackOnTimeOut: Combat not found for game ${gameId}`);
                return;
            }

            const { attackingPlayer, defendingPlayer } = this.getAttackingAndDefendingPlayers(combat);

            if (!attackingPlayer || !defendingPlayer) {
                console.warn(`[CombatGateway] attackOnTimeOut: Invalid players in combat`);
                this.cleanupFailedCombat(gameId, combat.id);
                return;
            }

            const rollResult = this.executeDiceRoll(attackingPlayer, defendingPlayer, combat.id);
            this.processAttackResult(attackingPlayer, defendingPlayer, rollResult, combat.id, gameId);
            this.determineNextCombatStep(defendingPlayer, attackingPlayer, gameId, combat.id);
        } catch (error) {
            console.error(`[CombatGateway] Error in attackOnTimeOut for game ${gameId}:`, error);
            this.gameManagerService.logGameStateDebug(gameId, 'AttackOnTimeOutError');
            this.cleanupFailedCombat(gameId, this.combatService.getCombatByGameId(gameId)?.id);
        }
    }

    handleCombatLost(defendingPlayer: Player, attackingPlayer: Player, gameId: string, combatId: string) {
        try {
            const game = this.gameCreationService.getGameById(gameId);
            if (!game) {
                console.warn(`[CombatGateway] handleCombatLost: Game ${gameId} not found`);
                this.cleanupFailedCombat(gameId, combatId);
                return;
            }

            this.combatService.combatWinStatsUpdate(attackingPlayer, gameId);
            this.itemsManagerService.dropInventory(defendingPlayer, gameId);

            if (defendingPlayer.position?.x === undefined || defendingPlayer.position.y === undefined) {
                console.warn(`[CombatGateway] Defending player ${defendingPlayer.name} has invalid position, recovering...`);
                if (defendingPlayer.initialPosition) {
                    defendingPlayer.position = { x: defendingPlayer.initialPosition.x, y: defendingPlayer.initialPosition.y };
                    console.log(
                        `[CombatGateway] ✓ Recovered position for ${defendingPlayer.name} at (${defendingPlayer.position.x}, ${defendingPlayer.position.y})`,
                    );
                }
            }

            if (game.settings.isFastElimination) {
                this.setPlayerToEliminated(defendingPlayer, game);

                const endResult = this.gameManagerService.checkAfterCombat(gameId, attackingPlayer, game.settings.isFastElimination);

                if (endResult.reason === GameEndReason.Ongoing) {
                    this.notifyPlayerEnteredObservationMode(defendingPlayer, 'Vous avez perdu le combat et êtes maintenant en mode observation.');
                }
            } else {
                const winnerPosition = attackingPlayer.position ? { x: attackingPlayer.position.x, y: attackingPlayer.position.y } : null;
                this.combatService.sendBackToInitPos(defendingPlayer, game);
                if (winnerPosition) {
                    attackingPlayer.position = winnerPosition;
                }
            }

            this.combatService.updatePlayersInGame(game);

            this.server.to(combatId).emit(CombatEvents.CombatFinishedNormally, attackingPlayer);
            this.journalService.logMessage(gameId, `Fin de combat. ${attackingPlayer.name} est le gagnant.`, [attackingPlayer.name]);

            // Emit updated game state immediately so all players see the elimination change right away
            const combatFinishedData: CombatFinishedData = { updatedGame: game, winner: attackingPlayer, loser: defendingPlayer };
            this.server.to(gameId).emit(CombatEvents.CombatFinished, combatFinishedData);

            this.combatCountdownService.deleteCountdown(gameId);
            setTimeout(() => {
                const game = this.gameCreationService.getGameById(gameId);
                if (!game) {
                    console.warn(`[CombatGateway] handleCombatLost setTimeout: Game ${gameId} not found (likely already ended)`);
                    return;
                }

                // Check if combat resulted in game end
                const endResult = this.gameManagerService.checkAfterCombat(gameId, attackingPlayer, game.settings.isFastElimination);

                if (endResult.reason !== GameEndReason.Ongoing) {
                    this.gameManagerService.handleGameEnd(gameId, endResult, this.server);
                    this.combatService.deleteCombat(gameId);
                    this.cleanupCombatRoom(combatId);
                    this.gameCountdownService.deleteCountdown(gameId);
                    return;
                }

                // Game continues
                this.handlePostCombatGameFlow(game, attackingPlayer, combatId);
            }, TIME_LIMIT_DELAY);
        } catch (error) {
            console.error(`[CombatGateway] Error in handleCombatLost:`, error);
            this.gameManagerService.logGameStateDebug(gameId, 'HandleCombatLostError');
            this.cleanupFailedCombat(gameId, combatId);
        }
    }

    prepareNextTurn(gameId: string) {
        const combat = this.combatService.getCombatByGameId(gameId);
        const game = this.gameCreationService.getGameById(gameId);

        // Failsafe: Check if game or combat still exists before preparing next turn
        if (!game) {
            if (combat) {
                this.combatCountdownService.deleteCountdown(gameId);
            }
            return;
        }

        if (combat) {
            this.combatService.updateTurn(gameId);
            this.combatCountdownService.resetTimerSubscription(gameId);
            this.startCombatTurns(gameId);
        }
    }

    startCombatTurns(gameId: string): void {
        const combat = this.combatService.getCombatByGameId(gameId);
        const result = this.combatService.startCombatTurns(gameId, this.combatCountdownService, this.gameCreationService);

        if (result && combat && combat.currentTurnSocketId.includes('virtual')) {
            this.handleVirtualPlayerTurn(result.currentPlayer, result.otherPlayer, gameId, combat);
        }
    }

    async cleanupCombatRoom(combatRoomId: string): Promise<void> {
        const sockets = await this.server.in(combatRoomId).fetchSockets();
        for (const socketId of sockets) {
            socketId.leave(combatRoomId);
        }
    }

    /**
     * Gets the attacking and defending players based on current turn
     */
    private getAttackingAndDefendingPlayers(combat: Combat): { attackingPlayer: Player; defendingPlayer: Player } {
        const attackingPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.challenger : combat.opponent;
        const defendingPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.opponent : combat.challenger;
        return { attackingPlayer, defendingPlayer };
    }

    /**
     * Sets a player as eliminated in both combat and game
     */
    private setPlayerToEliminated(player: Player, game: Game): void {
        player.isEliminated = true;
        player.isActive = false;
        const playerInGame = game.players.find((p) => p.socketId === player.socketId);
        if (playerInGame) {
            playerInGame.isEliminated = true;
            playerInGame.isActive = false;
        }
        console.log(`[ELIMINATION DEBUG] Player ${player.name} set as eliminated (isEliminated: ${player.isEliminated})`);
    }

    /**
     * Notifies a player they have been eliminated
     */
    private notifyPlayerEnteredObservationMode(player: Player, message: string): void {
        const observationModeData: PlayerEnteredObservationModeData = {
            player,
            message,
        };
        this.server.to(player.socketId).emit(CombatEvents.PlayerEnteredObservationMode, observationModeData);
    }

    /**
     * Validates combat start conditions
     */
    private validateCombatStart(data: StartCombatData): { game: Game; player: Player } | null {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (!game) {
            console.warn(`[CombatGateway] startCombat: Game ${data.gameId} not found`);
            return null;
        }

        const player = game.players.find((player) => player.turn === game.currentTurn);
        if (!player || !player.position) {
            console.warn(`[CombatGateway] startCombat: Player not found or has no position`);
            return null;
        }

        if (!data.opponent || !data.opponent.position) {
            console.warn(`[CombatGateway] startCombat: Opponent not found or has no position`);
            return null;
        }

        if (player?.isEliminated === true || data.opponent?.isEliminated === true) {
            return null;
        }

        return { game, player };
    }

    /**
     * Sets up opponent socket for combat (handles virtual and real players)
     * Returns true if opponent socket was successfully set up
     */
    private async setupOpponentSocket(data: StartCombatData, combatId: string): Promise<boolean> {
        if (data.opponent.socketId.includes('virtual')) {
            return true;
        } else {
            const sockets = await this.server.in(data.gameId).fetchSockets();
            const opponentSocket = sockets.find((socket) => socket.id === data.opponent.socketId);
            if (opponentSocket) {
                await opponentSocket.join(combatId);
                return true;
            }
        }
        return false;
    }

    /**
     * Adds observer players to combat room
     */
    private async addObserversToCombat(game: Game, combatId: string): Promise<void> {
        const observers = game.players.filter((p) => p.isEliminated === true || p.isObserver === true);
        const sockets = await this.server.in(game.id).fetchSockets();
        for (const observer of observers) {
            const observerSocket = sockets.find((socket) => socket.id === observer.socketId);
            if (observerSocket) {
                await observerSocket.join(combatId);
            }
        }
    }

    /**
     * Initializes combat by emitting events and starting combat flow
     */
    private initializeCombat(data: StartCombatData, combat: Combat, player: Player, clientId: string): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (!game) {
            console.warn(`[CombatGateway] initializeCombat: Game ${data.gameId} not found`);
            return;
        }
        this.combatService.initializeCombat(
            combat,
            game,
            clientId,
            this.journalService,
            this.gameManagerService,
            this.combatCountdownService,
            this.gameCountdownService,
            clientId,
        );
        this.startCombatTurns(data.gameId);
    }

    /**
     * Executes dice roll and emits results
     */
    private executeDiceRoll(attackingPlayer: Player, defendingPlayer: Player, combatId: string): any {
        const rollResult = this.combatService.rollDice(attackingPlayer, defendingPlayer);
        this.server.to(combatId).emit(CombatEvents.DiceRolled, rollResult);
        return rollResult;
    }

    /**
     * Processes attack result (success or failure)
     */
    private processAttackResult(attackingPlayer: Player, defendingPlayer: Player, rollResult: any, combatId: string, gameId: string): void {
        const attackResult = this.combatService.attackResult(attackingPlayer, defendingPlayer, rollResult);
        if (attackResult > 0) {
            this.combatService.handleAttackSuccess(attackingPlayer, defendingPlayer, combatId, gameId, attackResult);
        } else {
            this.server.to(combatId).emit(CombatEvents.AttackFailure, defendingPlayer);

            // Track dodged attack for challenge
            const game = this.gameCreationService.getGameById(gameId);
            if (game) {
                this.challengeService.onAttackDodged(game, defendingPlayer);
            }
        }
    }

    /**
     * Determines next combat step based on defending player's life
     */
    private determineNextCombatStep(defendingPlayer: Player, attackingPlayer: Player, gameId: string, combatId: string): void {
        if (defendingPlayer.specs.life <= 0) {
            this.handleCombatLost(defendingPlayer, attackingPlayer, gameId, combatId);
        } else {
            this.prepareNextTurn(gameId);
        }
    }

    /**
     * Handles successful evasion
     */
    private handleEvasionSuccess(evadingPlayer: Player, otherPlayer: Player, gameId: string, combat: Combat): void {
        const game = this.gameCreationService.getGameById(gameId);
        this.combatService.updatePlayersInGame(game);
        this.server.to(combat.id).emit(CombatEvents.EvasionSuccess, evadingPlayer);
        // this.journalService.logMessage(gameId, `Fin de combat. ${evadingPlayer.name} s'est évadé.`, [evadingPlayer.name]);
        this.combatCountdownService.deleteCountdown(gameId);

        setTimeout(async () => {
            const game = this.gameCreationService.getGameById(gameId);
            if (!game) {
                console.warn(`[CombatGateway] startEvasion setTimeout: Game ${gameId} not found (likely already ended)`);
                return;
            }
            const combatFinishedByEvasionData: CombatFinishedByEvasionData = { updatedGame: game, evadingPlayer: evadingPlayer };
            this.server.to(gameId).emit(CombatEvents.CombatFinishedByEvasion, combatFinishedByEvasionData);
            this.gameCountdownService.resumeCountdown(gameId);
            this.cleanupCombatRoom(combat.id);
            this.combatService.deleteCombat(gameId);

            if (otherPlayer.socketId.includes('virtual') && game.currentTurn === otherPlayer.turn) {
                await this.virtualGameManager.executeVirtualPlayerBehavior(otherPlayer, game);
            } else if (game.currentTurn === otherPlayer.turn) {
                // Safety check: Don't emit to invalidated/disconnected socketIds
                if (!otherPlayer.socketId.startsWith('DISCONNECTED-')) {
                    this.server.to(otherPlayer.socketId).emit(CombatEvents.ResumeTurnAfterCombatWin);
                    if (this.gameManagerService.isPlayerStuck(game.id, otherPlayer.socketId)) {
                        this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
                    }
                } else {
                    console.log(`[CombatGateway] Skipping ResumeTurnAfterCombatWin emission to invalidated socketId: ${otherPlayer.socketId} (player: ${otherPlayer.name})`);
                    // If player is disconnected, auto-timeout the turn
                    this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
                }
            }
        }, TIME_LIMIT_DELAY);
    }

    /**
     * Handles failed evasion
     */
    private handleEvasionFailure(evadingPlayer: Player, gameId: string, combatId: string): void {
        this.server.to(combatId).emit(CombatEvents.EvasionFailed, evadingPlayer);
        this.prepareNextTurn(gameId);
    }

    /**
     * Handles post-combat game flow (resume turn or timeout)
     */
    private handlePostCombatGameFlow(game: Game, winner: Player, combatId: string): void {
        if (game.currentTurn === winner.turn) {
            this.gameCountdownService.resumeCountdown(game.id);
            if (winner.socketId.includes('virtual')) {
                // Virtual player won and can continue their turn
                this.virtualGameManager.executeVirtualPlayerBehavior(winner, game);
            } else {
                // Safety check: Don't emit to invalidated/disconnected socketIds
                if (!winner.socketId.startsWith('DISCONNECTED-')) {
                    this.server.to(winner.socketId).emit(CombatEvents.ResumeTurnAfterCombatWin);
                    // Check if winner is stuck after combat
                    if (this.gameManagerService.isPlayerStuck(game.id, winner.socketId)) {
                        console.log(`[CombatGateway] Player ${winner.name} is stuck after combat. Auto-ending turn.`);
                        this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
                    }
                } else {
                    console.log(`[CombatGateway] Skipping ResumeTurnAfterCombatWin emission to invalidated socketId: ${winner.socketId} (player: ${winner.name})`);
                    // If winner is disconnected, auto-timeout the turn
                    this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
                }
            }
        } else {
            this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
        }
        this.combatService.deleteCombat(game.id);
        this.cleanupCombatRoom(combatId);
    }

    /**
     * Handles virtual player's combat turn
     */
    private handleVirtualPlayerTurn(currentPlayer: Player, otherPlayer: Player, gameId: string, combat: Combat): void {
        setTimeout(() => {
            const isCombatFinishedByEvasion = this.virtualGameManager.handleVirtualPlayerCombat(currentPlayer, otherPlayer, gameId, combat);
            if (otherPlayer.specs.life <= 0) {
                this.handleCombatLost(otherPlayer, currentPlayer, gameId, combat.id);
                // Don't execute virtual player behavior here - it will be handled in handleCombatLost after checking for game winner
            } else if (isCombatFinishedByEvasion) {
                this.handleVirtualPlayerEvasionSuccess(currentPlayer, gameId, combat.id);
            } else {
                this.prepareNextTurn(gameId);
            }
        }, TIME_LIMIT_DELAY);
    }

    /**
     * Handles virtual player's successful evasion
     */
    private handleVirtualPlayerEvasionSuccess(currentPlayer: Player, gameId: string, combatId: string): void {
        setTimeout(async () => {
            const game = this.gameCreationService.getGameById(gameId);
            if (!game) {
                console.warn(`[CombatGateway] startCombatTurns virtual evasion setTimeout: Game ${gameId} not found (likely already ended)`);
                return;
            }
            const combatFinishedByEvasionData: CombatFinishedByEvasionData = { updatedGame: game, evadingPlayer: currentPlayer };
            this.server.to(gameId).emit(CombatEvents.CombatFinishedByEvasion, combatFinishedByEvasionData);
            this.gameCountdownService.resumeCountdown(gameId);
            this.cleanupCombatRoom(combatId);
            this.combatService.deleteCombat(gameId);

            if (this.gameCreationService.getGameById(gameId)?.currentTurn === currentPlayer.turn) {
                await this.virtualGameManager.executeVirtualPlayerBehavior(currentPlayer, game);
            }
        }, TIME_LIMIT_DELAY);
    }

    async handleDisconnect(client: Socket): Promise<void> {
        const games = this.gameCreationService.getGames();

        for (const game of games) {
            if (!game.hasStarted) {
                if (this.handleHostDisconnection(client, game)) {
                    return;
                }
            }

            const player = game.players.find((player) => player.socketId === client.id);
            if (player) {
                await this.handlePlayerDisconnection(client, game, player);
            }
        }
    }

    private handleHostDisconnection(client: Socket, game: Game): boolean {
        if (this.gameCreationService.isPlayerHost(client.id, game.id)) {
            this.server.to(game.id).emit(GameCreationEvents.GameClosed);
            this.gameCreationService.deleteRoom(game.id);
            this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
            this.gameCountdownService.deleteCountdown(game.id); // Clean up game timer
            this.combatCountdownService.deleteCountdown(game.id); // Clean up combat timer if exists
            this.server.emit(GameCreationEvents.GameListUpdated);
            return true;
        }
        return false;
    }

    private async handlePlayerDisconnection(client: Socket, game: Game, player: Player): Promise<void> {
        const { game: updatedGame } = await this.gameCreationService.handlePlayerLeaving(client, game.id);
        // Emit only to other players in the room, not to the disconnecting player
        client.to(updatedGame.id).emit(GameCreationEvents.PlayerLeft, updatedGame.players);

        if (updatedGame.hasStarted) {
            // Get the updated player from the game after handlePlayerLeaving
            const updatedPlayer = updatedGame.players.find((p) => p.socketId === client.id);

            // If game is in elimination mode, set player as eliminated
            if (updatedGame.settings.isFastElimination && updatedPlayer) {
                this.setPlayerToEliminated(updatedPlayer, updatedGame);
            }

            if (player.inventory && player.inventory.length > 0) {
                this.itemsManagerService.dropInventory(player, updatedGame.id);
                const itemDroppedData: ItemDroppedData = { updatedGame: game, updatedPlayer: player };
                this.server.to(game.id).emit(ItemsEvents.ItemDropped, itemDroppedData);
            }
            this.journalService.logMessage(game.id, `${player.name} a abandonné la partie.`, [player.name]);

            // Check if there's an ongoing combat and update stats before checking game termination
            const combat = this.combatService.getCombatByGameId(updatedGame.id);
            if (combat) {
                // Update combat stats before game potentially ends
                const winner = client.id === combat.challenger.socketId ? combat.opponent : combat.challenger;
                
                this.combatService.combatWinStatsUpdate(winner, updatedGame.id);
                this.combatService.updatePlayersInGame(updatedGame);
            }

            // Check if disconnect caused game termination
            const endResult = this.gameManagerService.checkAfterDisconnect(updatedGame.id);

            if (endResult.reason === GameEndReason.NoWinner_Termination) {
                this.gameManagerService.handleGameEnd(updatedGame.id, endResult, this.server);
                this.gameCountdownService.deleteCountdown(updatedGame.id);
                this.combatCountdownService.deleteCountdown(updatedGame.id); // Clean up combat timer if exists
                return;
            }

            // If player was eliminated, check if game should end (elimination mode)
            if (updatedGame.settings.isFastElimination && updatedPlayer?.isEliminated) {
                const activePlayers = updatedGame.players.filter((p) => p.isActive && !p.isObserver);
                if (activePlayers.length < 2) {
                    const eliminationEndResult = this.gameManagerService.checkAfterCombat(updatedGame.id, activePlayers[0], true);
                    if (eliminationEndResult.reason !== GameEndReason.Ongoing) {
                        this.gameManagerService.handleGameEnd(updatedGame.id, eliminationEndResult, this.server);
                        this.gameCountdownService.deleteCountdown(updatedGame.id);
                        this.combatCountdownService.deleteCountdown(updatedGame.id);
                        return;
                    }
                }
            }

            // Game continues, handle combat or turn timeout
            // Only handle combat disconnection if stats weren't already updated above
            if (combat) {
                // Emit combat finished event and cleanup
                this.server.to(combat.id).emit(CombatEvents.CombatFinishedByDisconnection, combat.challenger.socketId === client.id ? combat.opponent : combat.challenger);
                this.combatCountdownService.deleteCountdown(updatedGame.id);
                
                setTimeout(() => {
                    const game = this.gameCreationService.getGameById(updatedGame.id);
                    if (!game) {
                        console.warn(`[CombatGateway] handlePlayerDisconnection setTimeout: Game ${updatedGame.id} not found (likely already ended)`);
                        return;
                    }
                    
                    const winner = client.id === combat.challenger.socketId ? combat.opponent : combat.challenger;
                    const loser = client.id === combat.challenger.socketId ? combat.challenger : combat.opponent;
                    const combatFinishedData: CombatFinishedData = { updatedGame: game, winner: winner, loser: loser };
                    this.server.to(game.id).emit(CombatEvents.CombatFinished, combatFinishedData);
                    
                    this.cleanupCombatRoom(combat.id);
                    this.combatService.deleteCombat(game.id);
                }, TIME_LIMIT_DELAY);
            } else if (updatedGame.currentTurn === player.turn) {
                // Player is in their turn - automatically finish their turn so next player can play
                console.log(`[CombatGateway] Player ${player.name} left during their turn. Automatically finishing turn.`);
                this.gameManagerGateway.prepareNextTurn(updatedGame.id);
            }
        }
    }

    private handleCombatDisconnection(client: Socket, updatedGame: Game, combat: Combat): void {
        const disconnectedPlayer = client.id === combat.challenger.socketId ? combat.challenger : combat.opponent;
        const winner = client.id === combat.challenger.socketId ? combat.opponent : combat.challenger;
        disconnectedPlayer.isActive = false;

        if (updatedGame.settings.isFastElimination) {
            this.setPlayerToEliminated(disconnectedPlayer, updatedGame);

            // Check if this elimination ends the game BEFORE notifying
            const endResult = this.gameManagerService.checkAfterCombat(updatedGame.id, winner, updatedGame.settings.isFastElimination);

            // Only notify about elimination if game continues
            // If game ends, the eliminated player will receive GameFinished event and be redirected to stats
            if (endResult.reason === GameEndReason.Ongoing) {
                this.notifyPlayerEnteredObservationMode(
                    disconnectedPlayer,
                    'Vous avez perdu le combat par déconnexion et êtes maintenant en mode observation.',
                );
            }
        }

        this.combatService.combatWinStatsUpdate(winner, updatedGame.id);
        this.combatService.updatePlayersInGame(updatedGame);
        this.server.to(combat.id).emit(CombatEvents.CombatFinishedByDisconnection, winner);

        this.combatCountdownService.deleteCountdown(updatedGame.id);

        setTimeout(() => {
            const game = this.gameCreationService.getGameById(updatedGame.id);
            if (!game) {
                console.warn(`[CombatGateway] handleCombatDisconnection setTimeout: Game ${updatedGame.id} not found (likely already ended)`);
                return;
            }
            const combatFinishedData: CombatFinishedData = { updatedGame: game, winner: winner, loser: disconnectedPlayer };
            this.server.to(game.id).emit(CombatEvents.CombatFinished, combatFinishedData);

            // Check if combat resulted in game end
            const endResult = this.gameManagerService.checkAfterCombat(game.id, winner, game.settings.isFastElimination);

            if (endResult.reason !== GameEndReason.Ongoing) {
                this.gameManagerService.handleGameEnd(game.id, endResult, this.server);
                this.combatService.deleteCombat(game.id);
                this.cleanupCombatRoom(combat.id);
                this.gameCountdownService.deleteCountdown(game.id);
                return;
            }

            // Game continues
            this.handlePostCombatGameFlow(game, winner, combat.id);
        }, TIME_LIMIT_DELAY);
    }

    private cleanupFailedCombat(gameId: string, combatId: string | undefined): void {
        console.log(`[CombatGateway] Cleaning up failed combat for game ${gameId}`);

        try {
            // Delete combat countdown
            this.combatCountdownService.deleteCountdown(gameId);

            // Delete combat
            if (this.combatService.getCombatByGameId(gameId)) {
                this.combatService.deleteCombat(gameId);
            }

            // Cleanup combat room
            if (combatId) {
                this.cleanupCombatRoom(combatId);
            }
            const game = this.gameCreationService.getGameById(gameId);
            if (!game) {
                return;
            }

            // Check if game should be terminated or continue
            if (this.gameManagerService.shouldTerminateGame(gameId)) {
                console.log(`[CombatGateway] Terminating game ${gameId} after combat failure - no active or observing players`);
                this.gameCreationService.deleteRoom(gameId);
                this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
                this.gameCountdownService.deleteCountdown(gameId);
            } else {
                // Resume game countdown and move to next turn
                console.log(`[CombatGateway] Resuming game ${gameId} after combat failure`);
                this.gameCountdownService.resumeCountdown(gameId);
                this.gameCountdownService.emit(CountdownEvents.Timeout, gameId);
            }
        } catch (error) {
            console.error(`[CombatGateway] Error cleaning up failed combat:`, error);
        }
    }
}
