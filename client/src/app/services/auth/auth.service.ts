import { Injectable } from '@angular/core';
import { ChallengeService } from '@app/services/challenge/challenge.service';
import { ChannelService } from '@app/services/channel/channel.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { Avatar, ProfilePicture } from '@common/game';
import { BehaviorSubject, firstValueFrom } from 'rxjs';
import { SocketService } from '../communication-socket/communication-socket.service';
@Injectable({ providedIn: 'root' })
export class AuthService {
    private readonly apiUrl = 'auth';
    private readonly authStateSubject = new BehaviorSubject<boolean>(!!localStorage.getItem('authToken'));
    public authState$ = this.authStateSubject.asObservable();

    constructor(
        private readonly communicationService: CommunicationMapService,
        private readonly socketService: SocketService,
        private readonly challengeService: ChallengeService,
        private readonly channelService: ChannelService,
    ) {
        this.communicationService = communicationService;
        this.socketService = socketService;
        this.challengeService = challengeService;
        this.channelService = channelService;
        this.setupAutoLogout();
    }

    isLoggedIn(): boolean {
        return !!localStorage.getItem('authToken');
    }

    private isElectron = !!(window as any).require;

    private setupAutoLogout(): void {
        if (this.isElectron) {
            // Pour Electron, se déconnecter seulement à la fermeture de l'app
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

    async register(
        email: string,
        password: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<any> {
        return firstValueFrom(
            this.communicationService.basicPost<any>(`${this.apiUrl}/register`, {
                email,
                password,
                username,
                avatar,
                avatarCustom: avatarCustom || null,
                profilePicture,
                profilePictureCustom: profilePictureCustom || null,
            }),
        );
    }

    async login(username: string, password: string): Promise<any> {
        let response: any;
        let body: any;
        try {
            response = await firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/login`, { username, password }));
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

        this.channelService.resetChannelState();

        this.authStateSubject.next(true);
        this.socketService.disconnect();
        this.socketService.connect();

        // Reinitialize challenge listeners for the new socket connection
        setTimeout(() => {
            this.challengeService.reinitializeListeners();
        }, 100);

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

    async updateAccount(
        email: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<any> {
        const token = localStorage.getItem('authToken');

        const response = await firstValueFrom(
            this.communicationService.basicPatch<any>(`${this.apiUrl}/update?token=${token}`, {
                email,
                username,
                avatar,
                avatarCustom: avatarCustom || null,
                profilePicture,
                profilePictureCustom: profilePictureCustom || null,
            }),
        );
        const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;

        if (body && body.success !== false) {
            this.authStateSubject.next(true);
        }

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

        this.channelService.resetChannelState();

        this.authStateSubject.next(false);
    }

    private logoutSync(): void {
        const token = localStorage.getItem('authToken');

        this.socketService.disconnect();

        this.channelService.resetChannelState();

        if (token) {
            try {
                if (this.isElectron) {
                    const url = `${this.communicationService['baseUrl']}/${this.apiUrl}/logout?token=${token}`;
                    const data = new Blob(['{}'], { type: 'application/json' });
                    navigator.sendBeacon(url, data);
                }
            } catch (error) {
                console.log('Erreur lors de la déconnexion synchrone:', error);
            }
        }

        localStorage.removeItem('authToken');
        this.authStateSubject.next(false);
    }
}
