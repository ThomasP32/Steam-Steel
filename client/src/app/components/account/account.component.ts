import { CommonModule } from '@angular/common';
import { Component, EventEmitter, OnInit, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';

@Component({
    selector: 'app-account',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './account.component.html',
    styleUrls: ['./account.component.scss'],
})
export class AccountComponent implements OnInit {
    userInfo: any;
    editMode = false;
    editEmail = '';
    editUsername = '';
    editAvatar = '';
    editMessage = '';

    @Output() closed = new EventEmitter<void>();

    constructor(private readonly authService: AuthService) {
        this.authService = authService;
    }

    ngOnInit(): void {
        void this.loadUserInfo();
    }

    private async loadUserInfo(): Promise<void> {
        this.userInfo = await this.authService.getUserInfo();
        this.resetEditFields();
    }

    formatAvgTime(seconds: number): string {
        if (isNaN(seconds) || seconds < 0) return 'N/A';
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}m ${secs}s`;
    }

    resetEditFields() {
        if (this.userInfo?.user) {
            this.editEmail = this.userInfo.user.email;
            this.editUsername = this.userInfo.user.username;
            this.editAvatar = this.userInfo.user.avatar;
        }
        this.editMessage = '';
    }

    enableEdit() {
        this.editMode = true;
        this.editMessage = '';
    }

    async saveEdit() {
        try {
            const result = await this.authService.updateAccount(this.editEmail, this.editUsername, this.editAvatar);
            if (result?.success === false) {
                this.editMessage = result?.message || 'Erreur lors de la modification.';
                return;
            }
            this.editMode = false;
            this.userInfo = await this.authService.getUserInfo();
            this.resetEditFields();
            this.editMessage = 'Modifications enregistrées !';
        } catch (e: any) {
            this.editMode = true;
            if (e?.error) {
                try {
                    const parsed = typeof e.error === 'string' ? JSON.parse(e.error) : e.error;
                    this.editMessage = parsed?.message || 'Erreur lors de la modification.';
                } catch {
                    this.editMessage = e.error;
                }
            } else {
                this.editMessage = 'Erreur lors de la modification.';
            }
        }
    }

    cancelEdit() {
        this.editMode = false;
        this.resetEditFields();
    }

    logout(): void {
        localStorage.removeItem('authToken');
        this.closed.emit();
    }

    deleteAccount(): void {
        this.authService.deleteAccount().then(() => {
            localStorage.removeItem('authToken');
            this.closed.emit();
        });
    }
}
