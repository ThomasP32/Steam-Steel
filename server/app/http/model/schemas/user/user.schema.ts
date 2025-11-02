import { Avatar } from '@common/game';
import { FriendRequest } from '@common/user-friends';
import { StatsUser } from '@common/userStats';
import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';
@Schema()
export class User extends Document {
    @Prop({ required: true, unique: true })
    email: string;

    @Prop({ required: true })
    password: string;

    @Prop({ required: true, unique: true })
    username: string;

    @Prop()
    avatar: Avatar;

    @Prop()
    avatarCustom?: string;

    @Prop({
        default: {
            classique: { gamesPlayed: 0, gamesWon: 0 },
            ctf: { gamesPlayed: 0, gamesWon: 0 },
            avgTime: 0,
        },
        type: Object,
    })
    stats: StatsUser;

    @Prop({
        default: 'offline',
        enum: ['online', 'offline', 'ingame'],
    })
    status: string;

    @Prop({
        default: [],
        type: [String],
    })
    friends: string[];

    @Prop({
        default: [],
        type: [{ from: String, to: String, status: String }],
    })
    friendRequests: FriendRequest[];
}

export const UserSchema = SchemaFactory.createForClass(User);
