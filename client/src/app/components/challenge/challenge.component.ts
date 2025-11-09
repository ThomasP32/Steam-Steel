import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { PublicChallengeView } from '@common/challenge';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-challenge',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './challenge.component.html',
    styleUrl: './challenge.component.scss',
})
export class ChallengeComponent implements OnInit, OnDestroy {

    challenge: PublicChallengeView | null = null;
    showTooltip: boolean = false;
    showInfoTooltip: boolean = false;
    private subscription: Subscription = new Subscription();

    constructor(private readonly challengeService: ChallengeService) {
        this.challengeService = challengeService;
    }

    ngOnInit(): void {
        
        this.subscription.add(
            this.challengeService.challenge$.subscribe((challenge) => {
                this.challenge = challenge;
            }),
        );
    }

    ngOnDestroy(): void {
        this.subscription.unsubscribe();
    }

    getProgressPercentage(): number {
        return this.challenge ? Math.round(this.challenge.progress * 100) : 0;
    }

    onInfoMouseEnter(): void {
        this.showInfoTooltip = true;
    }

    onInfoMouseLeave(): void {
        this.showInfoTooltip = false;
    }
}

