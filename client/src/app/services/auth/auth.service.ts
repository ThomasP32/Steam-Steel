import { Injectable } from '@angular/core';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { Avatar } from '@common/game';
import { BehaviorSubject, firstValueFrom } from 'rxjs';
import { SocketService } from '../communication-socket/communication-socket.service';
@Injectable({ providedIn: 'root' })
export class AuthService {
    private readonly apiUrl = 'auth';
    private authStateSubject = new BehaviorSubject<boolean>(!!localStorage.getItem('authToken'));
    public authState$ = this.authStateSubject.asObservable();

    constructor(
        private readonly communicationService: CommunicationMapService,
        private readonly socketService: SocketService,
    ) {
        this.communicationService = communicationService;
        this.socketService = socketService;
        this.setupAutoLogout();
    }

    isLoggedIn(): boolean {
        return !!localStorage.getItem('authToken');
    }

    private setupAutoLogout(): void {
        // Déconnexion automatique quand la page/app se ferme
        window.addEventListener('beforeunload', () => {
            this.logoutSync();
        });

        // Pour Electron spécifiquement
        if ((window as any).require) {
            try {
                const { ipcRenderer } = (window as any).require('electron');
                ipcRenderer.on('app-closing', () => {
                    this.logoutSync();
                });
            } catch (e) {
                // Ignore si pas dans Electron
            }
        }
    }

    async register(email: string, password: string, username: string, avatar: Avatar, avatarCustom?: string): Promise<any> {
        return firstValueFrom(
            this.communicationService.basicPost<any>(`${this.apiUrl}/register`, {
                email,
                password,
                username,
                avatar,
                avatarCustom: avatarCustom || null,
            }),
        );
    }

    async login(email: string, password: string): Promise<any> {
        let response: any;
        let body: any;
        try {
            response = await firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/login`, { email, password }));
            body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
            if (!body?.token) {
                throw new Error(body?.message || "Erreur d'authentification.");
            }
        } catch (err: any) {
            let errorMsg = "Erreur d'authentification.";
            if (err?.error) {
                try {
                    const parsed = typeof err.error === 'string' ? JSON.parse(err.error) : err.error;
                    errorMsg = parsed?.message || errorMsg;
                } catch {
                    errorMsg = err.error;
                }
            } else if (err?.message) {
                errorMsg = err.message;
            }
            throw new Error(errorMsg);
        }

        localStorage.setItem('authToken', body.token);
        this.authStateSubject.next(true);
        this.socketService.disconnect();
        this.socketService.connect();
        return response;
    }

    async getUserInfo(): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicGet<any>(`${this.apiUrl}/me?token=${token}`));
    }

    async deleteAccount(): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicDelete(`${this.apiUrl}/delete?token=${token}`));
    }

    async updateAccount(email: string, username: string, avatar?: Avatar, avatarCustom?: string): Promise<any> {
        const token = localStorage.getItem('authToken');
        const response = await firstValueFrom(
            this.communicationService.basicPatch<any>(`${this.apiUrl}/update?token=${token}`, {
                email,
                username,
                avatar,
                avatarCustom: avatarCustom || null,
            }),
        );
        const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        return body;
    }

    async updateStats(stats: { mode: string; isWin: boolean; duration: number }): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicPatch<any>(`${this.apiUrl}/stats?token=${token}`, stats));
    }

    async logout(): Promise<void> {
        const token = localStorage.getItem('authToken');
        if (token) {
            try {
                await firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/logout?token=${token}`, {}));
            } catch (error) {
                console.log('Erreur lors de la déconnexion côté serveur:', error);
            }
        }

        localStorage.removeItem('authToken');
        this.socketService.disconnect();

        this.authStateSubject.next(false);
    }

    private logoutSync(): void {
        const token = localStorage.getItem('authToken');
        if (token) {
            try {
                // Utiliser navigator.sendBeacon pour un appel synchrone lors de la fermeture
                const url = `${this.communicationService['baseUrl']}/${this.apiUrl}/logout?token=${token}`;
                const data = new Blob(['{}'], { type: 'application/json' });
                navigator.sendBeacon(url, data);
            } catch (error) {
                console.log('Erreur lors de la déconnexion synchrone:', error);
            }
        }

        localStorage.removeItem('authToken');
        this.socketService.disconnect();

        this.authStateSubject.next(false);
    }
}
