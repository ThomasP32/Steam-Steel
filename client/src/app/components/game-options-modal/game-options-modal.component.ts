import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';

@Component({
    selector: 'app-game-options-modal',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './game-options-modal.component.html',
    styleUrl: './game-options-modal.component.scss',
})
export class GameOptionsModalComponent {
    @Input() selectedMapName: string = '';
    @Output() closed = new EventEmitter<void>();
    @Output() next = new EventEmitter<{ isFastElimination: boolean; isFriendsOnly: boolean }>();

    isFastElimination: boolean = false;
    isFriendsOnly: boolean = false;

    onClose(): void {
        this.closed.emit();
    }

    onNext(): void {
        this.next.emit({
            isFastElimination: this.isFastElimination,
            isFriendsOnly: this.isFriendsOnly,
        });
    }

    toggleFastElimination(): void {
        this.isFastElimination = !this.isFastElimination;
    }

    toggleFriendsOnly(): void {
        this.isFriendsOnly = !this.isFriendsOnly;
    }
}
