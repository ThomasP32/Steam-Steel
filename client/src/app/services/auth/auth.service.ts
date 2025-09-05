import { Injectable } from '@angular/core';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { firstValueFrom } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
    private apiUrl = 'auth';

    constructor(private readonly communicationService: CommunicationMapService) {}

    async register(email: string, password: string, pseudonyme: string, avatar?: string): Promise<any> {
        return firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/register`, { email, password, pseudonyme, avatar }));
    }

    async login(email: string, password: string): Promise<any> {
        return firstValueFrom(this.communicationService.basicPost<any>(`${this.apiUrl}/login`, { email, password }));
    }
}
