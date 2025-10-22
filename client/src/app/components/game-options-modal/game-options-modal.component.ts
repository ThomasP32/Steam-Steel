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
    @Output() next = new EventEmitter<{ isFastElimination: boolean }>();

    isFastElimination: boolean = false;

    onClose(): void {
        this.closed.emit();
    }

    onNext(): void {
        this.next.emit({ isFastElimination: this.isFastElimination });
    }

    toggleFastElimination(): void {
        this.isFastElimination = !this.isFastElimination;
    }
}

