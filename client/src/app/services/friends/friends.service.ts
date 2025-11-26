import { Injectable } from '@angular/core';
import { FriendsEvents } from '@common/events/friends.events';
import { Friend, FriendRequest, UserStatus } from '@common/user-friends';
import { BehaviorSubject, firstValueFrom } from 'rxjs';
import { SocketService } from '../communication-socket/communication-socket.service';
import { CommunicationMapService } from '../communication/communication.map.service';

@Injectable({
    providedIn: 'root',
})
export class FriendsService {
    private friendsSubject = new BehaviorSubject<Friend[]>([]);
    public friends$ = this.friendsSubject.asObservable();

    private friendRequestsSubject = new BehaviorSubject<FriendRequest[]>([]);
    public friendRequests$ = this.friendRequestsSubject.asObservable();

    constructor(
        private readonly communicationService: CommunicationMapService,
        private readonly socketService: SocketService,
    ) {
        this.communicationService = communicationService;
        this.socketService = socketService;
    }

    private parseResponse(response: any): any {
        if (response.error) {
            return response.error;
        }

        let result = response.body || response;
        if (typeof result === 'string') {
            try {
                result = JSON.parse(result);
            } catch {
                result = { success: false, message: result };
            }
        }

        if (!result) {
            return { success: false, message: 'Réponse vide du serveur' };
        }

        return result;
    }

    public initializeFriendsSocket(): void {
        this.socketService.listen<{ username: string; status: UserStatus }>(FriendsEvents.FriendStatusUpdate).subscribe((update) => {
            this.updateFriendStatus(update.username, update.status);
        });

        this.socketService.listen<{ friends: Friend[] }>(FriendsEvents.FriendListUpdated).subscribe((update) => {
            this.friendsSubject.next(update.friends);
        });

        this.socketService.listen<{ friendRequests: FriendRequest[] }>(FriendsEvents.FriendRequestsUpdated).subscribe((update) => {
            this.friendRequestsSubject.next(update.friendRequests);
        });
    }

    public listenForNewUsers() {
        return this.socketService.listen<{ user: { username: string; level: number } }>(FriendsEvents.NewUserRegistered);
    }

    async loadFriends(): Promise<void> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicGet(`friends/${token}`))) as any;
            const result = this.parseResponse(response);

            if (result.success && result.friends) {
                this.friendsSubject.next(result.friends);
            }
        } catch (error) {
            console.error('Error loading friends:', error);
        }
    }
    async loadFriendRequests(): Promise<void> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicGet(`friends/requests/${token}`))) as any;
            const result = this.parseResponse(response);

            if (result.success && result.friendRequests) {
                this.friendRequestsSubject.next(result.friendRequests);
            }
        } catch (error) {
            console.error('Error loading friend requests:', error);
        }
    }

    async addFriend(username: string): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicPost('friends/add', { username, token }))) as any;
            return this.parseResponse(response);
        } catch (error) {
            return { success: false, message: "Erreur lors de l'envoi de la demande d'ami" };
        }
    }
    async acceptFriendRequest(username: string): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicPost(`friends/accept/${username}`, { token }))) as any;
            const result = this.parseResponse(response);

            if (result.success && result.friends) {
                this.friendsSubject.next(result.friends);
            }
            await this.loadFriendRequests();
            return result;
        } catch (error) {
            return { success: false, message: "Erreur lors de l'acceptation de la demande" };
        }
    }

    async rejectFriendRequest(username: string): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicPost(`friends/reject/${username}`, { token }))) as any;
            const result = this.parseResponse(response);

            if (result.success) {
                await this.loadFriendRequests();
            }
            return result;
        } catch (error) {
            return { success: false, message: 'Erreur lors du refus de la demande' };
        }
    }

    async removeFriend(username: string): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            const response = (await firstValueFrom(this.communicationService.basicDeleteWithBody(`friends/remove/${username}`, { token }))) as any;
            const result = this.parseResponse(response);

            if (result.success && result.friends) {
                this.friendsSubject.next(result.friends);
            }
            return result;
        } catch (error) {
            return { success: false, message: "Erreur lors de la suppression de l'ami" };
        }
    }

    private updateFriendStatus(username: string, status: UserStatus): void {
        const currentFriends = this.friendsSubject.value;
        const updatedFriends = currentFriends.map((friend) => (friend.username === username ? { ...friend, status } : friend));
        this.friendsSubject.next(updatedFriends);
    }

    getFriends(): Friend[] {
        return this.friendsSubject.value;
    }

    getOnlineFriends(): Friend[] {
        return this.friendsSubject.value.filter((friend) => friend.status === UserStatus.Online || friend.status === UserStatus.InGame);
    }

    inviteAllOnlineFriends(gameId: string, gameName: string): void {
        if (this.socketService.isSocketAlive()) {
            this.socketService.sendMessage(FriendsEvents.InviteAllOnlineFriends, { gameId, gameName });
        }
    }

    acceptGameInvitation(gameId: string, inviterUsername: string): void {
        if (this.socketService.isSocketAlive()) {
            this.socketService.sendMessage(FriendsEvents.GameInvitationAccepted, { gameId, inviterUsername });
        }
    }

    rejectGameInvitation(gameId: string, inviterUsername: string): void {
        if (this.socketService.isSocketAlive()) {
            this.socketService.sendMessage(FriendsEvents.GameInvitationRejected, { gameId, inviterUsername });
        }
    }
}
