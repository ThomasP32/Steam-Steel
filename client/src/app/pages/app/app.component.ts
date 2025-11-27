import { CommonModule } from '@angular/common';
import { Component, HostBinding, OnInit } from '@angular/core';
import { NavigationEnd, Router, RouterOutlet } from '@angular/router';
import { FriendsListComponent } from '@app/components/friends-list/friends-list.component';
import { GameInfoComponent } from '@app/components/game-info/game-info.component';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { GameInvitation, GameInvitationModalComponent } from '../../components/game-invitation-modal/game-invitation-modal.component';
import { AuthService } from '../../services/auth/auth.service';
import { SocketService } from '../../services/communication-socket/communication-socket.service';
import { FriendsService } from '../../services/friends/friends.service';
import { GameTurnService } from '../../services/game-turn/game-turn.service';
import { GameService } from '../../services/game/game.service';
import { ThemeService } from '../../services/theme/theme.service';

@Component({
    selector: 'app-root',
    standalone: true,
    templateUrl: './app.component.html',
    styleUrls: ['./app.component.scss'],
    imports: [CommonModule, RouterOutlet, GameInvitationModalComponent, FriendsListComponent, GameInfoComponent],
})
export class AppComponent implements OnInit {
    @HostBinding('class') get hostClasses(): string {
        return `${this.themeClass} ${this.isGamePage ? 'game-page' : ''}`;
    }

    themeClass: string = 'theme-dark';
    currentInvitation: GameInvitation | null = null;
    userMoney: number = 0;
    isFriendsListVisible: boolean = false;
    isGameInfoVisible: boolean = false;
    isGamePage: boolean = false;
    isLoggedIn: boolean = false;
    constructor(
        private readonly themeService: ThemeService,
        private readonly friendsService: FriendsService,
        private readonly socketService: SocketService,
        private readonly router: Router,
        private readonly authService: AuthService,
        protected readonly gameService: GameService,
        protected readonly gameTurnService: GameTurnService,
    ) {
        this.themeService = themeService;
        this.friendsService = friendsService;
        this.socketService = socketService;
        this.router = router;
        this.authService = authService;
        this.gameService = gameService;
        this.gameTurnService = gameTurnService;
    }

    ngOnInit(): void {
        this.authService.authState$.subscribe((isAuthenticated) => {
            this.isLoggedIn = isAuthenticated;
            if (isAuthenticated) {
                this.checkAndSetupFriendsFeatures();
            }
        });

        this.isLoggedIn = this.authService.isLoggedIn();

        this.router.events.subscribe((event) => {
            if (event instanceof NavigationEnd) {
                this.isGamePage = event.url.includes('/game');
            }
        });

        this.isGamePage = this.router.url.includes('/game');

        this.checkAndSetupFriendsFeatures();
    }

    setTheme(theme: string) {
        this.themeClass = theme;
    }

    async toggleTheme() {
        const next = this.themeClass === 'theme-dark' ? 'theme-light' : 'theme-dark';
        try {
            await this.themeService.applyThemeJson(next);
            this.themeClass = next;
        } catch (e) {
            console.error('Theme update failed', e);
        }
    }

    private setupGameInvitationListener(): void {
        if (!this.socketService.isSocketAlive()) {
            console.warn('Socket not connected, cannot setup game invitation listener');
            return;
        }

        this.socketService.listen<GameInvitation>(FriendsEvents.GameInvitationReceived).subscribe(async (invitation) => {
            this.currentInvitation = invitation;
            const userInfo = await this.authService.getUserInfo();
            this.userMoney = userInfo.user.virtualMoney ?? 0;
        });
    }

    onInvitationAccepted(invitation: GameInvitation): void {
        this.friendsService.acceptGameInvitation(invitation.gameId, invitation.inviterUsername);
        this.currentInvitation = null;

        const tempSubscription = this.socketService.listen<string>(GameCreationEvents.GameAccessed).subscribe((gameId) => {
            this.router.navigate([`join-game/${gameId}/create-character`]);
            tempSubscription.unsubscribe();
        });

        this.socketService.sendMessage(GameCreationEvents.AccessGame, invitation.gameId);
    }

    onInvitationRejected(invitation: GameInvitation): void {
        this.friendsService.rejectGameInvitation(invitation.gameId, invitation.inviterUsername);
        this.currentInvitation = null;
    }

    onInvitationClosed(): void {
        this.currentInvitation = null;
    }

    toggleFriendsListVisibility(): void {
        this.isFriendsListVisible = !this.isFriendsListVisible;
    }

    toggleGameInfoVisibility(): void {
        this.isGameInfoVisible = !this.isGameInfoVisible;
    }

    private async checkAndSetupFriendsFeatures(): Promise<void> {
        const userInfo = await this.authService.getUserInfo();
        if (userInfo && userInfo.user) {
            if (this.socketService.isSocketAlive()) {
                this.setupGameInvitationListener();
                this.friendsService.initializeFriendsSocket();
            } else {
                setTimeout(() => {
                    if (this.socketService.isSocketAlive()) {
                        this.setupGameInvitationListener();
                        this.friendsService.initializeFriendsSocket();
                    }
                }, 1000);
            }
        }
    }
}
