import { DoorTile } from '@app/http/model/schemas/map/tiles.schema';
import { UserService } from '@app/http/services/user/user.service';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { CombatService } from '@app/services/combat/combat.service';
import { CombatCountdownService } from '@app/services/countdown/combat/combat-countdown.service';
import { GameCountdownService } from '@app/services/countdown/game/game-countdown.service';
import { GameCreationService } from '@app/services/game-creation/game-creation.service';
import { GameManagerService } from '@app/services/game-manager/game-manager.service';
import { JournalService } from '@app/services/journal/journal.service';
import { VirtualGameManagerService } from '@app/services/virtual-game-manager/virtual-game-manager.service';
import {
    DEFAULT_ACTIONS,
    INVENTORY_SIZE,
    TIME_FOR_POSITION_UPDATE,
    TURN_DURATION,
    VIRTUAL_DELAY_CONSTANT,
    VIRTUAL_PLAYER_DELAY,
} from '@common/constants';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { GameTurnEvents } from '@common/events/game-turn.events';
import { DropItemData, ItemDroppedData, ItemsEvents } from '@common/events/items.events';
import { Game, GameEndReason, Player } from '@common/game';
import { Coordinate, Tile } from '@common/map.types';
import { Inject } from '@nestjs/common';
import { OnGatewayInit, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ItemsManagerService } from '../../../../services/items-manager/items-manager.service';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class GameManagerGateway implements OnGatewayInit {
    @WebSocketServer()
    server: Server;

    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(GameCountdownService) private readonly gameCountdownService: GameCountdownService;
    @Inject(CombatCountdownService) private readonly combatCountdownService: CombatCountdownService;
    @Inject(CombatService) private readonly combatService: CombatService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(VirtualGameManagerService) private virtualGameManagerService: VirtualGameManagerService;
    @Inject(ItemsManagerService) private readonly itemsManagerService: ItemsManagerService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(UserService) private readonly userService: UserService;

    afterInit(server: Server) {
        this.gameCountdownService.setServer(this.server);
        this.gameCountdownService.on('timeout', (gameId: string) => {
            this.prepareNextTurn(gameId);
        });
        this.virtualGameManagerService.setServer(this.server);
        this.virtualGameManagerService.on('virtualPlayerFinishedMoving', (gameId: string) => {
            const activeCombat = this.combatService.getCombatByGameId(gameId);
            if (activeCombat) {
                console.log(`[GameManagerGateway] Combat active in game ${gameId}, turn will not advance until combat ends`);
                return;
            }
            this.prepareNextTurn(gameId);
        });
        this.virtualGameManagerService.on('virtualPlayerCanResumeTurn', (gameId: string) => {
            this.startTurn(gameId);
        });
        this.journalService.initializeServer(server);
        this.challengeService.setServer(this.server);
        this.userService.setServer(this.server);
        this.itemsManagerService.setServer(this.server);
    }

    @SubscribeMessage('getMovements')
    getMoves(client: Socket, gameId: string): void {
        if (!this.gameCreationService.doesGameExist(gameId)) {
            client.emit(GameCreationEvents.GameNotFound);
            return;
        }
        const moves = this.gameManagerService.getMoves(gameId, client.id);
        client.emit(GameManagerEvents.PlayerPossibleMoves, moves);
    }

    @SubscribeMessage('moveToPosition')
    async getMove(client: Socket, data: { gameId: string; destination: Coordinate }): Promise<void> {
        let wasOnIceTile = false;
        if (!this.gameCreationService.doesGameExist(data.gameId)) {
            client.emit(GameCreationEvents.GameNotFound);
            return;
        }
        const game = this.gameCreationService.getGameById(data.gameId);

        const player = game.players.filter((player) => player.socketId === client.id)[0];
        const beforeMoveInventory = [...player.inventory];
        const moves = this.gameManagerService.getMove(data.gameId, client.id, data.destination);
        if (this.gameManagerService.onIceTile(player, game.id)) wasOnIceTile = true;
        if (moves.length === 0) return;
        const gameFinished = await this.movePlayer(moves, game, wasOnIceTile, player);

        if (!gameFinished) {
            if (this.gameManagerService.hasPickedUpFlag(beforeMoveInventory, player.inventory)) {
                this.server.to(data.gameId).emit(GameManagerEvents.FlagPickup, game);
                this.server.to(client.id).emit(GameManagerEvents.YouFinishedMoving);
                this.journalService.logMessage(
                    data.gameId,
                    `Le drapeau a été récupéré par ${player.name}.`,
                    game.players.map((player) => player.name),
                );
            } else {
                this.server.to(client.id).emit(GameManagerEvents.YouFinishedMoving);
            }
        }
    }

    @SubscribeMessage('toggleDoor')
    toggleDoor(client: Socket, data: { gameId: string; door: DoorTile }): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        const player = game.players.find((player) => player.socketId === client.id);
        const doorTile = game.doorTiles.find((door) => door.coordinate.x === data.door.coordinate.x && door.coordinate.y === data.door.coordinate.y);
        this.gameManagerService.updatePlayerActions(game.id, player.socketId);
        doorTile.isOpened = !doorTile.isOpened;
        game.nDoorsManipulated.push(doorTile.coordinate);

        // Track challenge progress when door is opened (not closed)
        this.challengeService.onDoorOpened(game, player, doorTile);

        const action = doorTile.isOpened ? 'ouverte' : 'fermée';
        const involvedPlayers = game.players.map((player) => player.name);
        this.journalService.logMessage(data.gameId, `Une porte a été ${action} par ${player.name}.`, involvedPlayers);
        this.server.to(data.gameId).emit(ItemsEvents.DoorToggled, { game: game, player: player });

        this.checkAndAutoEndTurn(game.id, player.socketId);
    }

    @SubscribeMessage('breakWall')
    breakWall(client: Socket, data: { gameId: string; wall: Tile }): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        const player = game.players.find((player) => player.socketId === client.id);
        const wallTiles = this.gameManagerService.getAdjacentWalls(player, game.id);

        wallTiles.forEach((wallTile) => {
            const index = game.tiles.findIndex((tile) => tile.coordinate.x === wallTile.coordinate.x && tile.coordinate.y === wallTile.coordinate.y);

            if (index !== -1) {
                game.tiles.splice(index, 1);
            }
        });
        this.gameManagerService.updatePlayerActions(game.id, player.socketId);
        const involvedPlayers = game.players.map((player) => player.name);
        this.journalService.logMessage(data.gameId, `${player.name}. a brisé un mur !`, involvedPlayers);
        this.server.to(data.gameId).emit(ItemsEvents.WallBroken, { game: game, player: player });

        // Check if player is stuck and auto-end turn
        this.checkAndAutoEndTurn(game.id, player.socketId);
    }

    @SubscribeMessage('getCombats')
    getCombats(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;
        const player = game.players.find((player) => player.socketId === client.id);
        const adjacentPlayers = this.gameManagerService.getAdjacentPlayers(player, gameId);
        this.server.to(client.id).emit(GameManagerEvents.YourCombats, adjacentPlayers);
    }

    @SubscribeMessage('getAdjacentDoors')
    getAdjacentDoors(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;
        const player = game.players.find((player) => player.socketId === client.id);
        const adjacentDoors = this.gameManagerService.getAdjacentDoors(player, gameId);
        this.server.to(client.id).emit(GameManagerEvents.YourDoors, adjacentDoors);
    }

    @SubscribeMessage('getAdjacentWalls')
    getAdjacentWalls(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;
        const player = game.players.find((player) => player.socketId === client.id);
        const adjacentWalls = this.gameManagerService.getAdjacentWalls(player, gameId);
        this.server.to(client.id).emit(GameManagerEvents.YourWalls, adjacentWalls);
    }

    @SubscribeMessage(ItemsEvents.dropItem)
    dropItem(client: Socket, data: DropItemData): void {
        const game = this.gameCreationService.getGameById(data.gameId);
        if (!game) return;
        const player = game.players.find((player) => player.socketId === client.id);
        const coordinates = player.position;
        this.itemsManagerService.dropItem(data.itemDropping, game.id, player, coordinates);
        const itemDroppedData: ItemDroppedData = { updatedGame: game, updatedPlayer: player };
        this.server.to(player.socketId).emit(ItemsEvents.ItemDropped, itemDroppedData);
    }
    @SubscribeMessage('startGame')
    startGame(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;
        this.gameCountdownService.initCountdown(gameId, TURN_DURATION);
        this.startTurn(gameId);
    }

    @SubscribeMessage('endTurn')
    endTurn(client: Socket, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;
        const player = game.players.find((player) => player.turn === game.currentTurn);
        if (player.socketId !== client.id) {
            return;
        }
        // Move to next turn - stats will be reset in startTurn for the next player
        this.prepareNextTurn(gameId);
    }

    prepareNextTurn(gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            return;
        }
        const finishingPlayer = game.players.find((player) => player.turn === game.currentTurn);
        if (finishingPlayer) {
            game.lastTurnPlayer = finishingPlayer.name;
        } else {
            console.warn(
                `[GameManagerGateway] prepareNextTurn: No player found for turn index ${game.currentTurn}, keeping lastTurnPlayer as ${game.lastTurnPlayer}`,
            );
        }
        this.gameCountdownService.resetTimerSubscription(gameId);
        this.gameManagerService.updateTurnCounter(gameId);

        this.startTurn(gameId);
    }

    private checkAndAutoEndTurn(gameId: string, playerSocketId: string): void {
        if (this.gameManagerService.isPlayerStuck(gameId, playerSocketId)) {
            console.log(`[GameManagerGateway] Player is stuck (no actions, has movement points but cannot move). Auto-ending turn.`);
            this.prepareNextTurn(gameId);
        }
    }

    private handleGameTermination(gameId: string, reason: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            return;
        }
        if (this.gameManagerService.shouldTerminateGame(gameId)) {
            console.log(`[GameManagerGateway] Terminating game ${gameId} - ${reason}`);
            this.gameCreationService.deleteRoom(gameId);
            this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
            this.gameCountdownService.deleteCountdown(gameId);
            this.combatCountdownService.deleteCountdown(gameId); // Clean up combat timer if exists
            this.server.emit(GameCreationEvents.GameListUpdated);
        } else {
            // Move to next turn if game is still viable
            console.log(`[GameManagerGateway] Skipping to next turn - ${reason}`);
            this.prepareNextTurn(gameId);
        }
    }

    startTurn(gameId: string, iterationCount: number = 0): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            // Game has already ended - return silently to avoid console spam
            return;
        }
        if (!this.gameManagerService.isGameResumable(gameId)) {
            this.gameCreationService.deleteRoom(gameId);
            this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
            this.gameCountdownService.resetTimerSubscription(gameId);
            this.gameCountdownService.deleteCountdown(gameId);
            this.combatCountdownService.deleteCountdown(gameId); // Clean up combat timer if exists
            return;
        }

        if (iterationCount >= game.players.length) {
            this.gameCreationService.deleteRoom(gameId);
            this.challengeService.cleanupGame(game, GameEndReason.NoWinner_Termination);
            this.gameCountdownService.resetTimerSubscription(gameId);
            this.gameCountdownService.deleteCountdown(gameId);
            this.combatCountdownService.deleteCountdown(gameId);
            this.server.to(gameId).emit(GameCreationEvents.GameEndedNoActivePlayers);
            return;
        }

        const activePlayer = game.players.find((player) => player.turn === game.currentTurn);
        const involvedPlayers = game.players.map((player) => player.name);
        if (!activePlayer) {
            console.warn(
                `[GameManagerGateway] startTurn: No player found for turn index ${game.currentTurn}. Advancing turn (iteration ${iterationCount + 1}/${game.players.length})`,
            );
            game.currentTurn++;
            if (game.currentTurn >= game.players.length) {
                game.currentTurn = 0;
            }
            this.startTurn(gameId, iterationCount + 1);
            return;
        }
        const skipReasons: string[] = [];
        if (!activePlayer.isActive) {
            skipReasons.push('inactive');
        }
        if (activePlayer.isEliminated) {
            skipReasons.push('eliminated');
        }
        if (activePlayer.isObserver) {
            skipReasons.push('observer');
        }
        if (game.lastTurnPlayer && activePlayer.name === game.lastTurnPlayer) {
            skipReasons.push('already ended previous turn');
        }
        if (skipReasons.length > 0) {
            console.log(
                `[GameManagerGateway] startTurn: Skipping ${activePlayer.name} (${skipReasons.join(
                    ', ',
                )}) (iteration ${iterationCount + 1}/${game.players.length})`,
            );
            game.currentTurn++;
            if (game.currentTurn >= game.players.length) {
                game.currentTurn = 0;
            }
            this.startTurn(gameId, iterationCount + 1);
            return;
        }
        game.nTurns++;
        this.journalService.logMessage(gameId, `C'est au tour de ${activePlayer.name}.`, involvedPlayers);
        activePlayer.specs.movePoints = activePlayer.specs.speed;
        activePlayer.specs.actions = DEFAULT_ACTIONS;

        this.gameCountdownService.startNewCountdown(game);

        if (activePlayer.socketId.includes('virtualPlayer')) {
            const delay = Math.floor(Math.random() * VIRTUAL_PLAYER_DELAY) + VIRTUAL_DELAY_CONSTANT;
            setTimeout(async () => {
                try {
                    const currentGame = this.gameCreationService.getGameById(gameId);
                    if (!currentGame) {
                        console.warn(`[GameManagerGateway] Virtual player timeout: Game ${gameId} not found`);
                        return;
                    }

                    const currentPlayer = currentGame.players.find((p) => p.socketId === activePlayer.socketId);
                    if (!currentPlayer) {
                        console.warn(`[GameManagerGateway] Virtual player timeout: Player ${activePlayer.socketId} not found`);
                        return;
                    }

                    if (currentPlayer.turn !== currentGame.currentTurn) {
                        console.log(
                            `[GameManagerGateway] Virtual player ${currentPlayer.name} timeout expired but turn has already advanced (was ${currentPlayer.turn}, now ${currentGame.currentTurn}). Skipping.`,
                        );
                        return;
                    }

                    // Validate game state before executing
                    const validation = this.gameManagerService.validateGameState(gameId, activePlayer.socketId);

                    if (validation.recovered) {
                        console.log(`[GameManagerGateway] ✓ Recovered invalid position for virtual player, continuing turn...`);
                        this.gameManagerService.logGameStateDebug(gameId, 'VirtualPlayerPositionRecovered');
                    }

                    if (!validation.valid) {
                        console.warn(`[GameManagerGateway] Invalid game state for virtual player: ${validation.reason}`);
                        this.gameManagerService.logGameStateDebug(gameId, 'VirtualPlayerTurnError');
                        this.handleGameTermination(gameId, 'invalid game state');
                        return;
                    }

                    console.log(`[GameManagerGateway] Virtual player ${currentPlayer.name} executing turn...`);
                    await this.virtualGameManagerService.executeVirtualPlayerBehavior(currentPlayer, currentGame);
                    this.server.to(currentGame.id).emit(GameManagerEvents.PositionToUpdate, { game: currentGame, player: currentPlayer });

                    // prepareNextTurn is now handled by the virtualPlayerFinishedMoving event
                    // which is emitted by executeVirtualPlayerBehavior
                } catch (error) {
                    console.error(`[GameManagerGateway] Error during virtual player turn:`, error);
                    console.error(`[GameManagerGateway] Error stack:`, error.stack);
                    this.gameManagerService.logGameStateDebug(gameId, 'VirtualPlayerException');
                    this.handleGameTermination(gameId, 'error during virtual player turn');
                }
            }, delay);
        } else {
            // Safety check: Don't emit to invalidated/disconnected socketIds
            if (!activePlayer.socketId.startsWith('DISCONNECTED-')) {
                this.server.to(activePlayer.socketId).emit(GameTurnEvents.YourTurn, activePlayer);
            } else {
                console.warn(`[GameManagerGateway] Skipping YourTurn emission to invalidated socketId: ${activePlayer.socketId}`);
            }
        }

        game.players
            .filter((player) => player.socketId !== activePlayer.socketId)
            .forEach((player) => {
                if (player.socketId !== activePlayer.socketId) {
                    // Safety check: Don't emit to invalidated/disconnected socketIds
                    if (!player.socketId.startsWith('DISCONNECTED-')) {
                        this.server.to(player.socketId).emit(GameTurnEvents.PlayerTurn, activePlayer.name);
                    } else {
                        console.log(`[GameManagerGateway] Skipping PlayerTurn emission to invalidated socketId: ${player.socketId} (player: ${player.name})`);
                    }
                    
                    if (player.inventory.length > INVENTORY_SIZE) {
                        const coordinates = player.position;
                        this.itemsManagerService.dropItem(player.inventory[INVENTORY_SIZE], game.id, player, coordinates);
                        const itemDroppedData: ItemDroppedData = { updatedGame: game, updatedPlayer: player };
                        this.server.to(game.id).emit(ItemsEvents.ItemDropped, itemDroppedData);
                    }
                }
            });
    }

    async movePlayer(moves: Coordinate[], game: Game, wasOnIceTile: boolean, player: Player): Promise<boolean> {
        for (const move of moves) {
            this.gameManagerService.updatePosition(game.id, player.socketId, [move]);
            const onItem = this.itemsManagerService.onItem(player, game.id);
            if (onItem) {
                this.itemsManagerService.pickUpItem(move, game.id, player);
                if (player.inventory.length > INVENTORY_SIZE) {
                    this.server.to(player.socketId).emit(ItemsEvents.InventoryFull);
                }
            }
            wasOnIceTile = this.gameManagerService.adaptSpecsForIceTileMove(player, game.id, wasOnIceTile);
            this.server.to(game.id).emit(GameManagerEvents.PositionToUpdate, { game: game, player: player });
            await new Promise((resolve) => setTimeout(resolve, TIME_FOR_POSITION_UPDATE));
            if (this.gameManagerService.checkForWinnerCtf(player, game.id)) {
                const endResult = this.gameManagerService.checkAfterMove(game.id, player);
                this.gameManagerService.handleGameEnd(game.id, endResult, this.server);
                this.gameCountdownService.deleteCountdown(game.id);
                this.combatCountdownService.deleteCountdown(game.id); // Clean up combat timer if exists
                return true;
            }
        }
        return false;
    }
}
