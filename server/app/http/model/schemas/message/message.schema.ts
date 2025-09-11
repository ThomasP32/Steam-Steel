import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class Message extends Document {
    @Prop({ required: true })
    author: string;

    @Prop({ required: true })
    text: string;

    @Prop({ required: true, enum: ['game', 'channel', 'global'] })
    roomType: string;

    @Prop({ required: true })
    roomId: string;
}

export const MessageSchema = SchemaFactory.createForClass(Message);

// compound index to speed-up fetching messages per room
MessageSchema.index({ roomType: 1, roomId: 1, createdAt: -1 });
