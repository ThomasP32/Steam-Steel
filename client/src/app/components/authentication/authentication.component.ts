import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ProfilePicture } from '@common/game';
import { AuthService } from '../../services/auth/auth.service';
import { ProfilePictureComponent } from '../profile-picture/profile-picture.component';

@Component({
    selector: 'app-authentication',
    standalone: true,
    imports: [FormsModule, CommonModule, ProfilePictureComponent],
    templateUrl: './authentication.component.html',
    styleUrl: './authentication.component.scss',
})
export class AuthenticationComponent {
    @Input() mode: 'login' | 'register' | 'both' = 'both';

    registerEmail = '';
    registerPassword = '';
    registerUsername = '';
    registerProfilePicture: ProfilePicture = ProfilePicture.Profile1;
    registerCustomProfilePicturePreview: string | undefined;
    loginUsername = '';
    loginPassword = '';
    registerMessage = '';
    loginMessage = '';
    showRegisterPassword = false;
    showLoginPassword = false;

    @Output() closed = new EventEmitter<void>();

    constructor(private readonly authService: AuthService) {
        this.authService = authService;
    }

    async register() {
        const profilePicture = this.registerProfilePicture;
        const profilePictureCustom = this.registerCustomProfilePicturePreview;
        const result = await this.handleAuth(() =>
            this.authService.register(
                this.registerEmail,
                this.registerPassword,
                this.registerUsername,
                undefined,
                undefined,
                profilePicture,
                profilePictureCustom,
            ),
        );
        this.registerMessage = result.message;
        if (result.success) {
            const loginResult = await this.handleAuth(() => 
                this.authService.login(this.registerUsername, this.registerPassword)
            );
            if (loginResult.success) {
                this.closed.emit();
            }
        }
    }

    async login() {
        const result = await this.handleAuth(() => this.authService.login(this.loginUsername, this.loginPassword));
        this.loginMessage = result.message || (result.success ? 'Connexion réussie !' : 'Erreur lors de la connexion.');
        if (result.success) {
            this.closed.emit();
        }
    }

    onInput(event: Event, fieldName: string): void {
        const target = event.target as HTMLInputElement;
        let value = target.value;

        value = value.replace(/\s/g, '');

        switch (fieldName) {
            case 'registerEmail':
                this.registerEmail = value;
                break;
            case 'registerPassword':
                this.registerPassword = value;
                break;
            case 'registerUsername':
                this.registerUsername = value;
                break;
            case 'loginUsername':
                this.loginUsername = value;
                break;
            case 'loginPassword':
                this.loginPassword = value;
                break;
        }

        target.value = value;
    }

    onRegisterPasswordMouseDown(): void {
        this.showRegisterPassword = true;
    }

    onRegisterPasswordMouseUp(): void {
        this.showRegisterPassword = false;
    }

    onLoginPasswordMouseDown(): void {
        this.showLoginPassword = true;
    }

    onLoginPasswordMouseUp(): void {
        this.showLoginPassword = false;
    }

    private async handleAuth(requestFn: () => Promise<any>): Promise<{ success: boolean; message: string }> {
        try {
            const response = await requestFn();
            const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
            return { success: true, message: body?.message || '' };
        } catch (err: any) {
            if (err?.error) {
                try {
                    const parsed = typeof err.error === 'string' ? JSON.parse(err.error) : err.error;
                    return { success: false, message: parsed?.message || '' };
                } catch {
                    return { success: false, message: err.error };
                }
            }
            return { success: false, message: err?.message || 'Erreur inconnue' };
        }
    }
}
