import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { ChannelService } from '@app/services/channel/channel.service';
import { CharacterService } from '@app/services/character/character.service';
import { CombatService } from '@app/services/combat/combat.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { EndgameService } from '@app/services/endgame/endgame.service';
import { GameTurnService } from '@app/services/game-turn/game-turn.service';
import { GameService } from '@app/services/game/game.service';
import { PlayerService } from '@app/services/player-service/player.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { FriendsEvents } from '@common/events/friends.events';
import { Avatar, Game, GameCtf, Player } from '@common/game';
import { Mode } from '@common/map.types';
import { UserStatus } from '@common/user-friends';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-endgame-page',
    standalone: true,
    imports: [CommonModule, ChatroomComponent],
    templateUrl: './endgame-page.component.html',
    styleUrl: './endgame-page.component.scss',
})
export class EndgamePageComponent implements OnInit, OnDestroy {
    socketSubscription: Subscription = new Subscription();
    isChatVisible: boolean = false;
    private readonly playerBanners: Map<string, string> = new Map();
    showLevelModal: boolean = false;
    newLevel: number = 0;
    bannerUnlocked: boolean = false;
    moneyReward: number = 0;
    challengeReward: number = 0;

    constructor(
        private readonly socketService: SocketService,
        private readonly gameService: GameService,
        private readonly playerService: PlayerService,
        private readonly characterService: CharacterService,
        private readonly router: Router,
        protected endgameService: EndgameService,
        private readonly channelService: ChannelService,
        private readonly gameTurnService: GameTurnService,
        private readonly challengeService: ChallengeService,
        private readonly shopHttpService: ShopHttpService,
        private readonly combatService: CombatService,
    ) {
        this.socketService = socketService;
        this.gameService = gameService;
        this.playerService = playerService;
        this.characterService = characterService;
        this.router = router;
        this.endgameService = endgameService;
        this.channelService = channelService;
        this.gameTurnService = gameTurnService;
        this.challengeService = challengeService;
        this.combatService = combatService;

        this.gameTurnService.moneyReward$.subscribe((reward) => {
            this.moneyReward = reward;
        });

        this.challengeService.challenge$.subscribe((challenge) => {
            if (challenge?.completed) {
                this.challengeReward = challenge.reward || 0;
            }
        });
        this.shopHttpService = shopHttpService;
    }

    async ngOnInit(): Promise<void> {
        console.log('[EndgamePage] ngOnInit, game:', this.gameService.game);
        
        // If no game data, redirect to main menu
        if (!this.gameService.game) {
            console.warn('[EndgamePage] No game data available, redirecting to main menu');
            this.router.navigate(['/main-menu']);
            return;
        }
        
        await this.loadPlayerBanners();
        this.listenToPlayerLeveledUp();
    }

    get player(): Player {
        return this.playerService.player;
    }

    get game(): Game {
        return this.gameService.game;
    }

    get players(): Player[] {
        return this.gameService.game?.players.filter(player => player.wasActivePlayer) || [];
    }

    isGameCtf(game: Game): game is GameCtf {
        return game.mode === Mode.Ctf;
    }

    isVirtualPlayer(socketId: string): boolean {
        return socketId.startsWith('virtualPlayer');
    }

    getAvatarPreview(avatar: Avatar): string {
        return this.characterService.getAvatarPreview(avatar);
    }

    listenToPlayerLeveledUp(): void {
        this.socketSubscription.add(
            this.endgameService.levelUp$.subscribe((data) => {
                if (data) {
                    this.showLevelModal = true;
                    this.newLevel = data.newLevel;
                    this.bannerUnlocked = data.bannerUnlocked;
                }
            }),
        );
    }

    navigateToMain(): void {
        this.playerService.resetPlayer();
        this.channelService.removePartyChannel(this.game.id);
        this.combatService.resetCombatState();
        this.socketService.sendMessage(FriendsEvents.UpdateUserStatus, { status: UserStatus.Online });

        setTimeout(() => {
            this.characterService.resetCharacterAvailability();
            // Socket stays connected - only leaving the game room
            this.router.navigate(['/main-menu']);
        }, 100);
    }

    ngOnDestroy() {
        if (this.socketSubscription) {
            this.socketSubscription.unsubscribe();
        }
        // Socket stays connected - only unsubscribing from events
    }

    private async loadPlayerBanners(): Promise<void> {
        if (!this.players || this.players.length === 0) {
            return;
        }

        for (const player of this.players) {
            try {
                const userItems = await this.shopHttpService.getUserItemsByUsername(player.name).toPromise();

                if (userItems && userItems.length > 0) {
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
                console.error(`❌ Error loading banner for ${player.name}:`, error);
            }
        }
    }

    getPlayerBanner(playerName: string): string | null {
        return this.playerBanners.get(playerName) || null;
    }
}
