import { Coordinate } from '@app/http/model/schemas/map/coordinate.schema';
import { UserService } from '@app/http/services/user/user.service';
import { ShopService } from '@app/services/shop/shop.service';
import { UserSocketService } from '@app/services/user-socket/user-socket.service';
import { ChallengeState, ChallengeType, PublicChallengeView } from '@common/challenge';
import { GameId, PlayerId } from '@common/combat';
import { ChallengeEvent } from '@common/events/challenge.events';
import { GameClassic, GameEndReason, Player } from '@common/game';
import { DoorTile, ItemCategory } from '@common/map.types';
import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';

@Injectable()
export class ChallengeService {
    // gameId -> playerId -> ChallengeState
    private states = new Map<GameId, Map<PlayerId, ChallengeState>>();
    server: Server;

    constructor(
        private readonly userService: UserService,
        private readonly userSocketService: UserSocketService,
        private readonly shopService: ShopService,
    ) {
        this.userService = userService;
        this.userSocketService = userSocketService;
        this.shopService = shopService;
    }

    setServer(server: Server): void {
        this.server = server;
    }

    // ------------ public API ------------
    assignForPlayer(game: GameClassic, player: Player): PublicChallengeView {
        const state = this.pickApplicableAndInit(game);
        this.setState(game.id, player.name, state);
        const view = this.publicView(game, player.name);

        // Emit initial challenge to player
        if (this.server) {
            this.server.to(player.socketId).emit(ChallengeEvent.Updated, view);
        } else {
            console.warn(`[ChallengeService] Server not initialized, cannot emit challenge!`);
        }

        return view;
    }

    // Deals with the challenges during the game
    onPlayerMove(game: GameClassic, player: Player, to: Coordinate[]) {
        const st = this.getState(game.id, player.name);
        if (!st) return;
        if (st.type === ChallengeType.VISIT_TILES_25) {
            to.forEach(() => {
                st.visitedTiles++;
            });
            this.challengeUpdate(game, player);
        }
    }

    onAttack(game: GameClassic, attacker: Player, damageDealt: number) {
        const a = this.getState(game.id, attacker.name);
        if (a && a.type === ChallengeType.DEAL_5_DAMAGE) {
            a.damageDealt = a.damageDealt + damageDealt;
            this.challengeUpdate(game, attacker);
        }
    }

    onAttackDodged(game: GameClassic, defender: Player) {
        const d = this.getState(game.id, defender.name);
        if (d && d.type === ChallengeType.ESCAPE_5_ATTACKS) {
            d.attacksDodged = (d.attacksDodged ?? 0) + 1;
            this.challengeUpdate(game, defender);
        }
    }

    onDoorOpened(game: GameClassic, player: Player, door: DoorTile) {
        const st = this.getState(game.id, player.name);
        if (!st) return;
        if (st.type === ChallengeType.OPEN_2_DOORS && door.isOpened) {
            st.doorsOpened! += 1;
            this.challengeUpdate(game, player);
        }
    }

    onItemCollected(game: GameClassic, player: Player, item: ItemCategory) {
        const st = this.getState(game.id, player.name);
        if (!st) return;
        if (st.type === ChallengeType.COLLECT_2_ITEMS) {
            // Only add the item if it's not already collected
            if (!st.collectedItems.includes(item)) {
                st.collectedItems.push(item);
                st.itemsCollected = st.collectedItems.length;
                this.challengeUpdate(game, player);
            }
        }
    }

    // Expose current public view
    publicView(game: GameClassic, playerId: PlayerId): PublicChallengeView {
        const st = this.getState(game.id, playerId)!;
        return {
            title: st.title,
            description: st.description,
            reward: st.reward,
            progress: st.progress,
            completed: st.completed,
        };
    }

    // Retrieve player's challenge for rejoining scenarios
    getPlayerChallenge(gameId: GameId, playerId: PlayerId): PublicChallengeView | null {
        const st = this.getState(gameId, playerId);
        if (!st) return null;

        return {
            title: st.title,
            description: st.description,
            reward: st.reward,
            progress: st.progress,
            completed: st.completed,
        };
    }


    async cleanupGame(game: GameClassic, endReason: GameEndReason): Promise<void> {
        const gameStates = this.states.get(game.id);
        if (!gameStates) return;

        // Iterate through all players in the state and handle completed challenges
        if (endReason !== GameEndReason.NoWinner_Termination) {
            for (const [playerId, state] of gameStates.entries()) {
                const player = game.players.find((p) => p.name === playerId);
                if (state.completed && player) {
                    const userId = this.userSocketService.getUserIdBySocket(player.socketId);
                    if (userId) {
                        await this.userService.incrementChallengesCompleted(userId);
                        await this.shopService.addMoney(userId, state.reward);
                    }
                }
            }
        }

        this.states.delete(game.id);
    }

    // ------------ internals ------------
    private setState(gameId: GameId, playerId: PlayerId, st: ChallengeState) {
        if (!this.states.has(gameId)) this.states.set(gameId, new Map());
        this.states.get(gameId)!.set(playerId, st);
    }
    private getState(gameId: GameId, playerId: PlayerId) {
        return this.states.get(gameId)?.get(playerId);
    }
    private challengeUpdate(game: GameClassic, player: Player) {
        const st = this.getState(game.id, player.name);

        this.recompute(game, st);
        this.pushUpdate(game, player);
    }
    private pushUpdate(game: GameClassic, player: Player) {
        const view = this.publicView(game, player.name);
        this.server.to(player.socketId).emit(ChallengeEvent.Updated, view);
    }

    private pickApplicableAndInit(game: GameClassic): ChallengeState {
        const candidates = [
            ChallengeType.VISIT_TILES_25,
            ChallengeType.DEAL_5_DAMAGE,
            ChallengeType.ESCAPE_5_ATTACKS,
            ChallengeType.OPEN_2_DOORS,
            ChallengeType.COLLECT_2_ITEMS,
        ].filter((t) => this.isApplicable(game, t));

        const type = (candidates.length ? candidates : [ChallengeType.VISIT_TILES_25])[Math.floor(Math.random() * (candidates.length || 1))];

        return this.initState(type);
    }

    private isApplicable(game: GameClassic, t: ChallengeType): boolean {
        switch (t) {
            case ChallengeType.VISIT_TILES_25:
                return (game.mapSize?.x ?? 0) * (game.mapSize?.y ?? 0) >= 4;
            case ChallengeType.DEAL_5_DAMAGE:
                return (game.players?.length ?? 0) >= 2;
            case ChallengeType.ESCAPE_5_ATTACKS:
                return true;
            case ChallengeType.OPEN_2_DOORS:
                return (game.doorTiles?.filter((d) => !d.isOpened).length ?? 0) >= 2;
            case ChallengeType.COLLECT_2_ITEMS:
                return (game.items?.length ?? 0) >= 2;
        }
    }

    private initState(type: ChallengeType): ChallengeState {
        switch (type) {
            case ChallengeType.VISIT_TILES_25: {
                return {
                    type,
                    title: 'Explorateur',
                    description: 'Parcourir au moins 25% des cases de la carte.',
                    reward: 250,
                    visitedTiles: 0,
                    progress: 0,
                    completed: false,
                };
            }
            case ChallengeType.DEAL_5_DAMAGE: {
                return {
                    type,
                    title: 'Bagarreur',
                    description: 'Infliger au moins 5 points de dommages.',
                    reward: 100,
                    damageDealt: 0,
                    progress: 0,
                    completed: false,
                };
            }
            case ChallengeType.ESCAPE_5_ATTACKS: {
                return {
                    type,
                    title: 'Protecteur',
                    description: 'Survivez à 5 attaques ennemies.',
                    reward: 150,
                    attacksDodged: 0,
                    progress: 0,
                    completed: false,
                };
            }
            case ChallengeType.OPEN_2_DOORS: {
                return {
                    type,
                    title: 'Serrurier',
                    description: 'Ouvrir au moins deux portes.',
                    reward: 50,
                    doorsOpened: 0,
                    progress: 0,
                    completed: false,
                };
            }
            case ChallengeType.COLLECT_2_ITEMS: {
                return {
                    type,
                    title: 'Collectionneur',
                    description: 'Collecter au moins deux objets différents.',
                    reward: 50,
                    itemsCollected: 0,
                    collectedItems: [],
                    progress: 0,
                    completed: false,
                };
            }
        }
    }

    private recompute(game: GameClassic, st: ChallengeState) {
        switch (st.type) {
            case ChallengeType.VISIT_TILES_25: {
                const total = (game.mapSize?.x || 1) * (game.mapSize?.y || 1);
                const target = Math.ceil(total * 0.25);
                st.progress = Math.min(st.visitedTiles / target, 1);
                st.completed = st.visitedTiles >= target;
                return;
            }
            case ChallengeType.DEAL_5_DAMAGE: {
                const d = st.damageDealt ?? 0;
                st.progress = Math.min(d / 5, 1);
                st.completed = d >= 5;
                return;
            }
            case ChallengeType.ESCAPE_5_ATTACKS: {
                const dodged = st.attacksDodged ?? 0;
                st.progress = Math.min(dodged / 5, 1);
                st.completed = dodged >= 5;
                return;
            }
            case ChallengeType.OPEN_2_DOORS: {
                const n = st.doorsOpened ?? 0;
                st.progress = Math.min(n / 2, 1);
                st.completed = n >= 2;
                return;
            }
            case ChallengeType.COLLECT_2_ITEMS: {
                const n = st.itemsCollected ?? 0;
                st.progress = Math.min(n / 2, 1);
                st.completed = n >= 2;
                return;
            }
        }
    }
}
