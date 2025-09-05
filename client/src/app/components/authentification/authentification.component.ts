import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../services/auth/auth.service';
@Component({
    selector: 'app-authentification',
    standalone: true,
    imports: [FormsModule, CommonModule],
    templateUrl: './authentification.component.html',
    styleUrl: './authentification.component.scss',
})
export class AuthentificationComponent {
    registerEmail = '';
    registerPassword = '';
    registerPseudonyme = '';
    registerAvatar = '';
    loginEmail = '';
    loginPassword = '';
    registerMessage = '';
    loginMessage = '';

    constructor(private authService: AuthService) {}

    async register() {
        this.registerMessage = await this.handleAuth(() =>
            this.authService.register(this.registerEmail, this.registerPassword, this.registerPseudonyme, this.registerAvatar),
        );
    }

    async login() {
        this.loginMessage = await this.handleAuth(() => this.authService.login(this.loginEmail, this.loginPassword));
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
