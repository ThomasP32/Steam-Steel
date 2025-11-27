import { ChatEvents } from '@common/events/chat.events';
import { FriendsEvents } from '@common/events/friends.events';
import { UserStatus } from '@common/user-friends';
import { Inject } from '@nestjs/common';
import { SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';
import { FriendsService } from '../../../../http/services/friends/friends.service';
import { UserService } from '../../../../http/services/user/user.service';
import { ChatroomService } from '../../../../services/chatroom/chatroom.service';
import { GameCreationService } from '../../../../services/game-creation/game-creation.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';
@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class FriendsGateway {
    @WebSocketServer() server: Server;

    @Inject(FriendsService) private readonly friendsService: FriendsService;
    @Inject(UserService) private readonly userService: UserService;
    @Inject(ChatroomService) private readonly chatroomService: ChatroomService;
    @Inject(GameCreationService) private readonly gameCreationService: GameCreationService;
    @Inject(UserSocketService) private readonly userSocketService: UserSocketService;

    constructor() {
        setTimeout(() => {
            this.friendsService.setFriendsGateway(this);
        }, 0);
    }

    @SubscribeMessage(FriendsEvents.UpdateUserStatus)
    async handleUpdateUserStatus(client: any, data: { status: UserStatus }): Promise<void> {
        const userId = this.userSocketService.getUserIdBySocket(client.id);
        if (userId) {
            const user = await this.userService.findById(userId);
            if (user) {
                await this.friendsService.updateUserStatus(user.username, data.status);

                if (data.status === UserStatus.Online || data.status === UserStatus.Offline || data.status === UserStatus.InGame) {
                    const statusString = data.status === UserStatus.Online ? 'online' : data.status === UserStatus.Offline ? 'offline' : 'ingame';
                    const updatedCount = await this.chatroomService.updateMessageAuthorStatus(user.username, statusString);

                    if (updatedCount > 0) {
                        this.notifyMessageAuthorStatusUpdate(user.username, statusString);
                    }
                }
            }
        }
    }

    @SubscribeMessage(FriendsEvents.InviteAllOnlineFriends)
    async handleInviteAllOnlineFriends(client: any, data: { gameId: string; gameName: string }): Promise<void> {
        const userId = this.userSocketService.getUserIdBySocket(client.id);
        if (userId) {
            const user = await this.userService.findById(userId);
            if (user) {
                await this.inviteOnlineFriends(user.username, data.gameId, data.gameName);
            }
        }
    }

    @SubscribeMessage(FriendsEvents.GameInvitationAccepted)
    async handleGameInvitationAccepted(client: any, data: { gameId: string; inviterUsername: string }): Promise<void> {
        const userId = this.userSocketService.getUserIdBySocket(client.id);
        if (userId) {
            const user = await this.userService.findById(userId);
            if (user) {
                const inviter = await this.userService.findByUsername(data.inviterUsername);
                if (inviter) {
                    const inviterSocketId = this.userSocketService.getSocketId(inviter._id.toString());
                    if (inviterSocketId) {
                        this.server.to(inviterSocketId).emit(FriendsEvents.GameInvitationAccepted, {
                            username: user.username,
                            gameId: data.gameId,
                        });
                    }
                }
            }
        }
    }

    @SubscribeMessage(FriendsEvents.GameInvitationRejected)
    async handleGameInvitationRejected(client: any, data: { gameId: string; inviterUsername: string }): Promise<void> {
        const userId = this.userSocketService.getUserIdBySocket(client.id);
        if (userId) {
            const user = await this.userService.findById(userId);
            if (user) {
                const inviter = await this.userService.findByUsername(data.inviterUsername);
                if (inviter) {
                    const inviterSocketId = this.userSocketService.getSocketId(inviter._id.toString());
                    if (inviterSocketId) {
                        this.server.to(inviterSocketId).emit(FriendsEvents.GameInvitationRejected, {
                            username: user.username,
                            gameId: data.gameId,
                        });
                    }
                }
            }
        }
    }

    async notifyFriendListUpdate(username: string): Promise<void> {
        const user = await this.userService.findByUsername(username);
        if (user) {
            const socketId = this.userSocketService.getSocketId(user._id.toString());
            if (socketId) {
                const friends = await this.friendsService.getFriends(user._id.toString());
                this.server.to(socketId).emit(FriendsEvents.FriendListUpdated, { friends });
            }
        }
    }

    async notifyFriendRequestUpdate(username: string): Promise<void> {
        const user = await this.userService.findByUsername(username);
        if (user) {
            const socketId = this.userSocketService.getSocketId(user._id.toString());
            if (socketId) {
                const friendRequests = await this.friendsService.getFriendRequests(user._id.toString());
                this.server.to(socketId).emit(FriendsEvents.FriendRequestsUpdated, { friendRequests });
            }
        }
    }

    async notifyFriendsStatusUpdate(username: string, status: UserStatus): Promise<void> {
        const usersWithThisFriend = await this.userService.getUsersWithFriend(username);

        for (const user of usersWithThisFriend) {
            const socketId = this.userSocketService.getSocketId(user._id.toString());
            if (socketId) {
                const eventData = { username, status };
                this.server.to(socketId).emit(FriendsEvents.FriendStatusUpdate, eventData);
            }
        }
    }

    async inviteOnlineFriends(inviterUsername: string, gameId: string, gameName: string): Promise<void> {
        const inviter = await this.userService.findByUsername(inviterUsername);
        if (!inviter) return;

        const game = this.gameCreationService.getGameById(gameId);
        const entryFee = game?.settings?.entryFee ?? 0;

        const friends = await this.friendsService.getFriends(inviter._id.toString());

        for (const friend of friends) {
            if (friend.status === UserStatus.Online) {
                const friendUser = await this.userService.findByUsername(friend.username);
                if (friendUser) {
                    const socketId = this.userSocketService.getSocketId(friendUser._id.toString());
                    if (socketId) {
                        const invitationData = {
                            gameId,
                            gameName,
                            inviterUsername,
                            inviterName: inviter.username,
                            entryFee,
                        };
                        this.server.to(socketId).emit(FriendsEvents.GameInvitationReceived, invitationData);
                    }
                }
            }
        }
    }

    public notifyMessageAuthorStatusUpdate(username: string, status: string): void {
        this.server.emit(ChatEvents.MessageAuthorStatusUpdated, {
            username,
            status,
        });
    }

    async notifyNewUserRegistered(newUser: { username: string; level: number }): Promise<void> {
        this.server.emit(FriendsEvents.NewUserRegistered, {
            user: newUser,
        });
    }
}
