import { Message as MessageDoc } from '@app/http/model/schemas/message/message.schema';
import { Message as IMessage } from '@common/message';
import { Injectable, Optional } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';

@Injectable()
export class ChatroomService {
    private roomMessages: Record<string, IMessage[]> = {};

    constructor(@Optional() @InjectModel('Message') private readonly messageModel?: Model<MessageDoc>) {
        this.messageModel = messageModel;
    }

    private inferRoomType(roomId: string): 'game' | 'channel' | 'global' {
        if (roomId === 'global') return 'global';
        if (roomId.startsWith('channel:')) return 'channel';
        return 'game';
    }

    async addMessage(roomId: string, message: IMessage): Promise<void> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType !== 'game';

        if (isPersistent && this.messageModel) {
            // persist in DB with explicit roomType/roomId
            await this.messageModel.create({ author: message.author, text: message.text, roomType, roomId });
        } else {
            // in-memory ephemeral storage
            if (!this.roomMessages[roomId]) {
                this.roomMessages[roomId] = [];
            }
            this.roomMessages[roomId].push(message);
        }
    }

    async getMessages(roomId: string, limit = 100): Promise<IMessage[]> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType !== 'game';

        if (isPersistent && this.messageModel) {
            // load last `limit` messages from DB ordered by creation time
            const docs = await this.messageModel.find({ roomType, roomId }).sort({ createdAt: -1 }).limit(limit).lean().exec();
            // map to IMessage and reverse to chronological order
            const docsReversed = docs.slice().reverse();
            return docsReversed.map((d: any) => ({
                author: d.author,
                text: d.text,
                timestamp: d.createdAt as Date,
                roomType: d.roomType,
                roomId: d.roomId,
                // backward compatibility
                gameId: d.roomType === 'game' ? d.roomId : undefined,
                channel: d.roomType === 'channel' ? d.roomId : undefined,
            }));
        }

        return this.roomMessages[roomId] || [];
    }
}
