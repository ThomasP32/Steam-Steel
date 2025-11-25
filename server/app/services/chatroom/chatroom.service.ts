import { Message as MessageDoc } from '@app/http/model/schemas/message/message.schema';
import { UserService } from '@app/http/services/user/user.service';
import { Message as IMessage } from '@common/message';
import { Injectable, Optional } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';

@Injectable()
export class ChatroomService {
    private roomMessages: Record<string, IMessage[]> = {};

    constructor(
        @Optional() @InjectModel('Message') private readonly messageModel?: Model<MessageDoc>,
        @Optional() private readonly userService?: UserService,
    ) {
        this.messageModel = messageModel;
        this.userService = userService;
    }

    private inferRoomType(roomId: string): 'game' | 'channel' | 'global' | 'party' {
        if (roomId === 'global') return 'global';
        if (roomId.startsWith('partie-')) return 'party';
        if (roomId && roomId.length < 50) {
            return 'channel';
        }
        return 'game';
    }

    async addMessage(roomId: string, message: IMessage): Promise<any> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType === 'global' || roomType === 'channel';

        let enrichedMessage = { ...message };
        if (this.userService) {
            try {
                const user = await this.userService.findByUsername(message.author);
                if (user) {
                    enrichedMessage.authorProfilePicture = user.profilePicture;
                    enrichedMessage.authorProfilePictureCustom = user.profilePictureCustom;
                    if (user.status === 'online' || user.status === 'offline' || user.status === 'ingame') {
                        enrichedMessage.authorStatus = user.status as 'online' | 'offline' | 'ingame';
                    }
                }
            } catch (error) {
                console.warn(`Could not get user info for ${message.author}:`, error);
            }
        }

        if (isPersistent && this.messageModel) {
            const created = await this.messageModel.create({
                author: enrichedMessage.author,
                text: enrichedMessage.text,
                roomType,
                roomId,
                authorProfilePicture: enrichedMessage.authorProfilePicture,
                authorProfilePictureCustom: enrichedMessage.authorProfilePictureCustom,
                authorStatus: enrichedMessage.authorStatus,
            });
            return created.toObject ? created.toObject() : created;
        } else {
            if (!this.roomMessages[roomId]) {
                this.roomMessages[roomId] = [];
            }
            this.roomMessages[roomId].push(enrichedMessage);
            return enrichedMessage;
        }
    }

    async getMessages(roomId: string, limit = 100): Promise<IMessage[]> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType === 'global' || roomType === 'channel';

        if (isPersistent && this.messageModel) {
            const docs = await this.messageModel.find({ roomId }).limit(limit).sort({ createdAt: 1 }).exec();
            return docs.map((doc) => ({
                author: doc.author,
                text: doc.text,
                timestamp: (doc as any).createdAt || new Date(),
                authorAvatar: (doc as any).authorAvatar,
                authorAvatarCustom: (doc as any).authorAvatarCustom,
                authorProfilePicture: (doc as any).authorProfilePicture,
                authorProfilePictureCustom: (doc as any).authorProfilePictureCustom,
                authorStatus: (doc as any).authorStatus,
            }));
        } else {
            const messages = this.roomMessages[roomId] || [];
            return messages;
        }
    }

    async deleteMessage(payload: { messageId?: string; author?: string; text?: string; timestamp?: string }): Promise<boolean> {
        if (!this.messageModel) return false;

        try {
            if (payload.messageId) {
                const res = await this.messageModel.deleteOne({ _id: payload.messageId }).exec();
                return (res.deletedCount ?? 0) > 0;
            }

            let tsQuery: any = undefined;
            if (payload.timestamp) {
                const parsed = new Date(payload.timestamp);
                if (!isNaN(parsed.getTime())) {
                    const before = new Date(parsed.getTime() - 2000);
                    const after = new Date(parsed.getTime() + 2000);
                    tsQuery = { $gte: before, $lte: after };
                }
            }

            const query: any = {};
            if (payload.author) query.author = payload.author;
            if (payload.text) query.text = payload.text;
            if (tsQuery) query.createdAt = tsQuery;

            if (Object.keys(query).length === 0) return false;

            const res = await this.messageModel.deleteOne(query).exec();
            return (res.deletedCount ?? 0) > 0;
        } catch (e) {
            return false;
        }
    }

    async updateMessageAuthor(oldUsername: string, newUsername: string): Promise<number> {
        if (!this.messageModel) return 0;

        try {
            const result = await this.messageModel.updateMany({ author: oldUsername }, { author: newUsername }).exec();

            let updatedInMemory = 0;
            for (const roomId in this.roomMessages) {
                const messages = this.roomMessages[roomId];
                for (const message of messages) {
                    if (message.author === oldUsername) {
                        message.author = newUsername;
                        updatedInMemory++;
                    }
                }
            }

            return (result.modifiedCount || 0) + updatedInMemory;
        } catch (error) {
            console.error('Error updating message author:', error);
            return 0;
        }
    }

    async updateMessageAuthorStatus(username: string, status: 'online' | 'offline' | 'ingame'): Promise<number> {
        if (!this.messageModel) return 0;

        try {
            const result = await this.messageModel.updateMany({ author: username }, { authorStatus: status }).exec();

            let updatedInMemory = 0;
            for (const roomId in this.roomMessages) {
                const messages = this.roomMessages[roomId];
                for (const message of messages) {
                    if (message.author === username) {
                        message.authorStatus = status;
                        updatedInMemory++;
                    }
                }
            }

            return (result.modifiedCount || 0) + updatedInMemory;
        } catch (error) {
            console.error('Error updating message author status:', error);
            return 0;
        }
    }

    async updateMessageAuthorAvatar(username: string, avatar?: any, avatarCustom?: string): Promise<number> {
        if (!this.messageModel) return 0;

        try {
            const updateFields: any = {};
            if (avatar !== undefined) updateFields.authorAvatar = avatar;
            if (avatarCustom !== undefined) updateFields.authorAvatarCustom = avatarCustom;

            const result = await this.messageModel.updateMany({ author: username }, updateFields).exec();

            let updatedInMemory = 0;
            for (const roomId in this.roomMessages) {
                const messages = this.roomMessages[roomId];
                for (const message of messages) {
                    if (message.author === username) {
                        if (avatar !== undefined) message.authorAvatar = avatar;
                        if (avatarCustom !== undefined) message.authorAvatarCustom = avatarCustom;
                        updatedInMemory++;
                    }
                }
            }

            return (result.modifiedCount || 0) + updatedInMemory;
        } catch (error) {
            console.error('Error updating message author avatar:', error);
            return 0;
        }
    }

    async updateMessageAuthorProfilePicture(username: string, profilePicture?: any, profilePictureCustom?: string): Promise<number> {
        if (!this.messageModel) return 0;

        try {
            const updateFields: any = {};
            if (profilePicture !== undefined) updateFields.authorProfilePicture = profilePicture;
            if (profilePictureCustom !== undefined) updateFields.authorProfilePictureCustom = profilePictureCustom;

            const result = await this.messageModel.updateMany({ author: username }, updateFields).exec();

            let updatedInMemory = 0;
            for (const roomId in this.roomMessages) {
                const messages = this.roomMessages[roomId];
                for (const message of messages) {
                    if (message.author === username) {
                        if (profilePicture !== undefined) message.authorProfilePicture = profilePicture;
                        if (profilePictureCustom !== undefined) message.authorProfilePictureCustom = profilePictureCustom;
                        updatedInMemory++;
                    }
                }
            }

            return (result.modifiedCount || 0) + updatedInMemory;
        } catch (error) {
            console.error('Error updating message author profile picture:', error);
            return 0;
        }
    }

    cleanupPartyMessages(gameId: string): void {
        const partyRoomId = `partie-${gameId}`;
        if (this.roomMessages[partyRoomId]) {
            delete this.roomMessages[partyRoomId];
        }
    }
}
