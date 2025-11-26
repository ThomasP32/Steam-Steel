import { DoorTile } from '@app/http/model/schemas/map/tiles.schema';
import { ICE_ATTACK_PENALTY, ICE_DEFENSE_PENALTY, N_WIN_VICTORIES, ProfileType } from '@common/constants';
import { CORNER_DIRECTIONS, DIRECTIONS, MovesMap } from '@common/directions';
import { CombatEvents } from '@common/events/combat.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { Game, GameEndReason, GameEndResult, Player } from '@common/game';
import { Coordinate, ItemCategory, Mode, Tile, TileCategory } from '@common/map.types';
import { Inject, Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { ChallengeService } from '../challenge/challenge.service';
import { GameCreationService } from '../game-creation/game-creation.service';
import { UserSocketService } from '../user-socket/user-socket.service';

@Injectable()
export class GameManagerService {
    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(UserSocketService) private readonly userSocketService: UserSocketService;
    public hasFallen: boolean = false;

    updatePosition(gameId: string, playerSocket: string, path: Coordinate[]): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] updatePosition: Game ${gameId} not found (likely already ended)`);
            return;
        }
        const player = game.players.find((player) => player.socketId === playerSocket);
        if (player) {
            this.updatePlayerPosition(player, path, game);
            this.challengeService.onPlayerMove(game, player, path);
        }
    }

    updatePlayerPosition(player: Player, path: Coordinate[], game: Game): void {
        path.forEach((position) => {
            player.specs.movePoints -= this.getTileWeight(position, game);
            if (!player.visitedTiles.some((tile) => tile.x === position.x && tile.y === position.y)) {
                player.visitedTiles.push(position);
            }
        });
        player.position = path[path.length - 1];
    }

    updateTurnCounter(gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] updateTurnCounter: Game ${gameId} not found (likely already ended)`);
            return;
        }
        game.currentTurn++;
        if (game.currentTurn >= game.players.length) {
            game.currentTurn = 0;
        }
    }

    updatePlayerActions(gameId: string, playerSocket: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] updatePlayerActions: Game ${gameId} not found (likely already ended)`);
            return;
        }
        const player = game.players.find((player) => player.socketId === playerSocket);
        if (player) {
            player.specs.actions--;
        }
    }

    getMoves(
        gameId: string,
        playerSocket: string,
    ): [
        string,
        {
            path: Coordinate[];
            weight: number;
        },
    ][] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] getMoves: Game ${gameId} not found (likely already ended)`);
            return [];
        }
        const player = game.players.find((p) => p.socketId === playerSocket);
        if (!player?.isActive || !player.position) {
            console.warn(`[GameManagerService] getMoves: Player not found or invalid position`);
            return [];
        }
        const moves = this.runDijkstra(player.position, game, player.specs.movePoints);
        const mapAsArray = Array.from(moves.entries());
        return mapAsArray;
    }

    isPlayerStuck(gameId: string, playerSocket: string): boolean {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            return false;
        }
        const player = game.players.find((p) => p.socketId === playerSocket);
        if (!player?.isActive || !player.position) {
            return false;
        }

        // Player is stuck if they have:
        // 1. No actions left (actions <= 0)
        // 2. Movement points remaining (movePoints > 0)
        // 3. No valid moves available
        if (player.specs.actions > 0 || player.specs.movePoints <= 0) {
            return false;
        }

        const moves = this.runDijkstra(player.position, game, player.specs.movePoints);
        // Check if there are any moves beyond the current position
        // runDijkstra always includes current position, so check if size > 1
        return moves.size <= 1;
    }

    getMove(gameId: string, playerSocket: string, destination: Coordinate): Coordinate[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] getMove: Game ${gameId} not found (likely already ended)`);
            return [];
        }
        const player = game.players.find((p) => p.socketId === playerSocket);
        let shortestPath: Coordinate[];

        if (!player?.isActive) {
            return [];
        }

        const shortestPaths = this.runDijkstra(player.position, game, player.specs.movePoints);

        shortestPaths.forEach((value) => {
            const lastPosition = value.path[value.path.length - 1];
            if (lastPosition.x === destination.x && lastPosition.y === destination.y) {
                shortestPath = value.path;
            }
        });

        if (!shortestPath) {
            return [];
        } else {
            const finalPath: Coordinate[] = [];
            shortestPath.shift();
            for (const position of shortestPath) {
                if (this.onTileItem(position, game)) {
                    finalPath.push(position);
                    break;
                } else {
                    finalPath.push(position);
                }
            }

            return finalPath;
        }
    }

    runDijkstra(start: Coordinate, game: Game, playerPoints: number): MovesMap {
        const { shortestPaths, visited, toVisit } = this.initializeDijkstra(start);

        while (toVisit.length > 0) {
            toVisit.sort((a, b) => a.weight - b.weight);
            const { point: currentPoint, weight: currentWeight } = toVisit.shift();
            const currentKey = this.coordinateToKey(currentPoint);

            if (visited.has(currentKey) || currentWeight > playerPoints) continue;

            visited.add(currentKey);

            const neighbors = this.getNeighbors(currentPoint, game);

            for (const neighbor of neighbors) {
                const neighborKey = this.coordinateToKey(neighbor);

                if (visited.has(neighborKey)) continue;

                const neighborWeight = currentWeight + this.getTileWeight(neighbor, game);

                if (neighborWeight <= playerPoints) {
                    this.updateShortestPaths(shortestPaths, neighborKey, currentKey, neighbor, neighborWeight);
                    toVisit.push({ point: neighbor, weight: neighborWeight });
                }
            }
        }
        return shortestPaths;
    }

    private updateShortestPaths(shortestPaths: MovesMap, neighborKey: string, currentKey: string, neighbor: Coordinate, neighborWeight: number) {
        const currentPath = shortestPaths.get(currentKey)?.path || [];
        const newPath = [...currentPath, neighbor];

        if (!shortestPaths.has(neighborKey) || neighborWeight < shortestPaths.get(neighborKey).weight) {
            shortestPaths.set(neighborKey, { path: newPath, weight: neighborWeight });
        }
    }

    private initializeDijkstra(start: Coordinate): {
        shortestPaths: Map<string, { path: Coordinate[]; weight: number }>;
        visited: Set<string>;
        toVisit: { point: Coordinate; weight: number }[];
    } {
        const shortestPaths = new Map<string, { path: Coordinate[]; weight: number }>();
        const visited = new Set<string>();
        const startKey = this.coordinateToKey(start);
        shortestPaths.set(startKey, { path: [start], weight: 0 });
        const toVisit = [{ point: start, weight: 0 }];
        return { shortestPaths, visited, toVisit };
    }

    coordinateToKey(coord: Coordinate): string {
        if (!coord) {
            console.error('[GameManagerService] coordinateToKey: coordinate is undefined');
            return '0,0';
        }
        return `${coord.x},${coord.y}`;
    }

    private getNeighbors(pos: Coordinate, game: Game): Coordinate[] {
        const neighbors: Coordinate[] = [];
        DIRECTIONS.forEach((dir) => {
            const neighbor = { x: pos.x + dir.x, y: pos.y + dir.y };
            if (!this.isOutOfMap(neighbor, game.mapSize) && this.isReachableTile(neighbor, game)) {
                neighbors.push(neighbor);
            }
        });
        return neighbors;
    }

    public isOutOfMap(pos: Coordinate, mapSize: Coordinate): boolean {
        return pos.x < 0 || pos.y < 0 || pos.x >= mapSize.x || pos.y >= mapSize.y;
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
        return true;
    }

    private onTileItem(pos: Coordinate, game: Game): boolean {
        return game.items.some((item) => item.coordinate.x === pos.x && item.coordinate.y === pos.y);
    }

    getTileWeight(pos: Coordinate, game: Game): number {
        for (const tile of game.tiles) {
            if (tile.coordinate.x === pos.x && tile.coordinate.y === pos.y) {
                if (tile.category === TileCategory.Water) return 2;
                if (tile.category === TileCategory.Ice) return 0;
            }
        }
        return 1;
    }

    onIceTile(player: Player, gameId: string): boolean {
        if (!player?.position) return false;
        return this.gameCreationService
            .getGameById(gameId)
            .tiles.some(
                (tile) => tile.coordinate.x === player.position.x && tile.coordinate.y === player.position.y && tile.category === TileCategory.Ice,
            );
    }

    shouldHaveIcePenalties(player: Player, gameId: string): boolean {
        const isOnIce = this.onIceTile(player, gameId);
        const hasSkates = player.inventory.includes(ItemCategory.IceSkates);
        return isOnIce && !hasSkates;
    }

    resetIceAttributes(player: Player, gameId: string): void {
        const shouldHavePenalties = this.shouldHaveIcePenalties(player, gameId);

        if (shouldHavePenalties) {
            if (player.specs.attack > 4 - ICE_ATTACK_PENALTY || player.specs.defense > 4 - ICE_DEFENSE_PENALTY) {
                player.specs.attack -= ICE_ATTACK_PENALTY;
                player.specs.defense -= ICE_DEFENSE_PENALTY;
            }
        } else {
            if (player.specs.attack < 4 && player.specs.defense < 4) {
                player.specs.attack += ICE_ATTACK_PENALTY;
                player.specs.defense += ICE_DEFENSE_PENALTY;
            }
        }
    }

    hasPickedUpFlag(oldInventory: ItemCategory[], newInventory: ItemCategory[]): boolean {
        return !oldInventory.some((item) => item === ItemCategory.Flag) && newInventory.some((item) => item === ItemCategory.Flag);
    }

    getAdjacentPlayers(player: Player, gameId: string): Player[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] getAdjacentPlayers: Game ${gameId} not found (likely already ended)`);
            return [];
        }
        const adjacentPlayers: Player[] = [];
        if (game?.players && player?.position) {
            game.players.forEach((otherPlayer) => {
                if (otherPlayer.isActive && !otherPlayer.isEliminated && otherPlayer.position) {
                    if (otherPlayer.socketId !== player.socketId) {
                        const isAdjacent = DIRECTIONS.some(
                            (direction) =>
                                otherPlayer.position.x === player.position.x + direction.x &&
                                otherPlayer.position.y === player.position.y + direction.y,
                        );
                        if (isAdjacent) {
                            adjacentPlayers.push(otherPlayer);
                        }
                    }
                }
            });
        }
        return adjacentPlayers;
    }

    getAdjacentDoors(player: Player, gameId: string): DoorTile[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] getAdjacentDoors: Game ${gameId} not found (likely already ended)`);
            return [];
        }
        if (!player?.position) {
            console.warn(`[GameManagerService] getAdjacentDoors: Player has no position`);
            return [];
        }
        const adjacentDoors: DoorTile[] = [];

        const adjacentPlayers = this.getAdjacentPlayers(player, gameId);

        game.doorTiles.forEach((door) => {
            const isAdjacent = DIRECTIONS.some(
                (direction) => door.coordinate.x === player.position.x + direction.x && door.coordinate.y === player.position.y + direction.y,
            );

            const isOccupied = adjacentPlayers.some(
                (adjPlayer) => adjPlayer.position && adjPlayer.position.x === door.coordinate.x && adjPlayer.position.y === door.coordinate.y,
            );

            if (isAdjacent && !isOccupied) {
                adjacentDoors.push(door);
            }
        });

        return adjacentDoors;
    }

    getAdjacentWalls(player: Player, gameId: string): Tile[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] getAdjacentWalls: Game ${gameId} not found (likely already ended)`);
            return [];
        }
        if (!player?.position) {
            console.warn(`[GameManagerService] getAdjacentWalls: Player has no position`);
            return [];
        }
        const adjacentWalls: Tile[] = [];

        game.tiles.forEach((tile) => {
            const isAdjacent = DIRECTIONS.some(
                (direction) => tile.coordinate.x === player.position.x + direction.x && tile.coordinate.y === player.position.y + direction.y,
            );

            if (isAdjacent && tile.category === TileCategory.Wall) {
                const hasAdjacentDoor = DIRECTIONS.some((direction) => {
                    const adjacentPosition = { x: tile.coordinate.x + direction.x, y: tile.coordinate.y + direction.y };
                    return game.doorTiles.some((door) => door.coordinate.x === adjacentPosition.x && door.coordinate.y === adjacentPosition.y);
                });

                if (!hasAdjacentDoor) {
                    adjacentWalls.push(tile);
                }
            }
        });

        return adjacentWalls;
    }
    adaptSpecsForIceTileMove(player: Player, gameId: string, wasOnIceTile: boolean): boolean {
        const isOnIceTile = this.onIceTile(player, gameId);
        const hasSkates = player.inventory.includes(ItemCategory.IceSkates);

        if (!hasSkates) {
            if (isOnIceTile && !wasOnIceTile) {
                if (player.specs.attack >= 4 && player.specs.defense >= 4) {
                    player.specs.attack -= ICE_ATTACK_PENALTY;
                    player.specs.defense -= ICE_DEFENSE_PENALTY;
                }
                wasOnIceTile = true;
            } else if (!isOnIceTile && wasOnIceTile) {
                if (player.specs.attack < 4 && player.specs.defense < 4) {
                    player.specs.attack += ICE_ATTACK_PENALTY;
                    player.specs.defense += ICE_DEFENSE_PENALTY;
                }
                wasOnIceTile = false;
            }
        } else {
            if (player.specs.attack < 4 && player.specs.defense < 4) {
                player.specs.attack += ICE_ATTACK_PENALTY;
                player.specs.defense += ICE_DEFENSE_PENALTY;
            }
            wasOnIceTile = isOnIceTile;
        }

        return wasOnIceTile;
    }

    getFirstFreePosition(start: Coordinate, game: Game): Coordinate | null {
        const allDirections = [...DIRECTIONS, ...CORNER_DIRECTIONS];

        for (const direction of allDirections) {
            const newPosition: Coordinate = {
                x: start.x + direction.x,
                y: start.y + direction.y,
            };
            //@chargé, on empêche l'item de drop sur une case de départ
            const isStartTile = game.startTiles.some((tile) => tile.coordinate.x === newPosition.x && tile.coordinate.y === newPosition.y);

            if (
                !this.isOutOfMap(newPosition, game.mapSize) &&
                this.isReachableTile(newPosition, game) &&
                !this.onTileItem(newPosition, game) &&
                !game.players.some((player) => player.position && player.position.x === newPosition.x && player.position.y === newPosition.y) &&
                !isStartTile
            ) {
                return newPosition;
            }
        }
        return null;
    }

    isGameResumable(gameId: string): boolean {
        return (
            this.gameCreationService.getGameById(gameId) &&
            !!this.gameCreationService.getGameById(gameId).players.find((player) => player.isActive && !player.isEliminated && !player.isObserver)
        );
    }

    checkForWinnerCtf(player: Player, gameId: string): boolean {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[GameManagerService] checkForWinnerCtf: Game ${gameId} not found (likely already ended)`);
            return false;
        }
        if (game && game.mode === Mode.Ctf) {
            if (player.inventory.includes(ItemCategory.Flag) && player.position && player.initialPosition) {
                return player.position.x === player.initialPosition.x && player.position.y === player.initialPosition.y;
            }
        }
        return false;
    }

    markCtfGameWinners(gameId: string, game: Game) {
        let winnerFound = false;
        for (const player of game.players) {
            if (!winnerFound && this.checkForWinnerCtf(player, gameId)) {
                player.isGameWinner = true;
                winnerFound = true;
            } else {
                player.isGameWinner = false;
            }
        }
    }

    shouldTerminateGame(gameId: string): boolean {
        const endResult = this.checkAfterDisconnect(gameId);
        return endResult.reason === GameEndReason.NoWinner_Termination;
    }

    validateGameState(gameId: string, playerSocketId: string): { valid: boolean; reason?: string; recovered?: boolean } {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            return { valid: false, reason: `Game ${gameId} not found` };
        }

        const player = game.players.find((p) => p.socketId === playerSocketId);
        if (!player) {
            return { valid: false, reason: `Player ${playerSocketId} not found in game` };
        }

        if (!player.isActive) {
            return { valid: false, reason: `Player ${player.name} is not active` };
        }

        // Check if position is undefined or has invalid coordinates
        if (!player.position || player.position.x === undefined || player.position.y === undefined) {
            console.warn(`[GameManagerService] Player ${player.name} has invalid position, attempting recovery...`);

            // Attempt to recover by sending player to initial position
            if (player.initialPosition && player.initialPosition.x !== undefined && player.initialPosition.y !== undefined) {
                const isPositionOccupied = game.players.some(
                    (otherPlayer) =>
                        otherPlayer.socketId !== player.socketId &&
                        otherPlayer.position &&
                        otherPlayer.position.x === player.initialPosition.x &&
                        otherPlayer.position.y === player.initialPosition.y,
                );

                if (!isPositionOccupied) {
                    player.position = { x: player.initialPosition.x, y: player.initialPosition.y };
                    console.log(
                        `[GameManagerService] ✓ Recovered position for ${player.name} at initial position (${player.position.x}, ${player.position.y})`,
                    );
                    return { valid: true, recovered: true };
                } else {
                    // Find closest available position
                    const closestPosition = this.getFirstFreePosition(player.initialPosition, game);
                    if (closestPosition) {
                        player.position = closestPosition;
                        console.log(
                            `[GameManagerService] ✓ Recovered position for ${player.name} near initial position at (${player.position.x}, ${player.position.y})`,
                        );
                        return { valid: true, recovered: true };
                    }
                }
            }

            return { valid: false, reason: `Player ${player.name} has no position and recovery failed` };
        }

        return { valid: true };
    }

    logGameStateDebug(gameId: string, context: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.log(`[DEBUG ${context}] Game ${gameId} not found`);
            return;
        }

        console.log(`[DEBUG ${context}] Game ${gameId}:`);
        console.log(`  - Players: ${game.players.length}`);
        game.players.forEach((p, i) => {
            console.log(
                `    ${i}. ${p.name} (${p.socketId.substring(0, 8)}...) - Active: ${p.isActive}, Observing: ${p.isEliminated}, Position: ${
                    p.position ? `(${p.position.x},${p.position.y})` : 'UNDEFINED'
                }`,
            );
        });
        console.log(`  - Current turn: ${game.currentTurn}`);
        console.log(`  - Turn count: ${game.nTurns}`);
    }

    // ===== Centralized Game Ending Logic =====

    /**
     * Helper: Get count of active non-observer players
     */
    private getActiveNonObserverCount(gameId: string): number {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return 0;
        return game.players.filter((p) => p.isActive && !p.isEliminated && !p.isObserver).length;
    }

    /**
     * Helper: Get list of active non-observer players
     */
    private getActiveNonObservers(gameId: string): Player[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return [];
        return game.players.filter((p) => p.isActive && !p.isEliminated && !p.isObserver);
    }

    /**
     * Helper: Get count of active non-observer real (non-virtual) players
     */
    private getActiveRealPlayerCount(gameId: string): number {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return 0;
        return game.players.filter((p) => p.isActive && !p.isObserver && p.profile === ProfileType.NORMAL).length;
    }

    /**
     * Helper: Get list of active non-observer real (non-virtual) players
     */
    private getActiveRealPlayers(gameId: string): Player[] {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return [];
        return game.players.filter((p) => p.isActive && !p.isObserver && p.profile === ProfileType.NORMAL);
    }

    /**
     * Helper: Check if player has 3 victories (Classic mode only)
     */
    private hasThreeVictories(player: Player, gameId: string): boolean {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game || game.mode !== Mode.Classic) return false;
        return player.specs.nVictories >= N_WIN_VICTORIES;
    }

    /**
     * Helper: Mark a player as the game winner
     */
    private markGameWinner(gameId: string, winner: Player): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;

        game.players.forEach((player) => {
            player.isGameWinner = player.socketId === winner.socketId;
        });
    }

    /**
     * Check game end condition after a player disconnects or leaves
     * Checks for:
     * - Last player standing (1 real player left in CTF/Classic modes)
     * - Termination (< 2 active non-observers and no real players)
     */
    checkAfterDisconnect(gameId: string): GameEndResult {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return { reason: GameEndReason.Ongoing };

        const count = this.getActiveNonObserverCount(gameId);

        // Debug: Log all players and their state
        console.log(`[GameManager] checkAfterDisconnect for game ${gameId}:`);
        if (game) {
            game.players.forEach((p) => {
                console.log(`  - ${p.name} (${p.socketId}): isActive=${p.isActive}, isEliminated=${p.isEliminated}, isObserver=${p.isObserver}`);
            });
        }
        console.log(`  Total active count: ${count}`);

        // Only terminate if less than 2 players total
        if (count < 2) {
            const lastPlayer = this.getActiveNonObservers(gameId);
            const winner = lastPlayer[0];
            console.log(`[GameManager] Victory by last player standing: ${winner.name}`);
            this.markGameWinner(gameId, winner);
            return {
                reason: GameEndReason.Victory_LastPlayerStanding,
                winner,
            };
        }

        return { reason: GameEndReason.Ongoing };
    }

    /**
     * Check game end condition after a combat ends
     * Checks for elimination victory (1 player left) or 3-win victory (Classic mode)
     */
    checkAfterCombat(gameId: string, winner: Player, isFastElimination: boolean): GameEndResult {
        const activePlayers = this.getActiveNonObservers(gameId);

        // Check elimination (1 player left)
        if (isFastElimination && activePlayers.length === 1) {
            console.log(`[GameManager] Victory by elimination: ${activePlayers[0].name}`);
            this.markGameWinner(gameId, activePlayers[0]);
            return {
                reason: GameEndReason.Victory_Elimination,
                winner: activePlayers[0],
            };
        }

        // Check 3 victories (Classic mode)
        if (this.hasThreeVictories(winner, gameId)) {
            console.log(`[GameManager] Victory by 3 wins: ${winner.name}`);
            this.markGameWinner(gameId, winner);
            return {
                reason: GameEndReason.Victory_CombatWins,
                winner,
            };
        }

        return { reason: GameEndReason.Ongoing };
    }

    /**
     * Check game end condition after a player moves
     * Checks for CTF flag victory
     */
    checkAfterMove(gameId: string, player: Player): GameEndResult {
        if (this.checkForWinnerCtf(player, gameId)) {
            console.log(`[GameManager] CTF victory: ${player.name}`);
            this.markCtfGameWinners(gameId, this.gameCreationService.getGameById(gameId));
            return {
                reason: GameEndReason.Victory_CtfFlag,
                winner: player,
            };
        }

        return { reason: GameEndReason.Ongoing };
    }

    /**
     * Handle game end based on the end result
     * Emits appropriate events and cleans up resources
     * Note: Caller (gateways) should also delete countdown and cleanup combat resources
     *
     * IMPORTANT: This method marks the game for deletion. Any timers or callbacks
     * that reference this game should check if the game still exists before proceeding.
     */
    async handleGameEnd(gameId: string, endResult: GameEndResult, server: Server): Promise<void> {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;

        console.log(`[GameManager] Ending game ${gameId}, reason: ${endResult.reason}`);
        await this.challengeService.cleanupGame(game, endResult.reason);

        // Termination (no winner)
        if (endResult.reason === GameEndReason.NoWinner_Termination) {
            server.to(gameId).emit(GameCreationEvents.GameEndedNoActivePlayers);
            await this.gameCreationService.endGameAndDistributeRewards(gameId, [], []);
            await this.gameCreationService.deleteRoom(gameId);
            server.emit(GameCreationEvents.GameListUpdated);
            return;
        }

        const { winners, activePlayers } = this.gameCreationService.getPlayerUserIdsForRewards(gameId, (socketId) =>
            this.userSocketService.getUserIdBySocket(socketId),
        );
        const rewardsMap = await this.gameCreationService.endGameAndDistributeRewards(gameId, winners, activePlayers);

        const rewardsObject = this.gameCreationService.convertUserRewardsToSocketRewards(gameId, rewardsMap, (userId) =>
            this.userSocketService.getSocketId(userId),
        );

        server.to(gameId).emit(CombatEvents.GameFinished, { updatedGame: game, moneyRewards: rewardsObject, reason: endResult.reason });
        server.to(gameId).emit(CombatEvents.GameFinishedPlayerWon, { winner: endResult.winner, reason: endResult.reason });

        // Delete the room and notify all clients to update their game list
        await this.gameCreationService.deleteRoom(gameId);
        server.emit(GameCreationEvents.GameListUpdated);
    }
}
