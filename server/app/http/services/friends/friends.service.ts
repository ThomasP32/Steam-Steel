import { Friend, FriendRequest, FriendRequestStatus, UserStatus } from '@common/user-friends';
import { Inject, Injectable, forwardRef } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ChatroomService } from '../../../services/chatroom/chatroom.service';
import { User } from '../../model/schemas/user/user.schema';

@Injectable()
export class FriendsService {
    private friendsGateway: any;

    constructor(
        @InjectModel(User.name) private userModel: Model<User>,
        @Inject(forwardRef(() => ChatroomService)) private chatroomService: ChatroomService,
    ) {
        this.userModel = userModel;
        this.chatroomService = chatroomService;
    }

    setFriendsGateway(friendsGateway: any) {
        this.friendsGateway = friendsGateway;
    }

    private async getUsers(fromUserId: string, toUsername: string) {
        const fromUser = await this.userModel.findById(fromUserId);
        const toUser = await this.userModel.findOne({ username: toUsername });

        if (!fromUser) throw new Error('Utilisateur non trouvé');
        if (!toUser) throw new Error('Utilisateur destinataire non trouvé');
        if (fromUser.username === toUsername) throw new Error('Vous ne pouvez pas vous ajouter vous-même');

        return { fromUser, toUser };
    }

    private areAlreadyFriends(user: User, friendUserId: string): boolean {
        return user.friends.includes(friendUserId);
    }

    private hasPendingRequest(user: User, fromUsername: string): boolean {
        return user.friendRequests.some((request) => request.from === fromUsername && request.status === FriendRequestStatus.Pending);
    }

    private cleanOldRequests(user: User, otherUsername: string) {
        user.friendRequests = user.friendRequests.filter(
            (request) =>
                !(
                    request.from === otherUsername &&
                    (request.status === FriendRequestStatus.Rejected || request.status === FriendRequestStatus.Accepted)
                ),
        );
    }

    private async getFriendInfo(userId: string): Promise<Friend | null> {
        const user = await this.userModel.findById(userId);
        if (!user) return null;

        return {
            username: user.username,
            status: user.status as UserStatus,
            avatar: user.avatar,
            avatarCustom: user.avatarCustom,
            profilePicture: user.profilePicture,
            profilePictureCustom: user.profilePictureCustom,
        };
    }

    async sendFriendRequest(fromUserId: string, toUsername: string): Promise<{ success: boolean; message?: string }> {
        try {
            const { fromUser, toUser } = await this.getUsers(fromUserId, toUsername);

            if (this.areAlreadyFriends(fromUser, toUser._id.toString())) {
                return { success: false, message: 'Cet utilisateur est déjà votre ami' };
            }

            if (this.hasPendingRequest(toUser, fromUser.username)) {
                return { success: false, message: "Une demande d'amitié est déjà en cours" };
            }

            if (this.hasPendingRequest(fromUser, toUsername)) {
                return { success: false, message: "Cet utilisateur vous a déjà envoyé une demande d'amitié" };
            }

            this.cleanOldRequests(toUser, fromUser.username);
            this.cleanOldRequests(fromUser, toUsername);

            const friendRequest: FriendRequest = {
                from: fromUser.username,
                to: toUsername,
                status: FriendRequestStatus.Pending,
            };

            toUser.friendRequests.push(friendRequest);

            await Promise.all([toUser.save(), fromUser.save()]);

            if (this.friendsGateway) {
                await this.friendsGateway.notifyFriendRequestUpdate(toUsername);
            }

            return { success: true, message: "Demande d'amitié envoyée" };
        } catch (error) {
            return { success: false, message: error.message };
        }
    }

    async acceptFriendRequest(userId: string, fromUsername: string): Promise<{ success: boolean; message?: string }> {
        try {
            const user = await this.userModel.findById(userId);
            const fromUser = await this.userModel.findOne({ username: fromUsername });

            if (!user || !fromUser) {
                return { success: false, message: 'Utilisateur non trouvé' };
            }

            const requestIndex = user.friendRequests.findIndex(
                (request) => request.from === fromUsername && request.status === FriendRequestStatus.Pending,
            );

            if (requestIndex === -1) {
                return { success: false, message: "Demande d'amitié non trouvée" };
            }

            user.friendRequests[requestIndex].status = FriendRequestStatus.Accepted;

            user.friends.push(fromUser._id.toString());
            fromUser.friends.push(user._id.toString());

            await Promise.all([user.save(), fromUser.save()]);

            if (this.friendsGateway) {
                await Promise.all([
                    this.friendsGateway.notifyFriendListUpdate(fromUsername),
                    this.friendsGateway.notifyFriendListUpdate(user.username),
                    this.friendsGateway.notifyFriendRequestUpdate(user.username),
                ]);
            }

            return { success: true, message: "Demande d'amitié acceptée" };
        } catch (error) {
            return { success: false, message: "Erreur lors de l'acceptation de la demande" };
        }
    }

    async rejectFriendRequest(userId: string, fromUsername: string): Promise<{ success: boolean; message?: string }> {
        try {
            const user = await this.userModel.findById(userId);
            if (!user) {
                return { success: false, message: 'Utilisateur non trouvé' };
            }

            const requestIndex = user.friendRequests.findIndex(
                (request) => request.from === fromUsername && request.status === FriendRequestStatus.Pending,
            );

            if (requestIndex === -1) {
                return { success: false, message: "Demande d'amitié non trouvée" };
            }

            user.friendRequests[requestIndex].status = FriendRequestStatus.Rejected;
            await user.save();

            if (this.friendsGateway) {
                await this.friendsGateway.notifyFriendRequestUpdate(user.username);
            }

            return { success: true, message: "Demande d'amitié refusée" };
        } catch (error) {
            return { success: false, message: 'Erreur lors du rejet de la demande' };
        }
    }

    async removeFriend(userId: string, friendUsername: string): Promise<User | null> {
        try {
            const user = await this.userModel.findById(userId);
            const friendUser = await this.userModel.findOne({ username: friendUsername });

            if (!user) return null;

            if (friendUser) {
                user.friends = user.friends.filter((friendId) => friendId !== friendUser._id.toString());
                friendUser.friends = friendUser.friends.filter((friendId) => friendId !== user._id.toString());

                await friendUser.save();

                if (this.friendsGateway) {
                    await Promise.all([
                        this.friendsGateway.notifyFriendListUpdate(friendUsername),
                        this.friendsGateway.notifyFriendListUpdate(user.username),
                    ]);
                }
            }

            return await user.save();
        } catch (error) {
            console.error('Error removing friend:', error);
            return null;
        }
    }

    async updateUserStatus(username: string, status: UserStatus): Promise<void> {
        const user = await this.userModel.findOne({ username });
        if (user && user.status !== status) {
            user.status = status;
            await user.save();

            if (this.chatroomService) {
                try {
                    const statusString = status === UserStatus.Online ? 'online' : status === UserStatus.Offline ? 'offline' : 'ingame';
                    const updatedCount = await this.chatroomService.updateMessageAuthorStatus(username, statusString);

                    if (updatedCount > 0 && this.friendsGateway) {
                        this.friendsGateway.notifyMessageAuthorStatusUpdate(username, statusString);
                    }
                } catch (error) {
                    console.error('Error updating message author status:', error);
                }
            }
        }

        if (this.friendsGateway) {
            this.friendsGateway.notifyFriendsStatusUpdate(username, status);
        }
    }

    async getFriends(userId: string): Promise<Friend[]> {
        const user = await this.userModel.findById(userId);
        if (!user) return [];

        const friends: Friend[] = [];
        for (const friendId of user.friends) {
            const friendInfo = await this.getFriendInfo(friendId);
            if (friendInfo) {
                friends.push(friendInfo);
            }
        }

        return friends;
    }

    async getFriendRequests(userId: string): Promise<FriendRequest[]> {
        const user = await this.userModel.findById(userId);
        return user?.friendRequests.filter((request) => request.status === FriendRequestStatus.Pending) || [];
    }

    async removeUserFromAllFriendLists(username: string): Promise<void> {
        try {
            const userToDelete = await this.userModel.findOne({ username });
            if (!userToDelete) return;

            const userIdToDelete = userToDelete._id.toString();

            await this.userModel.updateMany({ friends: userIdToDelete }, { $pull: { friends: userIdToDelete } });

            await this.userModel.updateMany({ 'friendRequests.from': username }, { $pull: { friendRequests: { from: username } } });

            await this.userModel.updateMany({ 'friendRequests.to': username }, { $pull: { friendRequests: { to: username } } });

            if (this.friendsGateway) {
                const usersWithDeletedFriend = await this.userModel.find({});

                for (const user of usersWithDeletedFriend) {
                    const hadAsFriend = user.friends.some((friendId) => friendId === userIdToDelete);
                    const hadRequests = user.friendRequests.some((req) => req.from === username || req.to === username);

                    if (hadAsFriend || hadRequests) {
                        await this.friendsGateway.notifyFriendListUpdate(user.username);
                        await this.friendsGateway.notifyFriendRequestUpdate(user.username);
                    }
                }
            }
        } catch (error) {
            console.error('Error removing user from friend lists:', error);
        }
    }
}
