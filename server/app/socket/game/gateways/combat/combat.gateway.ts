import { CombatService } from '@app/services/combat/combat.service';
import { Combat } from '@common/combat';
import { EVASION_SUCCESS_RATE, TIME_LIMIT_DELAY } from '@common/constants';
import { CombatEvents, CombatFinishedByEvasionData, CombatFinishedData, CombatStartedData, PlayerEnteredObservationModeData, StartCombatData } from '@common/events/combat.events';
import { CountdownEvents } from '@common/events/countdown.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { ItemDroppedData, ItemsEvents } from '@common/events/items.events';
import { Game, Player } from '@common/game';
import { Inject } from '@nestjs/common';
import { OnGatewayDisconnect, OnGatewayInit, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { CombatCountdownService } from '../../../../services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from '../../../../services/countdown/game/game-countdown.service';
import { GameCreationService } from '../../../../services/game-creation/game-creation.service';
import { GameManagerService } from '../../../../services/game-manager/game-manager.service';
import { ItemsManagerService } from '../../../../services/items-manager/items-manager.service';
import { JournalService } from '../../../../services/journal/journal.service';
import { VirtualGameManagerService } from '../../../../services/virtual-game-manager/virtual-game-manager.service';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class CombatGateway implements OnGatewayInit, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    @Inject(ItemsManagerService) private readonly itemsManagerService: ItemsManagerService;
    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(VirtualGameManagerService) private readonly virtualGameManager: VirtualGameManagerService;

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
        const game = this.gameCreationService.getGameById(data.gameId);
        if (game) {
            const player = game.players.find((player) => player.turn === game.currentTurn);

            if (player?.isObservationMode || data.opponent?.isObservationMode) {
                return;
            }
    
            const combat = this.combatService.createCombat(data.gameId, player, data.opponent);
            this.itemsManagerService.checkForAmulet(player, data.opponent);
            await client.join(combat.id);
            let opponentSocket;
            if (data.opponent.socketId.includes('virtual')) {
                opponentSocket = data.opponent.socketId;
            } else {
                const sockets = await this.server.in(data.gameId).fetchSockets();
                opponentSocket = sockets.find((socket) => socket.id === data.opponent.socketId);
                if (opponentSocket) {
                    await opponentSocket.join(combat.id);
                }
            }
            if (opponentSocket) {
                // Add observers to combat room
                const observers = game.players.filter((p) => p.isObservationMode);
                const sockets = await this.server.in(data.gameId).fetchSockets();
                for (const observer of observers) {
                    const observerSocket = sockets.find((socket) => socket.id === observer.socketId);
                    if (observerSocket) {
                        await observerSocket.join(combat.id);
                    }
                }

                const combatStartedData: CombatStartedData = {
                    challenger: player,
                    opponent: data.opponent,
                };
                this.server.to(combat.id).emit(CombatEvents.CombatStarted, combatStartedData);
                this.gameManagerService.updatePlayerActions(data.gameId, client.id);
                const involvedPlayers = [player.name];
                this.journalService.logMessage(data.gameId, `${player.name} a commencé un combat contre ${data.opponent.name}.`, involvedPlayers);

                this.server.to(data.gameId).emit(CombatEvents.CombatStartedSignal);
                this.server.to(client.id).emit(CombatEvents.YouStartedCombat, player);
                this.combatCountdownService.initCountdown(data.gameId, 5);
                this.gameCountdownService.pauseCountdown(data.gameId);
                this.startCombatTurns(data.gameId);
            }
        }
    }

    @SubscribeMessage(CombatEvents.Attack)
    attack(client: Socket, gameId: string): void {
        this.attackOnTimeOut(gameId);
    }

    @SubscribeMessage(CombatEvents.StartEvasion)
    async startEvasion(client: Socket, gameId: string): Promise<void> {
        const combat = this.combatService.getCombatByGameId(gameId);
        if (combat) {
            if (client.id === combat.currentTurnSocketId) {
                const evadingPlayer: Player = combat.challenger.socketId === client.id ? combat.challenger : combat.opponent;
                const otherPlayer: Player = combat.challenger.socketId === evadingPlayer.socketId ? combat.opponent : combat.challenger;
                if (evadingPlayer.specs.evasions === 0) {
                    return;
                }
                evadingPlayer.specs.nEvasions++;
                evadingPlayer.specs.evasions--;
                const evasionSuccess = Math.random() < EVASION_SUCCESS_RATE;

                if (evasionSuccess) {
                    const game = this.gameCreationService.getGameById(gameId);
                    this.combatService.updatePlayersInGame(game);
                    this.server.to(combat.id).emit(CombatEvents.EvasionSuccess, evadingPlayer);
                    this.journalService.logMessage(gameId, `Fin de combat. ${evadingPlayer.name} s'est évadé.`, [evadingPlayer.name]);
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
                        }
                    }, TIME_LIMIT_DELAY);
                } else {
                    this.server.to(combat.id).emit(CombatEvents.EvasionFailed, evadingPlayer);
                    this.prepareNextTurn(gameId);
                    this.journalService.logMessage(combat.id, `Tentative d'évasion par ${evadingPlayer.name}: non réussie.`, [evadingPlayer.name]);
                }
            }
        }
    }

    attackOnTimeOut(gameId: string) {
        const combat = this.combatService.getCombatByGameId(gameId);
        if (combat) {
            const attackingPlayer: Player = combat.currentTurnSocketId === combat.challenger.socketId ? combat.challenger : combat.opponent;
            const defendingPlayer: Player = combat.currentTurnSocketId === combat.challenger.socketId ? combat.opponent : combat.challenger;

            const rollResult = this.combatService.rollDice(attackingPlayer, defendingPlayer);
            this.server.to(combat.id).emit(CombatEvents.DiceRolled, rollResult);
            this.journalService.logMessage(
                combat.id,
                `Dés roulés. Dé d'attaque: ${rollResult.attackDice}. Dé de défense: ${rollResult.defenseDice}. Résultat = ${rollResult.attackDice} - ${rollResult.defenseDice}.`,
                [attackingPlayer.name, defendingPlayer.name],
            );

            if (this.combatService.isAttackSuccess(attackingPlayer, defendingPlayer, rollResult)) {
                this.combatService.handleAttackSuccess(attackingPlayer, defendingPlayer, combat.id);
                this.journalService.logMessage(combat.id, `Réussite de l'attaque sur ${defendingPlayer.name}.`, [defendingPlayer.name]);
            } else {
                this.server.to(combat.id).emit(CombatEvents.AttackFailure, defendingPlayer);
                this.journalService.logMessage(combat.id, `Échec de l'attaque sur ${defendingPlayer.name}.`, [defendingPlayer.name]);
            }

            if (defendingPlayer.specs.life === 0) {
                this.handleCombatLost(defendingPlayer, attackingPlayer, gameId, combat.id);
            } else {
                this.prepareNextTurn(gameId);
            }
        }
    }

    handleCombatLost(defendingPlayer: Player, attackingPlayer: Player, gameId: string, combatId: string) {
        const game = this.gameCreationService.getGameById(gameId);
        this.combatService.combatWinStatsUpdate(attackingPlayer, gameId);
                
        if(game.settings.isFastElimination){
            defendingPlayer.isObservationMode = true;
            // Also update the player in game.players array
            const playerInGame = game.players.find(p => p.socketId === defendingPlayer.socketId);
            if (playerInGame) {
                playerInGame.isObservationMode = true;
            }
            console.log(`[ELIMINATION DEBUG] Player ${defendingPlayer.name} set to observation mode (isObservationMode: ${defendingPlayer.isObservationMode})`);
        } 

        this.itemsManagerService.dropInventory(defendingPlayer, gameId);
        if (!game.settings.isFastElimination){
            this.combatService.sendBackToInitPos(defendingPlayer, game);
        }
        this.combatService.updatePlayersInGame(game);

        this.server.to(combatId).emit(CombatEvents.CombatFinishedNormally, attackingPlayer);

        this.journalService.logMessage(gameId, `Fin de combat. ${attackingPlayer.name} est le gagnant.`, [attackingPlayer.name]);


        if(game.settings.isFastElimination){
            const observationModeData: PlayerEnteredObservationModeData = {
                player: defendingPlayer,
                message: 'Vous avez perdu le combat et êtes maintenant en mode observation.'
            };
            this.server.to(defendingPlayer.socketId).emit(CombatEvents.PlayerEnteredObservationMode, observationModeData);
        }

        this.combatCountdownService.deleteCountdown(gameId);
        setTimeout(() => {
            const game = this.gameCreationService.getGameById(gameId);
            if (!game) {
                console.warn(`[CombatGateway] handleCombatLost setTimeout: Game ${gameId} not found (likely already ended)`);
                return;
            }
            const combatFinishedData: CombatFinishedData = { updatedGame: game, winner: attackingPlayer, loser: defendingPlayer };
            this.server.to(gameId).emit(CombatEvents.CombatFinished, combatFinishedData);
            
            if (this.combatService.checkForGameWinner(game.id, attackingPlayer)) {
                this.combatService.markClassicGameWinners(game.id, game);

                this.server.to(gameId).emit(CombatEvents.GameFinished, { updatedGame: game });
                this.server.to(gameId).emit(CombatEvents.GameFinishedPlayerWon, attackingPlayer);
                
                // Clean up combat resources before ending
                this.combatService.deleteCombat(game.id);
                this.cleanupCombatRoom(combatId);
                return;
            } else {
                if(game.settings.isFastElimination){
                    const observationModeData: PlayerEnteredObservationModeData = {
                        player: defendingPlayer,
                        message: 'Vous avez perdu le combat et êtes maintenant en mode observation.'
                    };
                    this.server.to(defendingPlayer.socketId).emit(CombatEvents.PlayerEnteredObservationMode, observationModeData);
                }
            }
            if (game.currentTurn === attackingPlayer.turn) {
                this.gameCountdownService.resumeCountdown(gameId);
                if (attackingPlayer.socketId.includes('virtual')) {
                    // Virtual player won and can continue their turn
                    this.virtualGameManager.executeVirtualPlayerBehavior(attackingPlayer, game);
                } else {
                    this.server.to(attackingPlayer.socketId).emit(CombatEvents.ResumeTurnAfterCombatWin);
                }
            } else {
                this.gameCountdownService.emit(CountdownEvents.Timeout, gameId);
            }
            this.combatService.deleteCombat(game.id);
            this.cleanupCombatRoom(combatId);
        }, TIME_LIMIT_DELAY);
    }

    prepareNextTurn(gameId: string) {
        if (this.combatService.getCombatByGameId(gameId)) {
            this.combatService.updateTurn(gameId);
            this.combatCountdownService.resetTimerSubscription(gameId);
            this.startCombatTurns(gameId);
        }
    }

    startCombatTurns(gameId: string): void {
        const combat = this.combatService.getCombatByGameId(gameId);
        const game = this.gameCreationService.getGameById(gameId);
        if (combat) {
            this.server.to(combat.currentTurnSocketId).emit(CombatEvents.YourTurnCombat);
            const currentPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.challenger : combat.opponent;
            const otherPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.opponent : combat.challenger;
            this.server.to(otherPlayer.socketId).emit(CombatEvents.PlayerTurnCombat);

            if (combat.currentTurnSocketId.includes('virtual')) {
                setTimeout(() => {
                    const isCombatFinishedByEvasion = this.virtualGameManager.handleVirtualPlayerCombat(currentPlayer, otherPlayer, game.id, combat);
                    if (otherPlayer.specs.life === 0) {
                        this.handleCombatLost(otherPlayer, currentPlayer, game.id, combat.id);
                        // Don't execute virtual player behavior here - it will be handled in handleCombatLost after checking for game winner
                    } else if (isCombatFinishedByEvasion) {
                        setTimeout(async () => {
                            const game = this.gameCreationService.getGameById(gameId);
                            if (!game) {
                                console.warn(`[CombatGateway] startCombatTurns virtual evasion setTimeout: Game ${gameId} not found (likely already ended)`);
                                return;
                            }
                            const combatFinishedByEvasionData: CombatFinishedByEvasionData = { updatedGame: game, evadingPlayer: currentPlayer };
                            this.server.to(gameId).emit(CombatEvents.CombatFinishedByEvasion, combatFinishedByEvasionData);
                            this.gameCountdownService.resumeCountdown(gameId);
                            this.cleanupCombatRoom(combat.id);
                            this.combatService.deleteCombat(gameId);

                            if (this.gameCreationService.getGameById(gameId)?.currentTurn === currentPlayer.turn) {
                                await this.virtualGameManager.executeVirtualPlayerBehavior(currentPlayer, game);
                            }
                        }, TIME_LIMIT_DELAY);
                    } else {
                        this.prepareNextTurn(gameId);
                    }
                }, TIME_LIMIT_DELAY);
            }
            this.combatCountdownService.startTurnCounter(game, currentPlayer.specs.evasions !== 0);
        }
    }

    async cleanupCombatRoom(combatRoomId: string): Promise<void> {
        const sockets = await this.server.in(combatRoomId).fetchSockets();
        for (const socketId of sockets) {
            socketId.leave(combatRoomId);
        }
    }

    handleDisconnect(client: Socket): void {
        const games = this.gameCreationService.getGames();

        games.forEach((game) => {
            if (!game.hasStarted) {
                if (this.handleHostDisconnection(client, game)) {
                    return;
                }
            }

            const player = game.players.find((player) => player.socketId === client.id);
            if (player) {
                this.handlePlayerDisconnection(client, game, player);
            }
        });
    }

    private handleHostDisconnection(client: Socket, game: Game): boolean {
        if (this.gameCreationService.isPlayerHost(client.id, game.id)) {
            this.server.to(game.id).emit(GameCreationEvents.GameClosed);
            this.gameCreationService.deleteRoom(game.id);
            return true;
        }
        return false;
    }

    private handlePlayerDisconnection(client: Socket, game: Game, player: Player): void {
        const updatedGame = this.gameCreationService.handlePlayerLeaving(client, game.id);
        this.server.to(updatedGame.id).emit(GameCreationEvents.PlayerLeft, updatedGame.players);

        if (updatedGame.hasStarted) {
            if (player.inventory && player.inventory.length > 0) {
                this.itemsManagerService.dropInventory(player, updatedGame.id);
                const itemDroppedData: ItemDroppedData = { updatedGame: game, updatedPlayer: player };
                this.server.to(game.id).emit(ItemsEvents.ItemDropped, itemDroppedData);
            }
            this.journalService.logMessage(game.id, `${player.name} a abandonné la partie.`, [player.name]);

            const combat = this.combatService.getCombatByGameId(updatedGame.id);
            if (combat) {
                this.handleCombatDisconnection(client, updatedGame, combat);
            } else if (game.currentTurn === player.turn) {
                this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
            }
        }
    }

    private handleCombatDisconnection(client: Socket, updatedGame: Game, combat: Combat): void {
        const disconnectedPlayer = client.id === combat.challenger.socketId ? combat.challenger : combat.opponent;
        const winner = client.id === combat.challenger.socketId ? combat.opponent : combat.challenger;
        disconnectedPlayer.isActive = false;
        
        
        if(updatedGame.settings.isFastElimination) {
            disconnectedPlayer.isObservationMode = true;
            // Also update the player in game.players array
            const playerInGame = updatedGame.players.find(p => p.socketId === disconnectedPlayer.socketId);
            if (playerInGame) {
                playerInGame.isObservationMode = true;
            }
            console.log(`[ELIMINATION DEBUG] Disconnected player ${disconnectedPlayer.name} set to observation mode via disconnection`);
        }

        this.combatService.combatWinStatsUpdate(winner, updatedGame.id);
        this.combatService.updatePlayersInGame(updatedGame);
        this.server.to(combat.id).emit(CombatEvents.CombatFinishedByDisconnection, winner);

        if(updatedGame.settings.isFastElimination) {
            const observationModeData: PlayerEnteredObservationModeData = {
                player: disconnectedPlayer,
                message: 'Vous avez perdu le combat par déconnexion et êtes maintenant en mode observation.'
            };
            this.server.to(disconnectedPlayer.socketId).emit(CombatEvents.PlayerEnteredObservationMode, observationModeData);
        }       


        if(updatedGame.settings.isFastElimination) {
            const observationModeData: PlayerEnteredObservationModeData = {
                player: disconnectedPlayer,
                message: 'Vous avez perdu le combat par déconnexion et êtes maintenant en mode observation.'
            };
            this.server.to(disconnectedPlayer.socketId).emit(CombatEvents.PlayerEnteredObservationMode, observationModeData);
        }       

        this.combatCountdownService.deleteCountdown(updatedGame.id);

        setTimeout(() => {
            const game = this.gameCreationService.getGameById(updatedGame.id);
            if (!game) {
                console.warn(`[CombatGateway] handleCombatDisconnection setTimeout: Game ${updatedGame.id} not found (likely already ended)`);
                return;
            }
            const combatFinishedData: CombatFinishedData = { updatedGame: game, winner: winner, loser: disconnectedPlayer };
            this.server.to(game.id).emit(CombatEvents.CombatFinished, combatFinishedData);

            if (this.combatService.checkForGameWinner(game.id, winner)) {
                this.combatService.markClassicGameWinners(game.id, game);
                this.server.to(game.id).emit(CombatEvents.GameFinishedPlayerWon, winner);
                
                // Clean up combat resources before ending
                this.combatService.deleteCombat(game.id);
                this.cleanupCombatRoom(combat.id);
                return;
            }

            if (game.currentTurn === winner.turn) {
                this.gameCountdownService.resumeCountdown(game.id);
            } else {
                this.gameCountdownService.emit(CountdownEvents.Timeout, game.id);
            }

            this.combatService.deleteCombat(game.id);
            this.cleanupCombatRoom(combat.id);
        }, TIME_LIMIT_DELAY);
    }
}
