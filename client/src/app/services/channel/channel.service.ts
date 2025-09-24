import { Injectable } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { ChatEvents } from '@common/events/chat.events';
import { BehaviorSubject, firstValueFrom } from 'rxjs';

export interface Channel {
    _id?: string;
    name: string;
    creator: string;
    isPublic: boolean;
    createdAt?: Date;
}

@Injectable({
    providedIn: 'root',
})
export class ChannelService {
    private availableChannelsSubject = new BehaviorSubject<Channel[]>([]);
    private joinedChannelsSubject = new BehaviorSubject<Channel[]>([]);
    private activeChannelSubject = new BehaviorSubject<string | null>('global');

    public availableChannels$ = this.availableChannelsSubject.asObservable();
    public joinedChannels$ = this.joinedChannelsSubject.asObservable();
    public activeChannel$ = this.activeChannelSubject.asObservable();

    constructor(
        private socketService: SocketService,
        private communicationService: CommunicationMapService,
    ) {
        this.setupSocketListeners();

        this.joinedChannelsSubject.next([{ name: 'global', creator: 'system', isPublic: true }]);
        this.activeChannelSubject.next('global');

        this.loadChannels();
    }

    private setupSocketListeners(): void {
        this.socketService.listen<Channel[]>(ChatEvents.ChannelsList).subscribe((channels: Channel[]) => {
            this.updateAvailableChannels(channels);
        });

        this.socketService.listen<Channel>(ChatEvents.ChannelCreated).subscribe((channel: Channel) => {
            this.loadChannels();
        });

        this.socketService.listen<{ name: string }>(ChatEvents.ChannelDeleted).subscribe((data) => {
            this.removeChannelFromAll(data.name);
        });

        this.socketService.listen<any>('connect').subscribe(() => {
            this.loadChannels();
        });
    }

    private updateAvailableChannels(channels: Channel[]): void {
        const joined = this.joinedChannelsSubject.value;
        const joinedNames = joined.map((c) => c.name);

        const available = channels.filter((channel) => !joinedNames.includes(channel.name));
        this.availableChannelsSubject.next(available);
    }

    private removeChannelFromAll(channelName: string): void {
        const available = this.availableChannelsSubject.value.filter((c) => c.name !== channelName);
        this.availableChannelsSubject.next(available);

        const joined = this.joinedChannelsSubject.value.filter((c) => c.name !== channelName);
        this.joinedChannelsSubject.next(joined);

        if (this.activeChannelSubject.value === channelName) {
            this.setActiveChannel('global');
        }
    }

    loadChannels(): void {
        this.communicationService.basicGet<any>('channels').subscribe({
            next: (response) => {
                if (response && response.channels) {
                    this.updateAvailableChannels(response.channels);
                }
            },
            error: (error) => {
                console.error('Error loading channels:', error);
            },
        });
    }

    async createChannel(name: string, creator: string, isPublic: boolean = true): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            if (!token) {
                return { success: false, message: 'Token requis' };
            }

            const response = await firstValueFrom(
                this.communicationService.basicPost<any>(`channels?token=${token}`, {
                    name,
                    creator,
                    isPublic,
                }),
            );

            const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
            if (body && body.success) {
                this.socketService.sendMessage(ChatEvents.CreateChannel, { name, creator, isPublic });
                this.loadChannels();
                return { success: true, message: body.message };
            } else {
                return { success: false, message: body?.message || 'Erreur lors de la création du channel' };
            }
        } catch (error) {
            console.error('Error creating channel:', error);
            return { success: false, message: 'Erreur de connexion' };
        }
    }

    async deleteChannel(name: string): Promise<{ success: boolean; message?: string }> {
        try {
            const token = localStorage.getItem('authToken');
            if (!token) {
                return { success: false, message: 'Token requis' };
            }

            const response = await firstValueFrom(this.communicationService.basicDelete(`channels/${name}?token=${token}`));

            const body = typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
            if (body && body.success) {
                this.socketService.sendMessage(ChatEvents.DeleteChannel, { name });
                this.removeChannelFromAll(name);
                return { success: true, message: body.message };
            } else {
                return { success: false, message: body?.message || 'Erreur lors de la suppression du channel' };
            }
        } catch (error) {
            console.error('Error deleting channel:', error);
            return { success: false, message: 'Erreur de connexion' };
        }
    }

    joinChannel(channelName: string): void {
        const available = this.availableChannelsSubject.value;
        const channelToJoin =
            available.find((c) => c.name === channelName) ||
            (channelName === 'global' ? { name: 'global', creator: 'system', isPublic: true } : null);

        if (!channelToJoin) {
            console.error('Channel not found:', channelName);
            return;
        }

        this.socketService.sendMessage(ChatEvents.JoinChannel, { channelName });

        const newAvailable = available.filter((c) => c.name !== channelName);
        const newJoined = [...this.joinedChannelsSubject.value];

        if (!newJoined.find((c) => c.name === channelName)) {
            newJoined.push(channelToJoin);
        }

        this.availableChannelsSubject.next(newAvailable);
        this.joinedChannelsSubject.next(newJoined);

        this.setActiveChannel(channelName);
    }

    leaveChannel(channelName: string): void {
        this.socketService.sendMessage(ChatEvents.LeaveChannel, { channelName });

        const joined = this.joinedChannelsSubject.value;
        const channelToMove = joined.find((c) => c.name === channelName);

        if (channelToMove) {
            const newJoined = joined.filter((c) => c.name !== channelName);
            const newAvailable = [...this.availableChannelsSubject.value, channelToMove];

            this.joinedChannelsSubject.next(newJoined);
            this.availableChannelsSubject.next(newAvailable);
        }

        if (this.activeChannelSubject.value === channelName) {
            this.setActiveChannel('global');
        }
    }

    setActiveChannel(channelName: string): void {
        const joined = this.joinedChannelsSubject.value;
        if (joined.find((c) => c.name === channelName)) {
            this.activeChannelSubject.next(channelName);
        }
    }

    getActiveChannel(): string | null {
        return this.activeChannelSubject.value;
    }

    getJoinedChannels(): Channel[] {
        return this.joinedChannelsSubject.value;
    }

    getAvailableChannels(): Channel[] {
        return this.availableChannelsSubject.value;
    }

    createPartyChannel(gameId: string, playerName: string): void {
        const partyChannelName = `partie-${gameId}`;
        const partyChannel: Channel = {
            name: partyChannelName,
            creator: 'system',
            isPublic: false,
        };

        const currentJoined = this.joinedChannelsSubject.value;
        if (!currentJoined.find((c) => c.name === partyChannelName)) {
            const newJoined = [...currentJoined, partyChannel];
            this.joinedChannelsSubject.next(newJoined);

            this.socketService.sendMessage(ChatEvents.JoinChannel, { channelName: partyChannelName });

            this.setActiveChannel(partyChannelName);
        }
    }

    removePartyChannel(gameId: string): void {
        const partyChannelName = `partie-${gameId}`;

        const currentJoined = this.joinedChannelsSubject.value;
        const newJoined = currentJoined.filter((c) => c.name !== partyChannelName);
        this.joinedChannelsSubject.next(newJoined);

        if (this.activeChannelSubject.value === partyChannelName) {
            this.setActiveChannel('global');
        }

        this.socketService.sendMessage(ChatEvents.LeaveChannel, { channelName: partyChannelName });
    }

    isPartyChannel(channelName: string): boolean {
        return channelName.startsWith('partie-');
    }
}
