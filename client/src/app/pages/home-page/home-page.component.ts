import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthentificationComponent } from '@app/components/authentification/authentification.component';
import { JoinGameModalComponent } from '@app/components/join-game-modal/join-game-modal.component';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
@Component({
    selector: 'app-main-page',
    standalone: true,
    templateUrl: './home-page.component.html',
    styleUrls: ['./home-page.component.scss'],
    imports: [JoinGameModalComponent, AuthentificationComponent, CommonModule],
})
export class HomePageComponent implements OnInit {
    teamNumber = 'Équipe 106';
    developers = ['Maude Racine', 'Noémie Hélias', 'Thomas Perron Duveau', 'Camille Ménard', 'Cerine Ouchene', 'Valentine Champvillard'];
    showJoinGameModal = false;
    isJoinGameModalVisible = false;
    isAuthModalVisible = false;
    toggleAuthModal(): void {
        this.isAuthModalVisible = true;
    }

    onCloseAuthModal(): void {
        this.isAuthModalVisible = false;
    }

    constructor(
        private readonly router: Router,
        private readonly socketService: SocketService,
    ) {
        this.router = router;
        this.socketService = socketService;
    }
    ngOnInit(): void {
        this.connect();
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
