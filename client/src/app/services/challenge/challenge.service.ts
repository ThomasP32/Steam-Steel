import { Injectable } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { PublicChallengeView } from '@common/challenge';
import { ChallengeEvent } from '@common/events/challenge.events';
import { BehaviorSubject, Subscription } from 'rxjs';

@Injectable({
    providedIn: 'root',
})
export class ChallengeService {
    private readonly challengeSubject = new BehaviorSubject<PublicChallengeView | null>(null);
    public challenge$ = this.challengeSubject.asObservable();
    private socketSubscription: Subscription = new Subscription();

    constructor(
        private readonly socketService: SocketService,
    ) {
        this.socketService = socketService;
        this.listenToChallengeEvents();
    }

    listenToChallengeEvents(): void {
        
        // Unsubscribe from any previous listeners to avoid duplicates
        this.socketSubscription.unsubscribe();
        this.socketSubscription = new Subscription();
        
        this.socketSubscription.add(
            this.socketService.listen<PublicChallengeView>(ChallengeEvent.Updated).subscribe((challenge) => {
                // The server uses server.to(player.socketId).emit() to send challenges
                // Each socket connection should only receive challenges intended for that connection
                this.challengeSubject.next(challenge);
            })
        );
    }
    
    reinitializeListeners(): void {
        this.listenToChallengeEvents();
    }

    resetChallenge(): void {
        this.challengeSubject.next(null);
        this.socketSubscription.unsubscribe();
        this.socketSubscription = new Subscription();
    }
}

