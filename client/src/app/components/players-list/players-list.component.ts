import { CommonModule } from '@angular/common';
import { Component, Input, OnChanges, OnInit, SimpleChanges } from '@angular/core';
import { CharacterService } from '@app/services/character/character.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { GameCreationEvents, KickPlayerData } from '@common/events/game-creation.events';
import { Avatar, Player } from '@common/game';

@Component({
    selector: 'app-players-list',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './players-list.component.html',
    styleUrl: './players-list.component.scss',
})
export class PlayersListComponent implements OnInit, OnChanges {
    @Input() players: Player[];
    @Input() isHost: boolean;
    @Input() isGameMaxed: boolean;
    @Input() isGameLocked: boolean;
    @Input() gameId: string;
    @Input() openProfileModal: () => void;

    hostPlayerId: string = '';
    hoveredPlayerId: string | null = null;
    playerBanners: Map<string, string> = new Map();

    constructor(
        private readonly characterService: CharacterService,
        private readonly socketService: SocketService,
        private readonly shopHttpService: ShopHttpService,
    ) {
        this.characterService = characterService;
        this.socketService = socketService;
        this.shopHttpService = shopHttpService;
    }

    ngOnInit(): void {
        if (this.isHost && this.players && this.players.length > 0) {
            this.hostPlayerId = this.players[0].socketId;
        }
        if (this.players && this.players.length > 0) {
            this.loadPlayerBanners();
        }
    }

    ngOnChanges(changes: SimpleChanges): void {
        if (changes['players'] && changes['players'].currentValue) {
            this.loadPlayerBanners();
        }
    }

    async loadPlayerBanners(): Promise<void> {
        if (!this.players || this.players.length === 0) {
            return;
        }

        for (const player of this.players) {
            try {
                const userItems = await this.shopHttpService.getUserItemsByUsername(player.name).toPromise();
                if (userItems) {
                    const equippedBanner = userItems.find(
                        (item: { itemId: string; equipped: boolean; purchaseDate: Date }) => item.equipped && item.itemId.startsWith('banner_'),
                    );
                    if (equippedBanner) {
                        const catalog = await this.shopHttpService.getCatalog().toPromise();
                        const bannerItem = catalog?.find((item) => item.id === equippedBanner.itemId);
                        if (bannerItem && bannerItem.imagePath) {
                            this.playerBanners.set(player.name, bannerItem.imagePath);
                        }
                    }
                }
            } catch (error) {
                console.error(`Erreur lors du chargement de la bannière pour ${player.name}:`, error);
            }
        }
    }

    getPlayerBanner(playerName: string): string | null {
        return this.playerBanners.get(playerName) || null;
    }

    getAvatarPreview(avatar: Avatar): string {
        return this.characterService.getAvatarPreview(avatar);
    }

    checkHostPlayerId(): void {
        if (!this.isHost || !this.hoveredPlayerId) return;
        if (this.hostPlayerId === '') {
            this.hostPlayerId = this.players[0]?.socketId || '';
        }
    }

    kickPlayer(playerId: string): void {
        const kickPlayer: KickPlayerData = { playerId: playerId, gameId: this.gameId };
        this.socketService.sendMessage(GameCreationEvents.KickPlayer, kickPlayer);
    }

    isVirtualPlayerSocketId(socketId: string): boolean {
        return !!socketId && socketId.includes('virtualPlayer');
    }
}
