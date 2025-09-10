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
        let response: any;
        let body: any;
        try {
            response = await firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/login`, { email, password }));
            body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        } catch (err: any) {
            let errorMsg = "Erreur d'authentification.";
            if (err?.error) {
                try {
                    const parsed = typeof err.error === 'string' ? JSON.parse(err.error) : err.error;
                    errorMsg = parsed?.message || errorMsg;
                } catch {
                    errorMsg = err.error;
                }
            }
            throw new Error(errorMsg);
        }

        if (!body?.token) {
            throw new Error(body?.message || "Erreur d'authentification.");
        }

        localStorage.setItem('authToken', body.token);
        return await new Promise((resolve, reject) => {
            let resolved = false;
            const timeoutId = setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    resolve(response);
                }
            }, 1000);
            try {
                this.socketService.disconnect();
                this.socketService.connect();
                this.socketService.socket?.once('auth_error', (msg: string) => {
                    if (!resolved) {
                        resolved = true;
                        clearTimeout(timeoutId);
                        this.socketService.disconnect();
                        try {
                            const token = localStorage.getItem('authToken');
                            const payload = token ? JSON.parse(atob(token.split('.')[1])) : null;
                            if (payload && payload.userId === body.user?._id) {
                                localStorage.removeItem('authToken');
                            }
                        } catch {
                            reject(new Error(msg || 'Ce compte est déjà connecté ailleurs.'));
                        }
                    }
                });
            } catch (e) {
                if (!resolved) {
                    resolved = true;
                    clearTimeout(timeoutId);
                    resolve(response);
                }
            }
        });
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
