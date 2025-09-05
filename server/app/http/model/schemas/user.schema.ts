import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema()
export class User extends Document {
    @Prop({ required: true, unique: true })
    email: string;

    @Prop({ required: true })
    password: string; // hashed password

    @Prop({ required: true })
    pseudonyme: string;

    @Prop()
    avatar: string; // url ou nom de fichier
}

export const UserSchema = SchemaFactory.createForClass(User);
