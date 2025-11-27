import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, EventEmitter, Input, NgZone, OnDestroy, OnInit, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { Channel, ChannelService } from '@app/services/channel/channel.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { FriendsService } from '@app/services/friends/friends.service';
import { ProfilePictureService } from '@app/services/profile-picture/profile-picture.service';
import { ChatEvents } from '@common/events/chat.events';
import { Message } from '@common/message';
import { UserStatus } from '@common/user-friends';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-chatroom',
    standalone: true,
    imports: [FormsModule, CommonModule],
    templateUrl: './chatroom.component.html',
    styleUrl: './chatroom.component.scss',
})
export class ChatroomComponent implements OnInit, OnDestroy {
    @Input() gameId: string;
    @Input() isInGame: boolean = false;
    @Output() closed = new EventEmitter<void>();

    playerName: string = '';
    messageText: string = '';
    messages: Message[] = [];
    messageSubscription: Subscription = new Subscription();
    newMessageSubscription: Subscription = new Subscription();
    isChatRetracted: boolean = false;
    isChannelRetracted: boolean = false;

    availableChannels: Channel[] = [];
    joinedChannels: Channel[] = [];
    activeChannel: string | null = null;
    previousChannel: string | null = null;
    showAvailableChannels: boolean = false;
    showJoinedChannels: boolean = false;
    newChannelName: string = '';
    channelSearchText: string = '';

    notificationMessage: string = '';
    showNotification: boolean = false;
    channelToDelete: string = '';
    showDeleteConfirmation: boolean = false;
    showCreateModal: boolean = false;
    newChannelNameModal: string = '';

    private messagesCache: Map<string, Message[]> = new Map();

    constructor(
        public readonly socketService: SocketService,
        private readonly channelService: ChannelService,
        private readonly authService: AuthService,
        private readonly friendsService: FriendsService,
        private readonly profilePictureService: ProfilePictureService,
        private readonly cdr: ChangeDetectorRef,
        private readonly ngZone: NgZone,
    ) {
        this.socketService = socketService;
        this.channelService = channelService;
        this.authService = authService;
        this.friendsService = friendsService;
        this.profilePictureService = profilePictureService;
        this.cdr = cdr;
        this.ngZone = ngZone;
    }

    ngOnInit(): void {
        this.getPlayerName();

        this.friendsService.loadFriends();
        this.friendsService.initializeFriendsSocket();

        this.authService.authState$.subscribe((isAuthenticated) => {
            if (isAuthenticated) {
                this.getPlayerName();
            }
        });

        this.channelService.availableChannels$.subscribe((channels) => {
            this.ngZone.run(() => {
                this.availableChannels = [...channels];
                this.cdr.detectChanges();
            });
        });

        this.channelService.joinedChannels$.subscribe((channels) => {
            this.ngZone.run(() => {
                this.joinedChannels = [...channels];
                this.cdr.detectChanges();
            });
        });

        this.channelService.activeChannel$.subscribe((channel) => {
            this.previousChannel = this.activeChannel;
            this.activeChannel = channel;
            if (channel && channel !== this.previousChannel) {
                if (this.previousChannel) {
                    this.messagesCache.set(this.previousChannel, [...this.messages]);
                }

                this.messages = [];

                const cachedMessages = this.messagesCache.get(channel);
                if (cachedMessages && cachedMessages.length > 0) {
                    if (channel.startsWith('partie-')) {
                        const validPartyMessages = cachedMessages.filter(
                            (msg) => !msg.gameId || msg.gameId === this.gameId || msg.text?.includes(this.gameId),
                        );
                        if (validPartyMessages.length > 0) {
                            this.messages = [...validPartyMessages];
                        } else {
                            this.loadChannelMessages(channel);
                        }
                    } else {
                        this.messages = [...cachedMessages];
                    }
                    this.scrollToBottom();
                } else {
                    this.loadChannelMessages(channel);
                }
            }
        });

        this.messageSubscription = this.socketService.listen<Message[]>(ChatEvents.PreviousMessages).subscribe((messages: Message[]) => {
            this.messages = [...messages];
            if (this.activeChannel) {
                this.messagesCache.set(this.activeChannel, [...messages]);
            }
            this.scrollToBottom();
        });

        this.newMessageSubscription = this.socketService.listen<Message>(ChatEvents.NewMessage).subscribe((message) => {
            const messageWithTimestamp = {
                ...message,
                timestamp: message.timestamp || new Date(),
            };
            this.messages.push(messageWithTimestamp);

            if (this.activeChannel) {
                this.messagesCache.set(this.activeChannel, [...this.messages]);
            }

            this.scrollToBottom();
        });

        this.socketService.listen<{ username: string; status: string }>(ChatEvents.MessageAuthorStatusUpdated).subscribe((data) => {
            this.updateMessageAuthorStatus(data.username, data.status as 'online' | 'offline' | 'ingame');
        });

        if (this.isInGame && this.gameId) {
            setTimeout(() => {
                this.createAndJoinPartyChannel();
            }, 100);
        } else {
            setTimeout(() => {
                if (!this.activeChannel) {
                    this.channelService.setActiveChannel('global');
                }
            }, 100);
        }
    }

    sendMessage(): void {
        if (this.messageText.trim().length > 0 && this.messageText.trim().length <= 200) {
            const roomName = this.activeChannel || 'global';
            const message: Message = {
                author: this.playerName,
                text: this.messageText,
                timestamp: new Date(),
                gameId: this.gameId,
            };
            this.socketService.sendMessage(ChatEvents.Message, { roomName, message });
            this.messageText = '';
            this.scrollToBottom();
        }
    }

    async getPlayerName(): Promise<void> {
        try {
            const info = await this.authService.getUserInfo();
            this.playerName = info?.user?.username || 'User';
        } catch {
            this.playerName = 'User';
        }
    }

    loadChannelMessages(channelName: string): void {
        if (this.previousChannel && this.previousChannel !== channelName) {
            this.socketService.sendMessage(ChatEvents.LeaveChannel, { channelName: this.previousChannel });
        }

        this.messages = [];
        this.socketService.sendMessage(ChatEvents.JoinChatRoom, channelName);
    }

    toggleAvailableChannels(): void {
        this.showAvailableChannels = !this.showAvailableChannels;
        if (this.showAvailableChannels) {
            this.showJoinedChannels = false;
        }
    }

    toggleJoinedChannels(): void {
        this.showJoinedChannels = !this.showJoinedChannels;
        if (this.showJoinedChannels) {
            this.showAvailableChannels = false;
        }
    }

    toggleChannel(): void {
        this.isChannelRetracted = !this.isChannelRetracted;
    }

    getFilteredAvailableChannels(): Channel[] {
        if (!this.channelSearchText.trim()) {
            return this.availableChannels;
        }

        const searchTerm = this.channelSearchText.toLowerCase().trim();
        return this.availableChannels.filter((channel) => channel.name.toLowerCase().includes(searchTerm));
    }

    createChannel(): void {
        if (this.channelSearchText.trim() && this.playerName) {
            this.channelService.createChannel(this.channelSearchText.trim(), this.playerName, true).then((result) => {
                if (!result.success && result.message) {
                    this.showNotificationMessage(result.message);
                } else {
                    this.toggleAvailableChannels();
                }
            });
            this.channelSearchText = '';
        }
    }

    toggleCreateModal(): void {
        this.showCreateModal = !this.showCreateModal;
        if (!this.showCreateModal) {
            this.newChannelNameModal = '';
        }
    }

    createChannelFromModal(): void {
        const name = this.newChannelNameModal.trim();
        if (!name || !this.playerName) return;

        if (name.length < 3 || name.length > 20) {
            this.showNotificationMessage('Le nom du salon doit contenir entre 3 et 20 caractères');
            return;
        }

        this.channelService.createChannel(name, this.playerName, true).then((result) => {
            if (!result.success && result.message) {
                this.showNotificationMessage(result.message);
            } else {
                this.toggleCreateModal();
                this.showNotificationMessage('Salon créé avec succès!');
            }
        });
    }

    joinChannel(channel: Channel): void {
        this.channelService.joinChannel(channel.name);
        this.showAvailableChannels = false;
    }

    leaveChannel(channelName: string): void {
        this.channelService.leaveChannel(channelName);
        this.messagesCache.delete(channelName);
    }

    deleteChannel(channelName: string): void {
        this.channelToDelete = channelName;
        this.notificationMessage = `Supprimer le salon "${channelName}" ?`;
        this.showDeleteConfirmation = true;

        setTimeout(() => {
            this.showDeleteConfirmation = false;
        }, 5000);
    }

    confirmDeleteChannel(): void {
        if (this.channelToDelete) {
            this.channelService.deleteChannel(this.channelToDelete).then((result) => {
                if (!result.success && result.message) {
                    this.showNotificationMessage(result.message);
                }
            });
            this.cancelDeleteChannel();
        }
    }

    cancelDeleteChannel(): void {
        this.channelToDelete = '';
        this.showDeleteConfirmation = false;
    }

    selectActiveChannel(channelName: string): void {
        this.channelService.setActiveChannel(channelName);
        this.showJoinedChannels = false;
    }

    scrollToBottom(): void {
        setTimeout(() => {
            const messageArea = document.getElementById('messageArea');
            if (messageArea) {
                messageArea.scrollTop = messageArea.scrollHeight;
            }
        }, 5);
    }

    private showNotificationMessage(message: string): void {
        this.notificationMessage = message;
        this.showNotification = true;

        setTimeout(() => {
            this.showNotification = false;
        }, 3000);
    }

    toggleChat() {
        this.isChatRetracted = !this.isChatRetracted;
    }

    closeChat() {
        this.isChatRetracted = !this.isChatRetracted;
        this.closed.emit();
    }

    createAndJoinPartyChannel(): void {
        const partyChannelName = `partie-${this.gameId}`;

        const existingChannel = this.joinedChannels.find((channel) => channel.name === partyChannelName);

        if (!existingChannel) {
            this.channelService.createPartyChannel(this.gameId);

            this.messagesCache.clear();
            this.messages = [];
        }
    }

    ngOnDestroy(): void {
        if (this.isInGame && this.gameId) {
            this.cleanupPartyChannel();
        }

        if (this.messageSubscription) {
            this.messageSubscription.unsubscribe();
        }
        if (this.newMessageSubscription) {
            this.newMessageSubscription.unsubscribe();
        }

        this.messagesCache.clear();
    }

    private cleanupPartyChannel(): void {
        this.channelService.removePartyChannel(this.gameId);
    }

    getMessageAuthorImageUrl(message: Message): string | null {
        // Priorité aux photos de profil
        if (message.authorProfilePictureCustom) {
            return message.authorProfilePictureCustom;
        }
        if (message.authorProfilePicture) {
            const profilePictureData = this.profilePictureService.getAllProfilePictureData().find((p) => p.id === message.authorProfilePicture);
            return profilePictureData ? profilePictureData.image : null;
        }

        // Fallback vers les avatars
        if (message.authorAvatarCustom) {
            return message.authorAvatarCustom;
        }
        if (message.authorAvatar) {
            return `assets/characters/${message.authorAvatar}.png`;
        }

        return null;
    }

    isAuthorFriend(username: string): boolean {
        const friends = this.friendsService.getFriends();
        return friends.some((friend) => friend.username === username);
    }

    getStatusText(status: string): string {
        switch (status) {
            case UserStatus.Online:
                return 'En ligne';
            case UserStatus.Offline:
                return 'Hors ligne';
            case UserStatus.InGame:
                return 'En jeu';
            default:
                return 'Inconnu';
        }
    }

    updateMessageAuthorStatus(username: string, status: 'online' | 'offline' | 'ingame'): void {
        let updated = false;
        this.messages.forEach((message) => {
            if (message.author === username) {
                message.authorStatus = status;
                updated = true;
            }
        });

        if (updated) {
            if (this.activeChannel) {
                this.messagesCache.set(this.activeChannel, [...this.messages]);
            }

            this.messagesCache.forEach((messages, channelName) => {
                let cacheUpdated = false;
                messages.forEach((message) => {
                    if (message.author === username) {
                        message.authorStatus = status;
                        cacheUpdated = true;
                    }
                });
                if (cacheUpdated) {
                    this.messagesCache.set(channelName, [...messages]);
                }
            });
        }
    }

    isDeletedAccount(author: string): boolean {
        return author === '[supprimé]';
    }
}
