import { CommonModule } from '@angular/common';
import { AfterViewInit, Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AccountComponent } from '@app/components/account/account.component';
import { AuthenticationComponent } from '@app/components/authentication/authentication.component';
import { ChatroomComponent } from '@app/components/chatroom/chatroom.component';
import { FriendsListComponent } from '@app/components/friends-list/friends-list.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { AuthService } from '@app/services/auth/auth.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { Subscription } from 'rxjs';
@Component({
    selector: 'app-main-page',
    standalone: true,
    templateUrl: './home-page.component.html',
    styleUrls: ['./home-page.component.scss'],
    imports: [JoinGameModalComponent, AuthenticationComponent, AccountComponent, CommonModule, ChatroomComponent, FriendsListComponent],
})
export class HomePageComponent implements OnInit, AfterViewInit, OnDestroy {
    teamNumber = 'Équipe 106';
    developers = ['Maude Racine', 'Noémie Hélias', 'Thomas Perron Duveau', 'Camille Ménard', 'Cerine Ouchene', 'Valentine Champvillard'];
    showJoinGameModal: boolean = false;
    isJoinGameModalVisible: boolean = false;
    isLoginModalVisible: boolean = false;
    isRegisterModalVisible: boolean = false;
    isLoggedIn: boolean = false;
    isAccountModalVisible: boolean = false;
    isChatVisible: boolean = false;
    isFriendsListVisible: boolean = false;

    private authSubscription: Subscription = new Subscription();

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
        this.authSubscription = this.authService.authState$.subscribe((isLoggedIn: boolean) => {
            this.isLoggedIn = isLoggedIn;
        });
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

    logout(): void {
        this.authService.logout();
        this.isChatVisible = false;
    }

    async connect() {
        if (!this.socketService.isSocketAlive()) {
            this.socketService.connect();
        }
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
