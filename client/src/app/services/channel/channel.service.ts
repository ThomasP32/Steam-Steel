import { Injectable, OnDestroy } from '@angular/core';
import { SocketService } from '@app/services/communication-socket/communication-socket.service';
import { CommunicationMapService } from '@app/services/communication/communication.map.service';
import { ChatEvents } from '@common/events/chat.events';
import { BehaviorSubject, firstValueFrom, Subscription } from 'rxjs';

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
export class ChannelService implements OnDestroy {
    private availableChannelsSubject = new BehaviorSubject<Channel[]>([]);
    private joinedChannelsSubject = new BehaviorSubject<Channel[]>([]);
    private activeChannelSubject = new BehaviorSubject<string | null>(null);

    public availableChannels$ = this.availableChannelsSubject.asObservable();
    public joinedChannels$ = this.joinedChannelsSubject.asObservable();
    public activeChannel$ = this.activeChannelSubject.asObservable();

    private subscriptions: Subscription[] = [];
    private channelListenersSub: Subscription[] = [];
    private setupRetryInterval: any = null;

    constructor(
        private socketService: SocketService,
        private communicationService: CommunicationMapService,
    ) {
        this.joinedChannelsSubject.next([{ name: 'global', creator: 'system', isPublic: true }]);
        this.activeChannelSubject.next('global');
        this.socketService = socketService;
        this.communicationService = communicationService;
        this.setupSocketListeners();
        this.loadChannels();
    }

    ngOnDestroy(): void {
        this.cleanupSubscriptions();
        if (this.setupRetryInterval) {
            clearInterval(this.setupRetryInterval);
        }
    }

    private cleanupSubscriptions(): void {
        this.subscriptions.forEach((sub) => sub.unsubscribe());
        this.subscriptions = [];
        this.channelListenersSub.forEach((sub) => sub.unsubscribe());
        this.channelListenersSub = [];
    }

    private setupSocketListeners(): void {
        if (!this.socketService.socket) {
            if (!this.setupRetryInterval) {
                this.setupRetryInterval = setInterval(() => {
                    if (this.socketService.socket) {
                        clearInterval(this.setupRetryInterval);
                        this.setupRetryInterval = null;
                        this.setupChannelListeners();
                    }
                }, 500);
            }
            return;
        }

        this.setupChannelListeners();
    }

    private setupChannelListeners(): void {
        this.channelListenersSub.forEach((sub) => sub.unsubscribe());
        this.channelListenersSub = [];

        if (!this.socketService.socket) {
            console.log('[ChannelService] Socket not available, will retry...');
            return;
        }

        console.log('[ChannelService] Setting up channel listeners...');

        this.channelListenersSub.push(
            this.socketService.listen<any>('connect').subscribe(() => {
                console.log('[ChannelService] Socket connected, loading channels...');
                this.loadChannels();
            }),
        );

        this.channelListenersSub.push(
            this.socketService.listen<Channel[]>(ChatEvents.ChannelsList).subscribe((channels: Channel[]) => {
                console.log('[ChannelService] ChannelsList received:', channels?.length);
                this.updateAvailableChannels(channels);
            }),
        );

        this.channelListenersSub.push(
            this.socketService.listen<Channel>(ChatEvents.ChannelCreated).subscribe((channel: Channel) => {
                console.log('[ChannelService] ChannelCreated received:', channel);
                if (channel && channel.name) {
                    const currentAvailable = this.availableChannelsSubject.value;
                    const joined = this.joinedChannelsSubject.value;

                    const alreadyExists = currentAvailable.some((c) => c.name === channel.name) || joined.some((c) => c.name === channel.name);

                    if (!alreadyExists) {
                        const newList = [channel, ...currentAvailable];
                        console.log(
                            '[ChannelService] Adding channel, new list:',
                            newList.map((c) => c.name),
                        );
                        this.availableChannelsSubject.next(newList);
                    } else {
                        console.log('[ChannelService] Channel already exists:', channel.name);
                    }
                }
            }),
        );

        this.channelListenersSub.push(
            this.socketService.listen<{ name: string }>(ChatEvents.ChannelDeleted).subscribe((data) => {
                console.log('[ChannelService] ChannelDeleted received:', data);
                if (data && data.name) {
                    this.removeChannelFromAll(data.name);
                }
            }),
        );

        console.log('[ChannelService] Channel listeners setup complete');
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
            if (!channelName.startsWith('partie-')) {
                this.setActiveChannel('global');
            } else {
                this.clearActiveChannel();
            }
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
                console.error('[ChannelService] Error loading channels:', error);
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

                const newChannel: Channel = { name, creator, isPublic };
                const currentAvailable = this.availableChannelsSubject.value;
                if (!currentAvailable.find((c) => c.name === name)) {
                    this.availableChannelsSubject.next([newChannel, ...currentAvailable]);
                }

                this.joinChannel(name);

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
        this.joinChannelWithoutActivation(channelName);
        this.setActiveChannel(channelName);
    }

    private joinChannelWithoutActivation(channelName: string): void {
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
            if (!channelName.startsWith('partie-')) {
                this.setActiveChannel('global');
            } else {
                this.clearActiveChannel();
            }
        }
    }

    setActiveChannel(channelName: string): void {
        const joined = this.joinedChannelsSubject.value;
        if (joined.find((c) => c.name === channelName)) {
            this.activeChannelSubject.next(channelName);
        }
    }

    clearActiveChannel(): void {
        this.activeChannelSubject.next(null);
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

    createPartyChannel(gameId: string): void {
        const partyChannelName = `partie-${gameId}`;
        const partyChannel: Channel = {
            name: partyChannelName,
            creator: 'system',
            isPublic: false,
        };

        const currentAvailable = this.availableChannelsSubject.value;
        if (!currentAvailable.find((c) => c.name === partyChannelName)) {
            const newAvailable = [...currentAvailable, partyChannel];
            this.availableChannelsSubject.next(newAvailable);

            this.joinChannelWithoutActivation(partyChannelName);
        }
    }

    removePartyChannel(gameId: string): void {
        const partyChannelName = `partie-${gameId}`;

        this.leaveChannel(partyChannelName);

        const currentAvailable = this.availableChannelsSubject.value;
        const newAvailable = currentAvailable.filter((c) => c.name !== partyChannelName);
        this.availableChannelsSubject.next(newAvailable);
    }

    resetChannelState(): void {
        console.log('[ChannelService] Resetting channel state...');
        this.availableChannelsSubject.next([]);
        this.joinedChannelsSubject.next([{ name: 'global', creator: 'system', isPublic: true }]);
        this.activeChannelSubject.next('global');

        // Re-setup socket listeners after socket reconnection
        setTimeout(() => {
            this.setupSocketListeners();
            this.loadChannels();
        }, 200);
    }
}
