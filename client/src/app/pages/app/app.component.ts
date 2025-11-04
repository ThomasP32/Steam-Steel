import { CommonModule } from '@angular/common';
import { Component, HostBinding, OnInit } from '@angular/core';
import { NavigationEnd, Router, RouterOutlet } from '@angular/router';
import { FriendsListComponent } from '@app/components/friends-list/friends-list.component';
import { ThemeService } from '@app/services/theme/theme.service';
import { FriendsEvents } from '@common/events/friends.events';
import { GameCreationEvents } from '@common/events/game-creation.events';
import { GameInvitation, GameInvitationModalComponent } from '../../components/game-invitation-modal/game-invitation-modal.component';
import { AuthService } from '../../services/auth/auth.service';
import { SocketService } from '../../services/communication-socket/communication-socket.service';
import { FriendsService } from '../../services/friends/friends.service';

@Component({
    selector: 'app-root',
    standalone: true,
    templateUrl: './app.component.html',
    styleUrls: ['./app.component.scss'],
    imports: [CommonModule, RouterOutlet, GameInvitationModalComponent, FriendsListComponent],
})
export class AppComponent implements OnInit {
    @HostBinding('class') themeClass: string = 'theme-dark';

    currentInvitation: GameInvitation | null = null;
    isFriendsListVisible: boolean = false;
    isGamePage: boolean = false;
    isLoggedIn: boolean = false;
    constructor(
        private readonly themeService: ThemeService,
        private readonly friendsService: FriendsService,
        private readonly socketService: SocketService,
        private readonly router: Router,
        private readonly authService: AuthService,
    ) {
        this.themeService = themeService;
        this.friendsService = friendsService;
        this.socketService = socketService;
        this.router = router;
        this.authService = authService;
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

        this.socketService.listen<GameInvitation>(FriendsEvents.GameInvitationReceived).subscribe((invitation) => {
            this.currentInvitation = invitation;
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
