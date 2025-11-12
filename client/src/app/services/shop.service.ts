import { Injectable } from '@angular/core';
import { ShopEvents } from '@common/events/shop.events';
import { BehaviorSubject } from 'rxjs';
import { SocketService } from './communication-socket/communication-socket.service';

@Injectable({
    providedIn: 'root',
})
export class ShopService {
    private userMoneySubject = new BehaviorSubject<number>(1000);
    public userMoney$ = this.userMoneySubject.asObservable();

    constructor(private socketService: SocketService) {
        this.socketService = socketService;
        this.setupSocketListeners();
    }

    getCurrentMoney(): number {
        return this.userMoneySubject.value;
    }

    private setupSocketListeners(): void {
        this.socketService.listen<number>(ShopEvents.UserMoneyUpdated).subscribe((money) => {
            console.log('UserMoneyUpdated received:', money);
            this.userMoneySubject.next(money);
        });
    }
}
