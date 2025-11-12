import { CommonModule } from '@angular/common';
import { Component, Input, OnDestroy, OnInit } from '@angular/core';
import { ShopEvents } from '@common/events/shop.events';
import { Subscription } from 'rxjs';
import { AuthService } from '../../services/auth/auth.service';
import { SocketService } from '../../services/communication-socket/communication-socket.service';

@Component({
    selector: 'app-virtual-money',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './virtual-money.component.html',
    styleUrl: './virtual-money.component.scss',
})
export class VirtualMoneyComponent implements OnInit, OnDestroy {
    @Input() compact = false;

    currentMoney = 0;
    private subscription: Subscription = new Subscription();

    constructor(
        private socketService: SocketService,
        private authService: AuthService,
    ) {
        this.socketService = socketService;
        this.authService = authService;
    }

    async ngOnInit(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            this.currentMoney = userInfo.user.virtualMoney || 0;
        } catch (error) {
            console.error("Erreur lors de la récupération de l'utilisateur:", error);
        }

        this.subscription.add(
            this.socketService.listen<number>(ShopEvents.UserMoneyUpdated).subscribe((money) => {
                this.currentMoney = money;
            }),
        );
    }

    ngOnDestroy(): void {
        this.subscription.unsubscribe();
    }
}
