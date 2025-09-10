import { Injectable } from '@angular/core';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { firstValueFrom } from 'rxjs';
import { SocketService } from '../communication-socket/communication-socket.service';
@Injectable({ providedIn: 'root' })
export class AuthService {
    private readonly apiUrl = 'auth';

    constructor(
        private readonly communicationService: CommunicationMapService,
        private readonly socketService: SocketService,
    ) {
        this.communicationService = communicationService;
        this.socketService = socketService;
    }

    async register(email: string, password: string, username: string, avatar?: string): Promise<any> {
        return firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/register`, { email, password, username, avatar }));
    }

    async login(email: string, password: string): Promise<any> {
        const response = await firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/login`, { email, password }));
        const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        if (body?.token) {
            localStorage.setItem('authToken', body.token);
            // Utilise le service socket pour ouvrir la connexion
            try {
                this.socketService.connect();
                // Optionnel: écouter l'event 'auth_error' pour déconnecter si refusé
                this.socketService.socket?.on('auth_error', (msg: string) => {
                    this.socketService.disconnect();
                    alert(msg);
                });
            } catch (e) {
                // ignore si le service n'est pas dispo
            }
            return response;
        }
    }

    async getUserInfo(): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicGet<any>(`${this.apiUrl}/me?token=${token}`));
    }

    async deleteAccount(): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicDelete(`${this.apiUrl}/delete?token=${token}`));
    }

    async updateAccount(email: string, username: string, avatar?: string): Promise<any> {
        const token = localStorage.getItem('authToken');
        const response = await firstValueFrom(
            this.communicationService.basicPatch<any>(`${this.apiUrl}/update?token=${token}`, { email, username, avatar }),
        );
        const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        return body;
    }

    async updateStats(stats: { mode: string; isWin: boolean; duration: number }): Promise<any> {
        const token = localStorage.getItem('authToken');
        return firstValueFrom(this.communicationService.basicPatch<any>(`${this.apiUrl}/stats?token=${token}`, stats));
    }
}
