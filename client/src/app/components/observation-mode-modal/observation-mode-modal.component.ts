import { Component, Input } from '@angular/core';

@Component({
    selector: 'app-observation-mode-modal',
    standalone: true,
    imports: [],
    templateUrl: './observation-mode-modal.component.html',
    styleUrl: './observation-mode-modal.component.scss',
})
export class ObservationModeModalComponent {
    @Input() message: string = 'Vous êtes maintenant en mode observation.';
    @Input() closeModal: () => void;

    onClose(): void {
        if (this.closeModal) {
            this.closeModal();
        }
    }
}
