import { CommonModule } from '@angular/common';
import { AfterViewInit, Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AccountComponent } from '@app/components/account/account.component';
import { AuthenticationComponent } from '@app/components/authentication/authentication.component';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { ShopComponent } from '@app/components/shop/shop.component';
import { AudioService } from '@app/services/audio/audio.service';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { Subscription } from 'rxjs';
@Component({
    selector: 'app-main-page',
    standalone: true,
    templateUrl: './home-page.component.html',
    styleUrls: ['./home-page.component.scss'],
    imports: [AuthenticationComponent, AccountComponent, CommonModule, ChatroomComponent, ShopComponent],
})
export class HomePageComponent implements OnInit, AfterViewInit, OnDestroy {
    teamNumber = 'Équipe 106';
    developers = ['Maude Racine', 'Noémie Hélias', 'Thomas Perron Duveau', 'Camille Ménard', 'Cerine Ouchene', 'Valentine Champvillard'];
    isLoginModalVisible: boolean = false;
    isRegisterModalVisible: boolean = false;
    isLoggedIn: boolean = false;
    isAccountModalVisible: boolean = false;
    isChatVisible: boolean = false;
    isFriendsListVisible: boolean = false;
    showShop: boolean = false;
    showDeleteConfirmation: boolean = false;

    private authSubscription: Subscription = new Subscription();

    constructor(
        private readonly router: Router,
        private readonly socketService: SocketService,
        private readonly authService: AuthService,
        public readonly audioService: AudioService,
    ) {
        this.router = router;
        this.socketService = socketService;
        this.authService = authService;
        this.audioService = audioService;
    }

    ngOnInit(): void {
        this.authSubscription = this.authService.authState$.subscribe((isLoggedIn: boolean) => {
            this.isLoggedIn = isLoggedIn;
        });
        this.audioService.playBackgroundMusic('music2.mp3');
    }

    ngAfterViewInit(): void {
        this.connect();
    }

    ngOnDestroy(): void {
        this.authSubscription.unsubscribe();
    }

    toggleLoginModal(): void {
        this.isLoginModalVisible = true;
    }

    toggleRegisterModal(): void {
        this.isRegisterModalVisible = true;
    }

    onCloseLoginModal(): void {
        this.isLoginModalVisible = false;
    }

    onCloseRegisterModal(): void {
        this.isRegisterModalVisible = false;
    }

    toggleAccountModal(): void {
        this.isAccountModalVisible = true;
    }
    onCloseAccountModal(): void {
        this.isAccountModalVisible = false;
    }

    confirmDeleteAccount(): void {
        this.authService.deleteAccount().then(() => {
            this.authService.logout();
            this.showDeleteConfirmation = false;
            this.isAccountModalVisible = false;
        });
    }

    logout(): void {
        if (!this.isLoggedIn) {
            this.isChatVisible = false;
        }
    }

    async connect() {
        if (!this.socketService.isSocketAlive()) {
            this.socketService.connect();
        }
    }

    navigateToJoin(): void {
        this.router.navigate(['/join-game']);
    }

    navigateToCreateGame(): void {
        this.router.navigate(['/create-game']);
    }

    navigateToAdmin(): void {
        this.router.navigate(['/admin-page']);
    }
}
