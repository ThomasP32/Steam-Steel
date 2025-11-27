import { Coordinate } from '@app/http/model/schemas/map/coordinate.schema';
import { Combat, RollResult } from '@common/combat';
import { COUNTDOWN_COMBAT_DURATION, DEFAULT_EVASIONS, DEFENDING_PLAYER_LIFE, ROLL_DICE_CONSTANT } from '@common/constants';
import { CORNER_DIRECTIONS, DIRECTIONS } from '@common/directions';
import { CombatEvents, CombatStartedData } from '@common/events/combat.events';
import { Game, Player } from '@common/game';
import { ItemCategory, TileCategory } from '@common/map.types';
import { Inject, Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { ChallengeService } from '../challenge/challenge.service';
import { CombatCountdownService } from '../countdown/combat/combat-countdown.service';
import { GameCountdownService } from '../countdown/game/game-countdown.service';
import { GameCreationService } from '../game-creation/game-creation.service';
import { GameManagerService } from '../game-manager/game-manager.service';
import { ItemsManagerService } from '../items-manager/items-manager.service';
import { JournalService } from '../journal/journal.service';
@Injectable()
export class CombatService {
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;

    private combatRooms: Record<string, Combat> = {};
    server: Server;

    constructor(
        private readonly gameCreationService: GameCreationService,
        private readonly itemManagerService: ItemsManagerService,
    ) {
        this.gameCreationService = gameCreationService;
        this.itemManagerService = itemManagerService;
    }

    setServer(server: Server) {
        this.server = server;
    }

    createCombat(gameId: string, challenger: Player, opponent: Player): Combat | null {
        // Check if combat already exists for this game
        if (this.doesCombatExist(gameId)) {
            console.log(`[CombatService] Cannot create combat - combat already exists for game ${gameId}`);
            return null;
        }

        let currentTurnSocketId: string = challenger.socketId;
        if (challenger.specs.speed < opponent.specs.speed) {
            currentTurnSocketId = opponent.socketId;
        }

        const combatRoomId = gameId + '-combat';
        const combat: Combat = {
            challenger: challenger,
            opponent: opponent,
            currentTurnSocketId: currentTurnSocketId,
            challengerLife: challenger.specs.life,
            opponentLife: opponent.specs.life,
            challengerAttack: challenger.specs.attack,
            opponentAttack: opponent.specs.attack,
            challengerDefense: challenger.specs.defense,
            opponentDefense: opponent.specs.defense,
            id: combatRoomId,
        };
        this.combatRooms[gameId] = combat;
        return combat;
    }

    getCombatByGameId(gameId: string): Combat {
        if (this.doesCombatExist(gameId)) {
            return this.combatRooms[gameId];
        }
    }

    doesCombatExist(gameId: string): boolean {
        return gameId in this.combatRooms;
    }

    deleteCombat(gameId: string) {
        delete this.combatRooms[gameId];
    }

    attackResult(attackPlayer: Player, opponent: Player, rollResult: { attackDice: number; defenseDice: number }): number {
        const attackTotal = attackPlayer.specs.attack + rollResult.attackDice;
        const defendTotal = opponent.specs.defense + rollResult.defenseDice;
        return attackTotal - defendTotal;
    }

    handleAttackSuccess(attackingPlayer: Player, defendingPlayer: Player, combatId: string, gameId: string, attackResult: number) {
        defendingPlayer.specs.life = defendingPlayer.specs.life - attackResult;
        defendingPlayer.specs.nLifeLost = defendingPlayer.specs.nLifeLost + attackResult;
        attackingPlayer.specs.nLifeTaken = attackingPlayer.specs.nLifeTaken + attackResult;

        const game = this.gameCreationService.getGameById(gameId);
        if (game) {
            this.challengeService.onAttack(game, attackingPlayer, attackResult);
        }

        if (defendingPlayer.inventory.includes(ItemCategory.Flask) && defendingPlayer.specs.life === DEFENDING_PLAYER_LIFE) {
            this.itemManagerService.activateItem(ItemCategory.Flask, defendingPlayer);
        }
        this.server.to(combatId).emit(CombatEvents.AttackSuccess, defendingPlayer);
    }

    updateTurn(gameId: string): void {
        const combat = this.getCombatByGameId(gameId);
        const currentTurnSocket = combat.currentTurnSocketId;
        combat.currentTurnSocketId = currentTurnSocket === combat.challenger.socketId ? combat.opponent.socketId : combat.challenger.socketId;
    }

    rollDice(attackPlayer: Player, opponent: Player): RollResult {
        const attackingPlayerAttackDice = Math.floor(Math.random() * attackPlayer.specs.attackBonus) + ROLL_DICE_CONSTANT;
        const opponentDefenseDice = Math.floor(Math.random() * opponent.specs.defenseBonus) + ROLL_DICE_CONSTANT;
        const attackDice = attackPlayer.specs.attack + attackingPlayerAttackDice;
        const defenseDice = opponent.specs.defense + opponentDefenseDice;

        return {
            attackDice,
            defenseDice,
        };
    }

    combatWinStatsUpdate(winner: Player, gameId: string) {
        const combat = this.getCombatByGameId(gameId);
        if (!combat) {
            console.warn(`[CombatService] combatWinStatsUpdate: Combat for game ${gameId} not found (likely already ended)`);
            return;
        }
        if (winner.socketId === combat.challenger.socketId) {
            combat.challenger.specs.nVictories++;
            combat.opponent.specs.nDefeats++;
        } else {
            combat.opponent.specs.nVictories++;
            combat.challenger.specs.nDefeats++;
        }
    }

    sendBackToInitPos(player: Player, game: Game) {
        const combat = this.getCombatByGameId(game.id);
        if (!combat) {
            console.warn(`[CombatService] sendBackToInitPos: Combat for game ${game.id} not found (likely already ended)`);
            return;
        }
        const currentPlayer = player.socketId === combat.challenger.socketId ? combat.challenger : combat.opponent;

        const isPositionOccupied = game.players.some(
            (otherPlayer) =>
                otherPlayer.position &&
                otherPlayer.position.x === currentPlayer.initialPosition.x &&
                otherPlayer.position.y === currentPlayer.initialPosition.y &&
                otherPlayer.socketId !== currentPlayer.socketId,
        );
        if (!isPositionOccupied) {
            currentPlayer.position = currentPlayer.initialPosition;
        } else {
            const closestPosition = this.findClosestAvailablePosition(currentPlayer.initialPosition, game);
            currentPlayer.position = closestPosition;
        }
        currentPlayer.inventory = [];
    }

    findClosestAvailablePosition(initialPosition: Coordinate, game: Game): Coordinate {
        for (let distance = 1; distance <= game.mapSize.x; distance++) {
            for (const direction of [...DIRECTIONS, ...CORNER_DIRECTIONS]) {
                const newPosition = {
                    x: initialPosition.x + direction.x * distance,
                    y: initialPosition.y + direction.y * distance,
                };

                const isOutOfMap = newPosition.x < 0 || newPosition.y < 0 || newPosition.x >= game.mapSize.x || newPosition.y >= game.mapSize.y;

                const isReachableTile = this.isReachableTile(newPosition, game);

                if (isReachableTile && !isOutOfMap) {
                    return newPosition;
                }
            }
        }
    }

    isReachableTile(pos: Coordinate, game: Game): boolean {
        for (const tile of game.tiles) {
            if (tile.coordinate.x === pos.x && tile.coordinate.y === pos.y) {
                if (tile.category === TileCategory.Wall) return false;
            }
        }
        for (const door of game.doorTiles) {
            if (door.coordinate.x === pos.x && door.coordinate.y === pos.y && !door.isOpened) {
                return false;
            }
        }
        for (const player of game.players) {
            if (player.isActive && player.position && player.position.x === pos.x && player.position.y === pos.y) {
                return false;
            }
        }
        for (const item of game.items) {
            if (item.coordinate.x === pos.x && item.coordinate.y === pos.y) {
                return false;
            }
        }
        return true;
    }

    updatePlayersInGame(game: Game) {
        const combat = this.getCombatByGameId(game.id);
        if (!combat) {
            console.warn(`[CombatService] updatePlayersInGame: Combat for game ${game.id} not found (likely already ended)`);
            return;
        }
        game.players.forEach((player, index) => {
            if (player.socketId === combat.challenger.socketId) {
                combat.challenger.specs.life = combat.challengerLife;
                combat.challenger.specs.attack = combat.challengerAttack;
                combat.challenger.specs.evasions = DEFAULT_EVASIONS;
                combat.challenger.specs.nCombats++;
                combat.challenger.isEliminated = player.isEliminated;
                game.players[index] = combat.challenger;

                this.gameManagerService.resetIceAttributes(combat.challenger, game.id);
            } else if (player.socketId === combat.opponent.socketId) {
                combat.opponent.specs.life = combat.opponentLife;
                combat.opponent.specs.attack = combat.opponentAttack;
                combat.opponent.specs.evasions = DEFAULT_EVASIONS;
                combat.opponent.specs.nCombats++;
                combat.opponent.isEliminated = player.isEliminated;
                game.players[index] = combat.opponent;

                this.gameManagerService.resetIceAttributes(combat.opponent, game.id);
            }
        });
    }

    /**
     * Initializes combat by handling journal logging, event emission, countdown initialization, and starting turns.
     * This method centralizes combat initialization logic to avoid duplication.
     * @param combat - The combat instance to initialize
     * @param game - The game instance
     * @param challengerSocketId - The socket ID of the challenger (used for updating player actions)
     * @param journalService - Service for logging journal messages
     * @param gameManagerService - Service for updating player actions
     * @param combatCountdownService - Service for initializing combat countdown
     * @param gameCountdownService - Service for pausing game countdown
     * @param optionalClientId - Optional client ID for emitting YouStartedCombat event (only for real players)
     */
    initializeCombat(
        combat: Combat,
        game: Game,
        challengerSocketId: string,
        journalService: JournalService,
        gameManagerService: GameManagerService,
        combatCountdownService: CombatCountdownService,
        gameCountdownService: GameCountdownService,
        optionalClientId?: string,
    ): void {
        const involvedPlayers = [combat.challenger.name];
        journalService.logMessage(game.id, `${combat.challenger.name} a commencé un combat contre ${combat.opponent.name}.`, involvedPlayers);

        combat.challenger.specs.evasions = DEFAULT_EVASIONS;
        combat.opponent.specs.evasions = DEFAULT_EVASIONS;

        const combatStartedData: CombatStartedData = {
            challenger: combat.challenger,
            opponent: combat.opponent,
        };
        this.server.to(combat.id).emit(CombatEvents.CombatStarted, combatStartedData);
        this.server.to(game.id).emit(CombatEvents.CombatStartedSignal);
        gameManagerService.updatePlayerActions(game.id, challengerSocketId);
        combatCountdownService.initCountdown(game.id, COUNTDOWN_COMBAT_DURATION);
        gameCountdownService.pauseCountdown(game.id);
        if (optionalClientId) {
            this.server.to(optionalClientId).emit(CombatEvents.YouStartedCombat, combat.challenger);
        }
    }

    /**
     * Starts combat turns by emitting turn events and initializing the turn counter.
     * This method centralizes combat turn initialization logic to avoid duplication.
     * @param gameId - The game ID
     * @param combatCountdownService - Service for starting the turn counter
     * @param gameCreationService - Service for getting game instance
     * @returns The current player and other player if combat exists, undefined otherwise
     */
    startCombatTurns(
        gameId: string,
        combatCountdownService: CombatCountdownService,
        gameCreationService: GameCreationService,
    ): { currentPlayer: Player; otherPlayer: Player } | undefined {
        const combat = this.getCombatByGameId(gameId);
        const game = gameCreationService.getGameById(gameId);

        if (!combat) {
            console.warn(`[CombatService] startCombatTurns: Combat not found for game ${gameId}`);
            return undefined;
        }

        if (!game) {
            console.warn(`[CombatService] startCombatTurns: Game ${gameId} not found (likely already ended)`);
            combatCountdownService.deleteCountdown(gameId);
            return undefined;
        }

        // Safety check: Don't emit to invalidated/disconnected socketIds
        if (!combat.currentTurnSocketId.startsWith('DISCONNECTED-')) {
            this.server.to(combat.currentTurnSocketId).emit(CombatEvents.YourTurnCombat);
        } else {
            console.warn(`[CombatService] Skipping YourTurnCombat emission to invalidated socketId: ${combat.currentTurnSocketId}`);
        }
        
        const currentPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.challenger : combat.opponent;
        const otherPlayer = combat.currentTurnSocketId === combat.challenger.socketId ? combat.opponent : combat.challenger;
        
        // Safety check: Don't emit to invalidated/disconnected socketIds
        if (!otherPlayer.socketId.startsWith('DISCONNECTED-')) {
            this.server.to(otherPlayer.socketId).emit(CombatEvents.PlayerTurnCombat);
        } else {
            console.log(`[CombatService] Skipping PlayerTurnCombat emission to invalidated socketId: ${otherPlayer.socketId} (player: ${otherPlayer.name})`);
        }
        combatCountdownService.startTurnCounter(game, currentPlayer.specs.evasions !== 0);

        return { currentPlayer, otherPlayer };
    }
}
