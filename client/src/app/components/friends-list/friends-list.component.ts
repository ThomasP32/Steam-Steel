import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CharacterService } from '@app/services/character/character.service';
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
    newFriendUsername: string = '';
    isAddingFriend: boolean = false;
    friendError: string = '';
    activeTab: 'friends' | 'requests' = 'friends';

    private readonly unsubscribe$ = new Subject<void>();

    constructor(
        private readonly friendsService: FriendsService,
        private readonly characterService: CharacterService,
    ) {
        this.friendsService = friendsService;
        this.characterService = characterService;
    }

    ngOnInit(): void {
        this.loadFriends();
        this.loadFriendRequests();

        this.friendsService.friends$.pipe(takeUntil(this.unsubscribe$)).subscribe((friends) => {
            this.friends = friends;
        });

        this.friendsService.friendRequests$.pipe(takeUntil(this.unsubscribe$)).subscribe((friendRequests) => {
            this.friendRequests = friendRequests;
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

    async addFriend(): Promise<void> {
        if (!this.newFriendUsername.trim()) {
            this.friendError = "Veuillez entrer un nom d'utilisateur";
            return;
        }

        this.isAddingFriend = true;
        this.friendError = '';

        const result = await this.friendsService.addFriend(this.newFriendUsername.trim());

        if (result.success) {
            this.newFriendUsername = '';
            this.friendError = "La demande d'ami a été envoyée avec succès";
        } else {
            this.friendError = result.message || "Erreur lors de l'envoi de la demande d'ami";
        }

        this.isAddingFriend = false;
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

    getStatusText(status: UserStatus): string {
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

    getStatusClass(status: UserStatus): string {
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

    onKeyPress(event: KeyboardEvent): void {
        if (event.key === 'Enter') {
            this.addFriend();
        }
    }

    switchTab(tab: 'friends' | 'requests'): void {
        this.activeTab = tab;
        if (tab === 'requests') {
            this.loadFriendRequests();
        } else if (tab === 'friends') {
            this.loadFriends();
            this.friendError = '';
        }
    }

    getFriendRequestsCount(): number {
        return this.friendRequests.length;
    }

    getFriendAvatarUrl(friend: Friend): string {
        if (friend.avatarCustom) {
            return friend.avatarCustom;
        }

        if (friend.avatar) {
            const avatarId = typeof friend.avatar === 'string' ? parseInt(friend.avatar, 10) : friend.avatar;
            if (avatarId && Object.values(Avatar).includes(avatarId as Avatar)) {
                return this.characterService.getAvatarPreview(avatarId as Avatar);
            }
        }

        return '';
    }
}
