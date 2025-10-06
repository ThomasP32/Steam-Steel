import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ timestamps: true })
export class Channel extends Document {
    @Prop({ required: true, unique: true })
    name: string;

    @Prop({ required: true })
    creator: string;

    @Prop({ default: true })
    isPublic: boolean;
}

export const ChannelSchema = SchemaFactory.createForClass(Channel);