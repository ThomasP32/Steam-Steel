import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AccountComponent } from '@app/components/account/account.component';
import { AuthenticationComponent } from '@app/components/authentication/authentication.component';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { ChatEvents } from '@common/events/chat.events';
@Component({
    selector: 'app-main-page',
    standalone: true,
    templateUrl: './home-page.component.html',
    styleUrls: ['./home-page.component.scss'],
    imports: [JoinGameModalComponent, AuthenticationComponent, AccountComponent, CommonModule, ChatroomComponent],
})
export class HomePageComponent implements OnInit {
    teamNumber = 'Équipe 106';
    developers = ['Maude Racine', 'Noémie Hélias', 'Thomas Perron Duveau', 'Camille Ménard', 'Cerine Ouchene', 'Valentine Champvillard'];
    showJoinGameModal: boolean = false;
    isJoinGameModalVisible: boolean = false;
    isAuthModalVisible: boolean = false;
    isLoggedIn: boolean = false;
    isAccountModalVisible: boolean = false;
    isChatVisible: boolean = false;
    userName: string = 'Guest';

    toggleAuthModal(): void {
        this.isAuthModalVisible = true;
    }

    onCloseAuthModal(): void {
        this.isAuthModalVisible = false;
        this.checkLoginStatus();
    }

    toggleAccountModal(): void {
        this.isAccountModalVisible = true;
    }
    onCloseAccountModal(): void {
        this.isAccountModalVisible = false;
        this.checkLoginStatus();
    }

    constructor(
        private readonly router: Router,
        private readonly socketService: SocketService,
        private readonly authService: AuthService,
    ) {
        this.router = router;
        this.socketService = socketService;
        this.authService = authService;
    }
    ngOnInit(): void {
        this.checkLoginStatus();
        this.connect();
        this.setupUserAndGlobalChat();
    }

    private async setupUserAndGlobalChat(): Promise<void> {
        if (this.isLoggedIn) {
            try {
                const info = await this.authService.getUserInfo();
                this.userName = info?.user?.username || 'User';
            } catch {
                this.userName = 'User';
            }
        } else {
            this.userName = 'Guest';
        }

        try {
            this.socketService.sendMessage(ChatEvents.JoinChatRoom, 'global');
        } catch (e) {
            // ignore
        }
    }

    async connect() {
        if (!this.socketService.isSocketAlive()) {
            this.socketService.connect();
        }
    }

    checkLoginStatus() {
        const token = localStorage.getItem('authToken');
        this.isLoggedIn = typeof token === 'string' && token.length > 0;
    }

    toggleJoinGameVisibility(): void {
        this.isJoinGameModalVisible = true;
    }

    onCloseModal(): void {
        this.isJoinGameModalVisible = false;
    }

    navigateToCreateGame(): void {
        this.router.navigate(['/create-game']);
    }

    navigateToAdmin(): void {
        this.router.navigate(['/admin-page']);
    }
}
