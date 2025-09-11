import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CharacterService } from '@app/services/character/character.service';
import { Avatar } from '@common/game';
import { AuthService } from '../../services/auth/auth.service';
@Component({
    selector: 'app-authentication',
    standalone: true,
    imports: [FormsModule, CommonModule],
    templateUrl: './authentication.component.html',
    styleUrl: './authentication.component.scss',
})
export class AuthenticationComponent {
    registerEmail = '';
    registerPassword = '';
    registerUsername = '';
    registerAvatar: Avatar = Avatar.Avatar1;
    loginEmail = '';
    loginPassword = '';
    registerMessage = '';
    loginMessage = '';

    avatars = this.characterService.characters;

    @Output() closed = new EventEmitter<void>();

    constructor(
        private readonly authService: AuthService,
        public characterService: CharacterService,
    ) {
        this.authService = authService;
    }

    async register() {
        this.registerMessage = await this.handleAuth(() =>
            this.authService.register(this.registerEmail, this.registerPassword, this.registerUsername, this.registerAvatar),
        );
    }

    async login() {
        this.loginMessage = '';
        try {
            const response = await this.authService.login(this.loginEmail, this.loginPassword);
            const body = typeof response?.body === 'string' ? JSON.parse(response.body) : response?.body;
            this.loginMessage = body?.message || 'Connexion réussie !';
            this.closed.emit();
        } catch (e: any) {
            this.loginMessage = e?.message || 'Erreur lors de la connexion.';
        }
    }

    private async handleAuth(requestFn: () => Promise<any>): Promise<string> {
        try {
            const response = await requestFn();
            const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
            return body?.message || '';
        } catch (err: any) {
            if (err?.error) {
                try {
                    const parsed = typeof err.error === 'string' ? JSON.parse(err.error) : err.error;
                    return parsed?.message || '';
                } catch {
                    return err.error;
                }
            }
            return '';
        }
    }
}
