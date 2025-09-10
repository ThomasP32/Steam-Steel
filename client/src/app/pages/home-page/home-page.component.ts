import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AccountComponent } from '@app/components/account/account.component';
import { AuthentificationComponent } from '@app/components/authentification/authentification.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
@Component({
    selector: 'app-main-page',
    standalone: true,
    templateUrl: './home-page.component.html',
    styleUrls: ['./home-page.component.scss'],
    imports: [JoinGameModalComponent, AuthentificationComponent, AccountComponent, CommonModule],
})
export class HomePageComponent implements OnInit {
    teamNumber = 'Équipe 106';
    developers = ['Maude Racine', 'Noémie Hélias', 'Thomas Perron Duveau', 'Camille Ménard', 'Cerine Ouchene', 'Valentine Champvillard'];
    showJoinGameModal = false;
    isJoinGameModalVisible = false;
    isAuthModalVisible = false;
    isLoggedIn = false;
    isAccountModalVisible = false;

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
    ) {
        this.router = router;
        this.socketService = socketService;
    }
    ngOnInit(): void {
        this.checkLoginStatus();
        this.connect();
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
