import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';

export interface GameInvitation {
    gameId: string;
    gameName: string;
    inviterUsername: string;
    inviterName: string;
}

@Component({
    selector: 'app-game-invitation-modal',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './game-invitation-modal.component.html',
    styleUrl: './game-invitation-modal.component.scss',
})
export class GameInvitationModalComponent {
    @Input() invitation: GameInvitation | null = null;
    @Output() accepted = new EventEmitter<GameInvitation>();
    @Output() rejected = new EventEmitter<GameInvitation>();
    @Output() closed = new EventEmitter<void>();

    onAccept(): void {
        if (this.invitation) {
            this.accepted.emit(this.invitation);
        }
    }

    onReject(): void {
        if (this.invitation) {
            this.rejected.emit(this.invitation);
        }
    }

    onClose(): void {
        this.closed.emit();
    }
}
