import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';

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
    @Output() next = new EventEmitter<{ isFastElimination: boolean; isDropInOut: boolean; isFriendsOnly: boolean; entryFee: number }>();

    isFastElimination: boolean = false;
    isDropInOut: boolean = false;
    isFriendsOnly: boolean = false;
    entryFee: number = 0;
    hasEntryFeeError: boolean = false;
    showAlert: boolean = false;
    insufficientFunds: boolean = false;
    private userMoney: number = 0;
    private authService = inject(AuthService);

    constructor() {
        this.loadUserMoney();
    }

    async loadUserMoney(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            this.userMoney = userInfo.user.virtualMoney || 0;
        } catch (error) {
            console.error('Error loading user money:', error);
            this.userMoney = 0;
        }
    }

    onClose(): void {
        this.closed.emit();
    }

    onNext(): void {
        if (this.entryFee > 500) {
            this.hasEntryFeeError = true;
            this.showAlert = true;
            return;
        }

        if (this.entryFee > this.userMoney) {
            this.insufficientFunds = true;
            return;
        }

        this.next.emit({
            isFastElimination: this.isFastElimination,
            isDropInOut: this.isDropInOut,
            isFriendsOnly: this.isFriendsOnly,
            entryFee: this.entryFee,
        });
    }

    closeAlert(): void {
        this.showAlert = false;
    }

    validateEntryFee(): void {
        if (this.entryFee < 0) {
            this.entryFee = 0;
        }
        this.entryFee = Math.floor(this.entryFee);
        this.hasEntryFeeError = this.entryFee > 500;
        this.insufficientFunds = this.entryFee > this.userMoney && this.entryFee <= 500;
    }

    onFocus(): void {
        if (this.entryFee === 0) {
            this.entryFee = null as any;
        }
    }

    onBlur(): void {
        if (this.entryFee === null || this.entryFee === undefined || this.entryFee.toString() === '') {
            this.entryFee = 0;
        }
        this.validateEntryFee();
    }

    onKeyDown(event: KeyboardEvent): void {
        const blockedKeys = ['.', ',', '-', 'e', 'E'];
        if (blockedKeys.includes(event.key)) {
            event.preventDefault();
        }
    }

    isEntryFeeValid(): boolean {
        return this.entryFee > 0 && this.entryFee <= 500;
    }

    canProceed(): boolean {
        if (this.entryFee > 500) return false;
        return this.entryFee <= this.userMoney;
    }

    toggleFastElimination(): void {
        this.isFastElimination = !this.isFastElimination;
    }

    toggleDropInOut(): void {
        this.isDropInOut = !this.isDropInOut;
    }

    toggleFriendsOnly(): void {
        this.isFriendsOnly = !this.isFriendsOnly;
    }
}
