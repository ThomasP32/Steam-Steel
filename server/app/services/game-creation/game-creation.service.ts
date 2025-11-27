import { ALL_ITEMS, BONUS_REDUCTION, HALF, MapConfig, MapSize } from '@common/constants';
import { Game, GameCtf, Player } from '@common/game';
import { Coordinate, ItemCategory, Mode, TileCategory } from '@common/map.types';
import { Inject, Injectable } from '@nestjs/common';
import { Socket } from 'socket.io';
import { ChallengeService } from '../challenge/challenge.service';
import { ShopService } from '../shop/shop.service';

@Injectable()
export class GameCreationService {
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    @Inject(ShopService) private readonly shopService: ShopService;
    private gameRooms: Record<string, Game> = {};
    private gamePrizePools: Record<string, { totalPool: number; playerEntries: Map<string, number> }> = {};

    getGameById(gameId: string): Game {
        const game = this.gameRooms[gameId];
        if (!game) {
            return null;
        }
        return game;
    }

    getGames(): Game[] {
        return Object.values(this.gameRooms);
    }

    getPlayer(gameId: string, playerSocketId: string): Player {
        const game = this.getGameById(gameId);
        return game.players.filter((player) => player.socketId === playerSocketId)[0];
    }

    addGame(game: Game): void {
        if (this.doesGameExist(game.id)) {
            return;
        }
        // Initialize nPlayersCtf for CTF games
        if (game.mode === Mode.Ctf) {
            const ctfGame = game as GameCtf;
            if (!ctfGame.nPlayersCtf) {
                ctfGame.nPlayersCtf = [];
            }
        }
        this.gameRooms[game.id] = game;
        if (!this.gamePrizePools[game.id]) {
            this.gamePrizePools[game.id] = {
                totalPool: 0,
                playerEntries: new Map<string, number>(),
            };
        }
    }

    doesGameExist(gameId: string): boolean {
        return gameId in this.gameRooms;
    }

    async addPlayerToGame(
        socketId: string,
        player: Player,
        gameId: string,
        userId?: string,
    ): Promise<{ success: boolean; game?: Game; message?: string }> {
        const game = this.getGameById(gameId);

        const entryFee = game.settings?.entryFee || 0;
        if (!game.hasStarted && entryFee > 0 && userId) {
            const canAfford = await this.shopService.canAfford(userId, entryFee);
            if (!canAfford) {
                return { success: false, message: `Vous n'avez pas assez de monnaie virtuelle. Frais d'entrée: ${entryFee}` };
            }

            const paymentSuccess = await this.shopService.deductMoney(userId, entryFee);
            if (!paymentSuccess) {
                return { success: false, message: "Erreur lors du paiement des frais d'entrée" };
            }

            if (!this.gamePrizePools[gameId]) {
                this.gamePrizePools[gameId] = {
                    totalPool: 0,
                    playerEntries: new Map<string, number>(),
                };
            }

            this.gamePrizePools[gameId].totalPool += entryFee;
            this.gamePrizePools[gameId].playerEntries.set(userId, entryFee);
            console.log(`[addPlayerToGame] Player ${userId} paid ${entryFee}, total pool: ${this.gamePrizePools[gameId].totalPool}`);
        }
        if (player.isEliminated === undefined) {
            player.isEliminated = false;
        }

        const existingPlayer = game.players.find((plyr) => plyr.name === player.name);
        if (existingPlayer) {
            if (game.settings.isFastElimination && existingPlayer.specs.nDefeats === 1) {
                existingPlayer.isActive = false;
                existingPlayer.isEliminated = true;

            } else {
                // Only set isActive = true if player is not eliminated and not an observer
                if (!existingPlayer.isEliminated && !existingPlayer.isObserver) {
                    existingPlayer.isActive = true;
                    // Mark as active player when they rejoin as an active participant
                    if (existingPlayer.wasActivePlayer === undefined || existingPlayer.wasActivePlayer === false) {
                        existingPlayer.wasActivePlayer = true;
                    }
                } else {
                    existingPlayer.isActive = false;
                }
                // Preserve elimination status if game has started - don't reset eliminated players
                if (!game.hasStarted) {
                    existingPlayer.isEliminated = false;
                }
                existingPlayer.inventory = [];
            }
            existingPlayer.socketId = socketId;
        } else {
            // Ensure inventory is initialized for new players
            if (!player.inventory) {
                player.inventory = [];
            }
            // Mark new players as active participants (not observers)
            player.wasActivePlayer = true;
            this.gameRooms[gameId].players.push(player);

            // Assign challenge to new player
            if (!player.socketId.includes('virtual')) {
                console.log(`[GameCreationService] Assigning challenge to new player ${player.name}`);
                this.challengeService.assignForPlayer(game, player);
            }

            return { success: true, game };
        }
        return { success: true, game };
    }

    addRandomItemsToGame(gameId: string): void {
        const game = this.getGameById(gameId);

        const currentItems = game.items;
        const availableItems = ALL_ITEMS.filter((item) => !currentItems.some((currentItem) => currentItem.category === item));

        game.items = currentItems.map((currentItem) => {
            if (currentItem.category === ItemCategory.Random) {
                const randomIndex = Math.floor(Math.random() * availableItems.length);
                const newItem = availableItems.splice(randomIndex, 1)[0];
                return {
                    coordinate: currentItem.coordinate,
                    category: newItem,
                };
            }
            return currentItem;
        });
    }

    isPlayerHost(socketId: string, gameId: string): boolean {
        return this.getGameById(gameId).hostSocketId === socketId;
    }

    private async handlePlayerRefund(gameId: string, userId: string): Promise<number> {
        const game = this.getGameById(gameId);

        if (game.hasStarted) {
            return 0;
        }

        if (!this.gamePrizePools[gameId]?.playerEntries.has(userId)) {
            return 0;
        }

        const entryFee = this.gamePrizePools[gameId].playerEntries.get(userId);
        console.log(`[handlePlayerRefund] Refunding ${entryFee} to user ${userId}`);

        if (entryFee > 0) {
            await this.shopService.refundPlayer(userId, entryFee);
            this.gamePrizePools[gameId].totalPool -= entryFee;
            this.gamePrizePools[gameId].playerEntries.delete(userId);
            console.log(`[handlePlayerRefund] Refund successful: ${entryFee}`);
            return entryFee;
        }

        return 0;
    }

    async handlePlayerLeaving(client: Socket, gameId: string, userId?: string): Promise<{ game: Game; refundAmount: number }> {
        const game = this.getGameById(gameId);
        let refundAmount = 0;

        console.log(`[handlePlayerLeaving] Game ${gameId}, userId: ${userId}, hasStarted: ${game.hasStarted}`);

        if (userId) {
            refundAmount = await this.handlePlayerRefund(gameId, userId);
        }

        if (game.hasStarted) {
            const leavingPlayer = game.players.find((player) => player.socketId === client.id);
            
            // If player was only an observer (never active participant) and was not eliminated, remove them from the game
            if (!leavingPlayer?.wasActivePlayer && leavingPlayer?.isObserver && !leavingPlayer?.isEliminated) {
                game.players = game.players.filter((player) => player.socketId !== client.id);
            } else {
                game.players = game.players.map((player) => {
                    if (player.socketId === client.id) {
                        // CRITICAL: Invalidate socketId to prevent turn events from being sent to this socket
                        // The socketId is used to send events directly, so we must invalidate it when player leaves
                        const invalidatedSocketId = `DISCONNECTED-${Date.now()}-${client.id}`;
                        console.log(`[GameCreationService] Invalidating socketId for ${player.name} in game ${gameId}: ${client.id} -> ${invalidatedSocketId}`);
                        
                        // If game is in elimination mode, set player as eliminated (only if they were an active player)
                        if (game.settings.isFastElimination) {
                            return { ...player, isActive: false, isEliminated: true, isObserver: false, socketId: invalidatedSocketId };
                        }
                        return { ...player, isActive: false, isObserver: false, socketId: invalidatedSocketId };
                    }
                    return player;
                });
            }
        } else {
            game.players = game.players.filter((player) => player.socketId !== client.id);
            if (!this.isMaxPlayersReached(gameId)) {
                game.isLocked = false;
            }
        }

        return { game: this.getGameById(gameId), refundAmount };
    }

    async handleHostLeaving(gameId: string, hostUserId: string): Promise<number> {
        console.log(`[handleHostLeaving] Game ${gameId}, hostUserId: ${hostUserId}`);
        return await this.handlePlayerRefund(gameId, hostUserId);
    }

    async refundAllPlayersInGame(gameId: string): Promise<{ totalRefunded: number; refundedUsers: string[] }> {
        const prizePool = this.gamePrizePools[gameId];
        if (!prizePool || prizePool.playerEntries.size === 0) {
            return { totalRefunded: 0, refundedUsers: [] };
        }

        const game = this.getGameById(gameId);
        if (game.hasStarted) {
            console.log(`[refundAllPlayersInGame] Game ${gameId} has already started, no refunds`);
            return { totalRefunded: 0, refundedUsers: [] };
        }

        let totalRefunded = 0;
        const refundedUsers: string[] = [];

        for (const [userId, entryFee] of prizePool.playerEntries.entries()) {
            if (entryFee > 0) {
                await this.shopService.refundPlayer(userId, entryFee);
                totalRefunded += entryFee;
                refundedUsers.push(userId);
                console.log(`[refundAllPlayersInGame] Refunded ${entryFee} to user ${userId}`);
            }
        }

        prizePool.totalPool = 0;
        prizePool.playerEntries.clear();

        console.log(`[refundAllPlayersInGame] Total refunded: ${totalRefunded} to ${refundedUsers.length} players`);
        return { totalRefunded, refundedUsers };
    }

    async handlePlayerKicked(gameId: string, playerId: string, userId?: string): Promise<{ updatedGame: Game; refundAmount: number }> {
        const game = this.getGameById(gameId);
        let refundAmount = 0;

        console.log(`[handlePlayerKicked] Game ${gameId}, playerId: ${playerId}, userId: ${userId}`);

        if (userId) {
            refundAmount = await this.handlePlayerRefund(gameId, userId);
        }

        game.players = game.players.filter((player) => player.socketId !== playerId);

        console.log(`Player with socket ID ${playerId} has been kicked from game ${gameId}, refund: ${refundAmount}`);
        return { updatedGame: game, refundAmount };
    }

    initializeGame(gameId: string): void {
        this.setOrder(gameId);
        this.setStartingPoints(gameId);
        this.addRandomItemsToGame(gameId);
        this.getGameById(gameId).hasStarted = true;
        this.getGameById(gameId).isLocked = true;
    }

    setOrder(gameId: string): void {
        const game = this.getGameById(gameId);
        const updatedPlayers = game.players.sort((player1, player2) => {
            const speedDifference = player2.specs.speed - player1.specs.speed;
            return speedDifference === 0 ? Math.random() - HALF : speedDifference;
        });
        updatedPlayers.forEach((player, index) => {
            player.turn = index;
        });
        game.players = updatedPlayers;
    }

    setStartingPoints(gameId: string): void {
        const game = this.getGameById(gameId);
        const nPlayers = game.players.length;
        while (game.startTiles.length > nPlayers) {
            const randomIndex = Math.floor(Math.random() * game.startTiles.length);
            game.startTiles.splice(randomIndex, 1);
        }
        let startTilesLeft = [...game.startTiles];

        if (game.mode === Mode.Ctf) {
            const ctfGame = game as GameCtf;
            ctfGame.playerStartTiles = [];
        }

        game.players.forEach((player) => {
            const randomIndex = Math.floor(Math.random() * startTilesLeft.length);
            const assignedTile = startTilesLeft[randomIndex];

            player.position.x = assignedTile.coordinate.x;
            player.position.y = assignedTile.coordinate.y;
            player.initialPosition.x = assignedTile.coordinate.x;
            player.initialPosition.y = assignedTile.coordinate.y;

            if (game.mode === Mode.Ctf) {
                const ctfGame = game as GameCtf;
                ctfGame.playerStartTiles.push({
                    socketId: player.socketId,
                    coordinate: { x: assignedTile.coordinate.x, y: assignedTile.coordinate.y },
                });
            }

            if (
                game.tiles.some(
                    (tile) =>
                        tile.coordinate.x === assignedTile.coordinate.x &&
                        tile.coordinate.y === assignedTile.coordinate.y &&
                        tile.category === TileCategory.Ice,
                )
            ) {
                player.specs.attack -= BONUS_REDUCTION;
                player.specs.defense -= BONUS_REDUCTION;
            }
            startTilesLeft.splice(randomIndex, 1);
        });
    }

    sameCoords(coordsA: Coordinate, coordsB: Coordinate) {
        return coordsA.x === coordsB.x && coordsA.y === coordsB.y;
    }

    isGameStartable(gameId: string): boolean {
        const game = this.getGameById(gameId);
        const mapSize = Object.values(MapSize).find((size) => MapConfig[size].size === game.mapSize.x);

        if (mapSize) {
            const activePlayersCount = game.players.filter((player) => player.isActive && !player.isObserver).length;
            return activePlayersCount >= MapConfig[mapSize].minPlayers;
        }
        return false;
    }

    isMaxPlayersReached(gameId: string): boolean {
        const game = this.getGameById(gameId);
        const mapSize = Object.values(MapSize).find((size) => MapConfig[size].size === game.mapSize.x);
        const activeOrEliminatedCount = game.players.filter((p) => p.isActive || p.isEliminated).length;
        return mapSize && activeOrEliminatedCount >= MapConfig[mapSize].maxPlayers;
    }

    lockGame(gameId: string): void {
        this.gameRooms[gameId].isLocked = true;
    }

    async deleteRoom(gameId: string): Promise<void> {
        delete this.gameRooms[gameId];
        delete this.gamePrizePools[gameId];
    }

    async endGameAndDistributeRewards(gameId: string, winners: string[] = [], activePlayers: string[] = []): Promise<Map<string, number>> {
        console.log(`[endGameAndDistributeRewards] Game ${gameId} ending. Winners: ${winners.length}, Active players: ${activePlayers.length}`);

        let rewardsMap = new Map<string, number>();

        if (winners.length > 0 || activePlayers.length > 0) {
            rewardsMap = await this.distributeGameRewards(gameId, winners, activePlayers);
        }

        for (const winnerId of winners) {
            await this.shopService.addMoney(winnerId, 50);
            const currentReward = rewardsMap.get(winnerId) || 0;
            rewardsMap.set(winnerId, currentReward + 50);
        }

        const otherActivePlayers = activePlayers.filter((playerId) => !winners.includes(playerId));
        for (const playerId of otherActivePlayers) {
            await this.shopService.addMoney(playerId, 30);
            const currentReward = rewardsMap.get(playerId) || 0;
            rewardsMap.set(playerId, currentReward + 30);
        }

        this.deleteRoom(gameId);
        return rewardsMap;
    }

    getPlayerUserIdsForRewards(
        gameId: string,
        // eslint-disable-next-line no-unused-vars
        getUserIdBySocket: (socketId: string) => string | undefined,
    ): { winners: string[]; activePlayers: string[] } {
        const game = this.getGameById(gameId);
        if (!game) {
            return { winners: [], activePlayers: [] };
        }

        const winners: string[] = [];
        const activePlayers: string[] = [];

        for (const player of game.players) {
            if (player.socketId.includes('virtualPlayer')) {
                continue;
            }

            const userId = getUserIdBySocket(player.socketId);
            if (!userId) {
                continue;
            }

            if (player.isActive) {
                activePlayers.push(userId);
            }

            if (player.isGameWinner) {
                winners.push(userId);
            }
        }

        return { winners, activePlayers };
    }

    async distributeGameRewards(gameId: string, winners: string[], activePlayers: string[]): Promise<Map<string, number>> {
        const rewardsMap = new Map<string, number>();
        const prizePool = this.gamePrizePools[gameId];
        if (!prizePool || prizePool.totalPool <= 0) {
            return rewardsMap;
        }

        if (activePlayers.length === 1) {
            const result = await this.shopService.distributeLastPlayerWinnings(prizePool.totalPool, activePlayers[0]);
            if (result.success) {
                rewardsMap.set(activePlayers[0], result.amount);
            }
            return rewardsMap;
        }

        const result = await this.shopService.distributeGameWinnings(prizePool.totalPool, winners, activePlayers);
        if (result.success) {
            for (const winnerId of winners) {
                rewardsMap.set(winnerId, result.winnerAmount);
            }
            const otherPlayers = activePlayers.filter((id) => !winners.includes(id));
            for (const playerId of otherPlayers) {
                rewardsMap.set(playerId, result.consolationAmount);
            }
        }
        return rewardsMap;
    }

    getGamePrizePool(gameId: string): number {
        return this.gamePrizePools[gameId]?.totalPool || 0;
    }

    convertUserRewardsToSocketRewards(
        gameId: string,
        userRewardsMap: Map<string, number>,
        // eslint-disable-next-line no-unused-vars
        getSocketIdByUserId: (userId: string) => string | undefined,
    ): { [key: string]: number } {
        const socketRewards: { [key: string]: number } = {};
        for (const [userId, amount] of userRewardsMap) {
            const socketId = getSocketIdByUserId(userId);
            if (socketId) {
                socketRewards[socketId] = amount;
            }
        }

        return socketRewards;
    }

    async chargeHostForGameCreation(userId: string, gameId: string, entryFee: number): Promise<boolean> {
        const canAfford = await this.shopService.canAfford(userId, entryFee);
        if (!canAfford) {
            console.log(`[chargeHostForGameCreation] Host ${userId} cannot afford entry fee of ${entryFee}`);
            return false;
        }

        const paymentSuccess = await this.shopService.deductMoney(userId, entryFee);
        if (!paymentSuccess) {
            console.log(`[chargeHostForGameCreation] Payment failed for host ${userId}`);
            return false;
        }

        if (!this.gamePrizePools[gameId]) {
            this.gamePrizePools[gameId] = {
                totalPool: 0,
                playerEntries: new Map<string, number>(),
            };
        }

        this.gamePrizePools[gameId].totalPool += entryFee;
        this.gamePrizePools[gameId].playerEntries.set(userId, entryFee);
        console.log(`[chargeHostForGameCreation] Host ${userId} paid ${entryFee}, total pool: ${this.gamePrizePools[gameId].totalPool}`);

        return true;
    }

    recalculateTurnOrder(game: Game): void {
        const currentPlayer = game.players.find((p) => p.turn === game.currentTurn);
        const activePlayers = game.players.filter((p) => p.isActive && !p.isObserver);
        const inactivePlayers = game.players.filter((p) => !p.isActive || p.isObserver);
        const orderedActivePlayers = [...activePlayers].sort((player1, player2) => {
            const speedDifference = player2.specs.speed - player1.specs.speed;
            return speedDifference === 0 ? Math.random() - HALF : speedDifference;
        });

        const orderedPlayers = [...orderedActivePlayers, ...inactivePlayers];

        orderedPlayers.forEach((player, index) => {
            player.turn = index;
        });

        game.players = orderedPlayers;

        if (currentPlayer) {
            const newIndex = game.players.findIndex((p) => p.socketId === currentPlayer.socketId);
            if (newIndex !== -1) {
                game.currentTurn = newIndex;
            } else {
                game.currentTurn = 0;
            }
        } else {
            game.currentTurn = 0;
        }
    }
}
