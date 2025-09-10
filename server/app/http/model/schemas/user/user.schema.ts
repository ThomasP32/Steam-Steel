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
    pseudonyme: string;

    @Prop()
    avatar: string;

    @Prop({
        default: {
            classique: { gamesPlayed: 0, gamesWon: 0 },
            ctf: { gamesPlayed: 0, gamesWon: 0 },
            avgTime: 0,
        },
        type: Object,
    })
    stats: StatsUser;
}

export const UserSchema = SchemaFactory.createForClass(User);
