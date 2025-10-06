import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnDestroy, OnInit, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { Channel, ChannelService } from '@app/services/channel/channel.service';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { ChatEvents } from '@common/events/chat.events';
import { Message } from '@common/message';
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

    availableChannels: Channel[] = [];
    joinedChannels: Channel[] = [];
    activeChannel: string | null = null;
    previousChannel: string | null = null;
    showAvailableChannels: boolean = false;
    showJoinedChannels: boolean = false;
    newChannelName: string = '';
    channelSearchText: string = '';

    constructor(
        public readonly socketService: SocketService,
        private readonly channelService: ChannelService,
        private readonly authService: AuthService,
    ) {
        this.socketService = socketService;
        this.channelService = channelService;
        this.authService = authService;
    }

    ngOnInit(): void {
        this.getPlayerName();
        this.channelService.availableChannels$.subscribe((channels) => {
            this.availableChannels = channels;
        });

        this.channelService.joinedChannels$.subscribe((channels) => {
            this.joinedChannels = channels;
        });

        if (this.isInGame && this.gameId) {
            this.createAndJoinPartyChannel();
        }

        this.channelService.activeChannel$.subscribe((channel) => {
            this.previousChannel = this.activeChannel;
            this.activeChannel = channel;
            if (channel) {
                this.messages = [];
                this.loadChannelMessages(channel);
            }
        });

        if (!this.isInGame) {
            this.socketService.sendMessage(ChatEvents.JoinChatRoom, 'global');
        }

        this.messageSubscription = this.socketService.listen<Message[]>(ChatEvents.PreviousMessages).subscribe((messages: Message[]) => {
            this.messages = messages;
            this.scrollToBottom();
        });

        this.newMessageSubscription = this.socketService.listen<Message>(ChatEvents.NewMessage).subscribe((message) => {
            const messageWithTimestamp = {
                ...message,
                timestamp: message.timestamp || new Date(),
            };
            this.messages.push(messageWithTimestamp);
            this.scrollToBottom();
        });
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

    getFilteredAvailableChannels(): Channel[] {
        if (!this.channelSearchText.trim()) {
            return this.availableChannels;
        }

        const searchTerm = this.channelSearchText.toLowerCase().trim();
        return this.availableChannels.filter((channel) => channel.name.toLowerCase().includes(searchTerm));
    }

    createChannel(): void {
        if (this.newChannelName.trim() && this.playerName) {
            this.channelService.createChannel(this.newChannelName.trim(), this.playerName, true).then((result) => {
                if (!result.success && result.message) {
                    alert(result.message);
                }
            });
            this.newChannelName = '';
        }
    }

    joinChannel(channel: Channel): void {
        this.channelService.joinChannel(channel.name);
        this.showAvailableChannels = false;
    }

    leaveChannel(channelName: string): void {
        this.channelService.leaveChannel(channelName);
    }

    deleteChannel(channelName: string): void {
        if (confirm(`Êtes-vous sûr de vouloir supprimer le channel "${channelName}" ?`)) {
            this.channelService.deleteChannel(channelName).then((result) => {
                if (!result.success && result.message) {
                    alert(result.message);
                }
            });
        }
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

    toggleChat() {
        this.isChatRetracted = !this.isChatRetracted;
    }

    closeChat() {
        this.isChatRetracted = !this.isChatRetracted;
        this.closed.emit();
    }

    createAndJoinPartyChannel(): void {
        this.channelService.createPartyChannel(this.gameId);
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
    }

    private cleanupPartyChannel(): void {
        const partyChannelName = `partie-${this.gameId}`;
        this.channelService.removePartyChannel(partyChannelName);
    }
}
