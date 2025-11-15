import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { CharacterService } from '@app/services/character/character.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { Avatar } from '@common/game';
import { Friend, FriendRequest, UserStatus } from '@common/user-friends';
import { Subject, takeUntil } from 'rxjs';

@Component({
    selector: 'app-friends-list',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './friends-list.component.html',
    styleUrls: ['./friends-list.component.scss'],
})
export class FriendsListComponent implements OnInit, OnDestroy {
    friends: Friend[] = [];
    friendRequests: FriendRequest[] = [];
    isAddingFriend: boolean = false;
    friendError: string = '';
    activeTab: 'friends' | 'requests' = 'friends';
    currentUsername: string = '';

    allUsers: { username: string, level: number }[] = [];
    searchQuery: string = '';
    isLoadingUsers: boolean = false;
    selectedUserForAdd: string = '';
    filteredUsers: { username: string }[] = [];

    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly friendsService: FriendsService,
        private readonly characterService: CharacterService,
        private readonly communicationMapService: CommunicationMapService,
        private readonly authService: AuthService,
    ) {
        this.friendsService = friendsService;
        this.characterService = characterService;
        this.communicationMapService = communicationMapService;
        this.authService = authService;
    }

    async ngOnInit(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            this.currentUsername = userInfo?.user?.username || '';
        } catch (error) {
            console.error("Erreur lors de la récupération du nom d'utilisateur:", error);
        }

        this.loadFriends();
        this.loadFriendRequests();
        this.loadAllUsers();

        this.friendsService.friends$.pipe(takeUntil(this.unsubscribe$)).subscribe((friends) => {
            this.friends = friends;
            this.updateFilteredUsers();
        });

        this.friendsService.friendRequests$.pipe(takeUntil(this.unsubscribe$)).subscribe((friendRequests) => {
            this.friendRequests = friendRequests;
            this.updateFilteredUsers();
        });
    }

    ngOnDestroy(): void {
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }

    async loadFriends(): Promise<void> {
        await this.friendsService.loadFriends();
    }

    async loadFriendRequests(): Promise<void> {
        await this.friendsService.loadFriendRequests();
    }

    async loadAllUsers(): Promise<void> {
        this.isLoadingUsers = true;

        try {
            const token = localStorage.getItem('authToken');
            const response = await this.communicationMapService
                .basicGet<{ success: boolean; users: any[] }>(`auth/users/search?q=&token=${token}`)
                .toPromise();

            if (response && response.success) {
                this.allUsers = response.users;

                this.updateFilteredUsers();
            } else {
                console.error('❌ Échec de la récupération des utilisateurs:', response);
            }
        } catch (error) {
            console.error('💥 Erreur lors du chargement des utilisateurs:', error);
        } finally {
            this.isLoadingUsers = false;
        }
    }

    async addFriendFromList(username: string): Promise<void> {
        this.isAddingFriend = true;
        this.selectedUserForAdd = username;
        this.friendError = '';

        const result = await this.friendsService.addFriend(username);

        if (result.success) {
            this.friendError = "La demande d'ami a été envoyée avec succès";
            this.updateFilteredUsers();
        } else {
            this.friendError = result.message || "Erreur lors de l'envoi de la demande d'ami";
        }

        this.isAddingFriend = false;
        this.selectedUserForAdd = '';
    }

    async acceptFriendRequest(username: string): Promise<void> {
        const result = await this.friendsService.acceptFriendRequest(username);

        if (!result.success) {
            this.friendError = result.message || '';
        }
    }

    async rejectFriendRequest(username: string): Promise<void> {
        const result = await this.friendsService.rejectFriendRequest(username);

        if (!result.success) {
            this.friendError = result.message || '';
        }
    }

    async removeFriend(username: string): Promise<void> {
        const result = await this.friendsService.removeFriend(username);

        if (!result.success) {
            this.friendError = result.message || '';
        }
    }

    switchTab(tab: 'friends' | 'requests'): void {
        this.activeTab = tab;
        if (tab === 'requests') {
            this.loadFriendRequests();
        } else if (tab === 'friends') {
            this.loadFriends();
            this.loadAllUsers();
            this.friendError = '';
        }
    }

    getFriendRequestsCount(): number {
        return this.friendRequests.length;
    }

    getTotalUsersCount(): number {
        return this.getFilteredFriends().length + this.getFilteredOtherUsers().length;
    }

    onSearchInput(event: Event): void {
        const target = event.target as HTMLInputElement;
        this.searchQuery = target.value;
        this.updateFilteredUsers();
    }

    updateFilteredUsers(): void {
        if (!this.allUsers) {
            return;
        }

        const query = this.searchQuery.toLowerCase().trim();

        let filteredUsers = this.allUsers.filter((user) => user.username !== this.currentUsername);

        if (query) {
            filteredUsers = filteredUsers.filter((user) => user.username.toLowerCase().includes(query));
        }

        this.filteredUsers = filteredUsers;
    }

    getFilteredFriends(): Friend[] {
        const friendUsernames = this.friends.map((f) => f.username);
        const filteredFriendUsernames = this.filteredUsers.filter((user) => friendUsernames.includes(user.username)).map((user) => user.username);

        return this.friends.filter((friend) => filteredFriendUsernames.includes(friend.username));
    }

    getFilteredOtherUsers(): { username: string }[] {
        const friendUsernames = this.friends.map((f) => f.username);
        return this.filteredUsers.filter((user) => !friendUsernames.includes(user.username));
    }

    getUserAvatarUrl(user: Friend | { username: string }): string {
        if ('avatar' in user || 'avatarCustom' in user) {
            const friend = user as Friend;
            if (friend.avatarCustom) {
                return friend.avatarCustom;
            }

            if (friend.avatar) {
                const avatarId = typeof friend.avatar === 'string' ? parseInt(friend.avatar, 10) : friend.avatar;
                if (avatarId && Object.values(Avatar).includes(avatarId as Avatar)) {
                    return this.characterService.getAvatarPreview(avatarId as Avatar);
                }
            }
        }

        return '';
    }

    getFriendLevel(username: string): number {
        const user = this.allUsers.find((user) => user.username === username);
        return user?.level ?? 1;
    }

    getPendingRequestStatus(username: string): string {
        const sentRequest = this.friendRequests.find((req) => req.from === username);
        const receivedRequest = this.friendRequests.find((req) => req.to === username);

        if (sentRequest) return 'Demande reçue';
        if (receivedRequest) return 'Demande envoyée';
        return '';
    }

    getStatusText(status?: UserStatus): string {
        switch (status) {
            case UserStatus.Online:
                return 'En ligne';
            case UserStatus.InGame:
                return 'En jeu';
            case UserStatus.Offline:
                return 'Hors ligne';
            default:
                return 'Inconnu';
        }
    }

    getStatusClass(status?: UserStatus): string {
        switch (status) {
            case UserStatus.Online:
                return 'status-online';
            case UserStatus.InGame:
                return 'status-ingame';
            case UserStatus.Offline:
                return 'status-offline';
            default:
                return 'status-unknown';
        }
    }
}
