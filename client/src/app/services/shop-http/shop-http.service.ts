import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { ShopItem } from '@common/events/shop.events';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

@Injectable({
    providedIn: 'root',
})
export class ShopHttpService {
    private readonly baseUrl = `${environment.serverUrl}/shop`;

    constructor(private http: HttpClient) {
        this.http = http;
    }

    getCatalog(): Observable<ShopItem[]> {
        return this.http.get<ShopItem[]>(`${this.baseUrl}/catalog`);
    }

    getCatalogWithUserStatus(userId: string): Observable<ShopItem[]> {
        return this.http.get<ShopItem[]>(`${this.baseUrl}/catalog/${userId}`);
    }

    getUserItems(userId: string): Observable<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        return this.http.get<{ itemId: string; equipped: boolean; purchaseDate: Date }[]>(`${this.baseUrl}/user-items/${userId}`);
    }

    getUserItemsByUsername(username: string): Observable<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        return this.http.get<{ itemId: string; equipped: boolean; purchaseDate: Date }[]>(`${this.baseUrl}/user-items-by-username/${username}`);
    }

    purchaseItem(userId: string, itemId: string): Observable<{ success: boolean; newBalance?: number; error?: string }> {
        return this.http.post<{ success: boolean; newBalance?: number; error?: string }>(`${this.baseUrl}/purchase`, {
            userId,
            itemId,
        });
    }

    equipItem(userId: string, itemId: string): Observable<{ success: boolean; error?: string }> {
        return this.http.post<{ success: boolean; error?: string }>(`${this.baseUrl}/equip`, {
            userId,
            itemId,
        });
    }

    unequipItem(userId: string, itemId: string): Observable<{ success: boolean; error?: string }> {
        return this.http.post<{ success: boolean; error?: string }>(`${this.baseUrl}/unequip`, {
            userId,
            itemId,
        });
    }
}
