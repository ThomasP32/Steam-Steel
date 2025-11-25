import {
    AMULET_LIFE_BONUS,
    ARMOR_DEFENSE_BONUS,
    ARMOR_SPEED_PENALTY,
    FLASK_ATTACK_BONUS,
    SWORD_ATTACK_BONUS,
    SWORD_SPEED_BONUS,
} from '@common/constants';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { GameCtf, Player } from '@common/game';
import { Coordinate, ItemCategory, Mode } from '@common/map.types';
import { Inject, Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { ChallengeService } from '../challenge/challenge.service';
import { GameCreationService } from '../game-creation/game-creation.service';
import { GameManagerService } from '../game-manager/game-manager.service';
import { JournalService } from '../journal/journal.service';

@Injectable()
export class ItemsManagerService {
    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(GameManagerService) private readonly gameManagerService: GameManagerService;
    @Inject(JournalService) private readonly journalService: JournalService;
    @Inject(ChallengeService) private readonly challengeService: ChallengeService;
    private server: Server;

    setServer(server: Server): void {
        this.server = server;
    }

    dropInventory(player: Player, gameId: string): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) return;

        const inventoryCopy = [...player.inventory];

        for (const item of inventoryCopy) {
            const dropPosition = this.gameManagerService.getFirstFreePosition(player.position, game);
            
            if (dropPosition) {
                this.dropItem(item, gameId, player, dropPosition);
            } else {
                // If no free position found, log warning but continue
                console.warn(`[ItemsManagerService] dropInventory: No free position found for item ${item}, skipping drop`);
            }
        }
    }

    pickUpItem(pos: Coordinate, gameId: string, player: Player): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[ItemsManagerService] pickUpItem: Game ${gameId} not found (likely already ended)`);
            return;
        }
        const itemIndex = game.items.findIndex((item) => item.coordinate.x === pos.x && item.coordinate.y === pos.y);
        if (itemIndex !== -1) {
            const item = game.items[itemIndex].category;

            // Ensure inventory is initialized
            if (!player.inventory) {
                console.warn(`[ItemsManagerService] Player ${player.name} had undefined inventory, initializing`);
                player.inventory = [];
            }

            player.inventory.push(item);
            player.specs.nItemsUsed++;
            if (item === ItemCategory.Flag) {
                if (game && game.mode === Mode.Ctf) {
                    const ctfGame = game as GameCtf;
                    // Ensure nPlayersCtf is initialized
                    if (!ctfGame.nPlayersCtf) {
                        console.warn(`[ItemsManagerService] Game ${gameId} had undefined nPlayersCtf, initializing`);
                        ctfGame.nPlayersCtf = [];
                    }
                    ctfGame.nPlayersCtf.push(player);
                }
            }
            game.items.splice(itemIndex, 1);

            if (item === ItemCategory.Flag && game.mode === Mode.Ctf && this.server) {
                this.handleCtfPlayerStartTile(game, player.socketId, true);
            }

            // Track challenge progress
            this.challengeService.onItemCollected(game, player, item);

            const involvedPlayers = game.players.map((player) => player.name);

            this.journalService.logMessage(gameId, `${player.name}. a ramassé un item !`, involvedPlayers);

            if (item === ItemCategory.Sword || item === ItemCategory.Armor) this.activateItem(item, player);
        }
    }

    dropItem(itemDropping: ItemCategory, gameId: string, player: Player, coordinates: Coordinate): void {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[ItemsManagerService] dropItem: Game ${gameId} not found (likely already ended)`);
            return;
        }
        const itemIndex = player.inventory.findIndex((item) => item === itemDropping);
        if (itemIndex !== -1) {
            const item = player.inventory[itemIndex];
            player.inventory.splice(itemIndex, 1);
            game.items.push({ coordinate: coordinates, category: item });

            if (item === ItemCategory.Flag && game.mode === Mode.Ctf && this.server) {
                this.handleCtfPlayerStartTile(game, player.socketId, false);
            }

            if (item === ItemCategory.Sword || item === ItemCategory.Armor) this.desactivateItem(item, player);
        }
    }

    activateItem(item: ItemCategory, player: Player): void {
        switch (item) {
            case ItemCategory.Sword:
                player.specs.speed += SWORD_SPEED_BONUS;
                player.specs.attack += SWORD_ATTACK_BONUS;
                break;
            case ItemCategory.Armor:
                player.specs.defense += ARMOR_DEFENSE_BONUS;
                player.specs.speed -= ARMOR_SPEED_PENALTY;
                break;
            case ItemCategory.Flask:
                player.specs.attack += FLASK_ATTACK_BONUS;
                break;
            case ItemCategory.Amulet:
                player.specs.life += AMULET_LIFE_BONUS;
        }
    }

    desactivateItem(item: ItemCategory, player: Player): void {
        switch (item) {
            case ItemCategory.Sword:
                player.specs.speed -= SWORD_SPEED_BONUS;
                player.specs.attack -= SWORD_ATTACK_BONUS;
                break;
            case ItemCategory.Armor:
                player.specs.defense -= ARMOR_DEFENSE_BONUS;
                player.specs.speed += ARMOR_SPEED_PENALTY;
                break;
            case ItemCategory.Flask:
                player.specs.attack -= FLASK_ATTACK_BONUS;
                break;
            case ItemCategory.Amulet:
                player.specs.life -= AMULET_LIFE_BONUS;
        }
    }

    onItem(player: Player, gameId: string): boolean {
        const game = this.gameCreationService.getGameById(gameId);
        if (!game) {
            console.warn(`[ItemsManagerService] onItem: Game ${gameId} not found (likely already ended)`);
            return false;
        }
        return game.items.some((item) => item.coordinate.x === player.position.x && item.coordinate.y === player.position.y);
    }

    checkForAmulet(challenger: Player, opponent: Player): void {
        if (challenger.inventory.includes(ItemCategory.Amulet) && opponent.specs.life > challenger.specs.life) {
            this.activateItem(ItemCategory.Amulet, challenger);
        }
        if (opponent.inventory.includes(ItemCategory.Amulet) && challenger.specs.life > opponent.specs.life) {
            this.activateItem(ItemCategory.Amulet, opponent);
        }
    }

    private handleCtfPlayerStartTile(game: any, playerSocketId: string, hasFlag: boolean): void {
        if (game.mode === Mode.Ctf) {
            const ctfGame = game as GameCtf;
            if (ctfGame.playerStartTiles) {
                const playerStartTile = ctfGame.playerStartTiles.find((entry) => entry.socketId === playerSocketId);
                if (playerStartTile) {
                    if (hasFlag) {
                        this.server.to(playerSocketId).emit(GameManagerEvents.PlayerStartTile, playerStartTile.coordinate);
                    } else {
                        this.server.to(playerSocketId).emit(GameManagerEvents.PlayerStartTile, null);
                    }
                }
            }
        }
    }
}
