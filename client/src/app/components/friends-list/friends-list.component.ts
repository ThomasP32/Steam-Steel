import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { ProfilePictureService } from '@app/services/profile-picture/profile-picture.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { ProfilePicture } from '@common/game';
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
    friendErrorType: 'success' | 'error' = 'error';
    activeTab: 'friends' | 'requests' = 'friends';
    currentUsername: string = '';

    allUsers: { username: string; level: number }[] = [];
    friendsSearchQuery: string = '';
    othersSearchQuery: string = '';
    isLoadingUsers: boolean = false;
    selectedUserForAdd: string = '';
    filteredUsers: { username: string }[] = [];
    requestStatusMap: Map<string, 'sent' | 'received'> = new Map();
    addedFriendsSet: Set<string> = new Set();

    friendsSectionCollapsed: boolean = true;
    othersSectionCollapsed: boolean = false;

    private readonly friendBanners: Map<string, string> = new Map();
    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly friendsService: FriendsService,
        private readonly profilePictureService: ProfilePictureService,
        private readonly communicationMapService: CommunicationMapService,
        private readonly authService: AuthService,
        private readonly shopHttpService: ShopHttpService,
    ) {
        this.friendsService = friendsService;
        this.profilePictureService = profilePictureService;
        this.communicationMapService = communicationMapService;
        this.authService = authService;
        this.shopHttpService = shopHttpService;
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
            this.loadFriendsBanners();
        });

        this.friendsService.friendRequests$.pipe(takeUntil(this.unsubscribe$)).subscribe((friendRequests) => {
            this.friendRequests = friendRequests;
            this.updateRequestStatusMap();
            this.updateFilteredUsers();
        });

        this.friendsService
            .listenForNewUsers()
            .pipe(takeUntil(this.unsubscribe$))
            .subscribe((data: { user: { username: string; level: number } }) => {
                const existingUser = this.allUsers.find((user) => user.username === data.user.username);
                if (!existingUser) {
                    this.allUsers.push({
                        username: data.user.username,
                        level: data.user.level,
                    });
                    this.updateFilteredUsers();
                }
            });
    }

    ngOnDestroy(): void {
        this.unsubscribe$.next();
        this.unsubscribe$.complete();
    }

    private updateRequestStatusMap(): void {
        this.requestStatusMap.clear();
        this.friendRequests.forEach((request) => {
            if (request.from === this.currentUsername) {
                this.requestStatusMap.set(request.to, 'sent');
            } else {
                this.requestStatusMap.set(request.from, 'received');
            }
        });
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
            this.friendErrorType = 'success';
            this.addedFriendsSet.add(username);
            this.requestStatusMap.set(username, 'sent');
            this.updateFilteredUsers();
            setTimeout(() => {
                if (this.friendErrorType === 'success') {
                    this.friendError = '';
                }
            }, 3000);
        } else {
            this.friendError = result.message || "Erreur lors de l'envoi de la demande d'ami";
            this.friendErrorType = 'error';
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
        this.isAddingFriend = false;
        this.selectedUserForAdd = '';

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
        this.friendError = '';
        this.friendsSearchQuery = '';
        this.othersSearchQuery = '';

        if (tab === 'requests') {
            this.loadFriendRequests();
        } else if (tab === 'friends') {
            this.loadFriends();
            this.loadAllUsers();
        }
    }

    getFriendRequestsCount(): number {
        return this.friendRequests.length;
    }

    getTotalUsersCount(): number {
        return this.getFilteredFriends().length + this.getFilteredOtherUsers().length;
    }

    onFriendsSearchInput(event: Event): void {
        const target = event.target as HTMLInputElement;
        this.friendsSearchQuery = target.value;
    }

    onOthersSearchInput(event: Event): void {
        const target = event.target as HTMLInputElement;
        this.othersSearchQuery = target.value;
        this.updateFilteredUsers();
    }

    updateFilteredUsers(): void {
        if (!this.allUsers) {
            return;
        }

        const query = this.othersSearchQuery.toLowerCase().trim();

        let filteredUsers = this.allUsers.filter((user) => user.username !== this.currentUsername);

        if (query) {
            filteredUsers = filteredUsers.filter((user) => user.username.toLowerCase().includes(query));
        }

        this.filteredUsers = filteredUsers;
    }

    getFilteredFriends(): Friend[] {
        if (!this.friendsSearchQuery.trim()) {
            return this.friends;
        }

        const query = this.friendsSearchQuery.toLowerCase().trim();
        return this.friends.filter((friend) => friend.username.toLowerCase().includes(query));
    }

    getFilteredOtherUsers(): { username: string }[] {
        const friendUsernames = new Set(this.friends.map((f) => f.username));
        return this.filteredUsers.filter((user) => !friendUsernames.has(user.username));
    }

    getUserProfilePictureUrl(user: Friend | { username: string }): string {
        if ('profilePicture' in user || 'profilePictureCustom' in user) {
            const friend = user as Friend;
            if (friend.profilePictureCustom) {
                return friend.profilePictureCustom;
            }

            if (friend.profilePicture) {
                const profilePictureId = typeof friend.profilePicture === 'string' ? parseInt(friend.profilePicture, 10) : friend.profilePicture;
                if (profilePictureId && Object.values(ProfilePicture).includes(profilePictureId as ProfilePicture)) {
                    return this.profilePictureService.getProfilePicturePreview(profilePictureId as ProfilePicture);
                }
            }
        }

        // Fallback to avatar if profile picture is not available
        if ('avatar' in user || 'avatarCustom' in user) {
            const friend = user as Friend;
            if (friend.avatarCustom) {
                return friend.avatarCustom;
            }
        }

        return '';
    }

    getFriendLevel(username: string): number {
        const user = this.allUsers.find((user) => user.username === username);
        return user?.level ?? 1;
    }

    getPendingRequestStatus(username: string): string {
        const status = this.requestStatusMap.get(username);
        if (status === 'received') return 'Demande reçue';
        if (status === 'sent') return 'Demande envoyée';
        return '';
    }

    hasPendingRequest(username: string): boolean {
        return this.requestStatusMap.has(username) || this.addedFriendsSet.has(username);
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

    private async loadFriendsBanners(): Promise<void> {
        if (!this.friends || this.friends.length === 0) {
            return;
        }

        for (const friend of this.friends) {
            try {
                const userItems = await this.shopHttpService.getUserItemsByUsername(friend.username).toPromise();

                if (userItems && userItems.length > 0) {
                    const equippedBanner = userItems.find(
                        (item: { itemId: string; equipped: boolean; purchaseDate: Date }) => item.equipped && item.itemId.startsWith('banner_'),
                    );
                    if (equippedBanner) {
                        const catalog = await this.shopHttpService.getCatalog().toPromise();
                        const bannerItem = catalog?.find((item) => item.id === equippedBanner.itemId);
                        if (bannerItem && bannerItem.imagePath) {
                            this.friendBanners.set(friend.username, bannerItem.imagePath);
                        }
                    }
                }
            } catch (error) {
                console.error(`❌ Error loading banner for ${friend.username}:`, error);
            }
        }
    }

    getFriendBanner(username: string): string | null {
        return this.friendBanners.get(username) || null;
    }

    toggleFriendsSection(): void {
        this.friendsSectionCollapsed = !this.friendsSectionCollapsed;
    }

    toggleOthersSection(): void {
        this.othersSectionCollapsed = !this.othersSectionCollapsed;
    }
}
