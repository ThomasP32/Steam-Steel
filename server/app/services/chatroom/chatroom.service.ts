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
        if (roomId && roomId.length < 50) {
            return 'channel';
        }
        return 'game';
    }

    async addMessage(roomId: string, message: IMessage): Promise<any> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType !== 'game';

        if (isPersistent && this.messageModel) {
            const created = await this.messageModel.create({ author: message.author, text: message.text, roomType, roomId });
            return created.toObject ? created.toObject() : created;
        } else {
            if (!this.roomMessages[roomId]) {
                this.roomMessages[roomId] = [];
            }
            this.roomMessages[roomId].push(message);
            return message;
        }
    }

    async getMessages(roomId: string, limit = 100): Promise<IMessage[]> {
        const roomType = this.inferRoomType(roomId);
        const isPersistent = roomType !== 'game';

        if (isPersistent && this.messageModel) {
            const docs = await this.messageModel.find({ roomType, roomId }).sort({ createdAt: -1 }).limit(limit).lean().exec();
            const docsReversed = docs.slice().reverse();
            return docsReversed.map((d: any) => ({
                id: d._id?.toString?.() ?? d._id,
                _id: d._id?.toString?.() ?? d._id,
                author: d.author,
                text: d.text,
                timestamp: d.createdAt as Date,
                roomType: d.roomType,
                roomId: d.roomId,
                gameId: d.roomType === 'game' ? d.roomId : undefined,
                channel: d.roomType === 'channel' ? d.roomId : undefined,
            }));
        }

        return this.roomMessages[roomId] || [];
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
}
