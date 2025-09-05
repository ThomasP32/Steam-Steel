import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User } from '../model/schemas/user.schema';

@Injectable()
export class UserService {
    constructor(@InjectModel(User.name) private userModel: Model<User>) {}

    async create(email: string, password: string, pseudonyme: string, avatar?: string): Promise<User> {
        const user = new this.userModel({ email, password, pseudonyme, avatar });
        return user.save();
    }

    async findByEmail(email: string): Promise<User | null> {
        return this.userModel.findOne({ email }).exec();
    }

    async validateUser(email: string, password: string): Promise<User | null> {
        const user = await this.findByEmail(email);
        if (user && user.password === password) {
            return user;
        }
        return null;
    }

    async findByPseudonyme(pseudonyme: string): Promise<User | null> {
        return this.userModel.findOne({ pseudonyme }).exec();
    }
}
