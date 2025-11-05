import { Channel } from '@app/http/model/schemas/channel/channel.schema';
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';

@Injectable()
export class ChannelService {
    constructor(@InjectModel('Channel') private readonly channelModel: Model<Channel>) {
        this.channelModel = channelModel;
    }

    async createChannel(name: string, creator: string, isPublic: boolean = true) {
        if (!name || name.trim().length === 0) {
            throw new Error('Le nom du channel ne peut pas être vide');
        }

        if (name.includes(' ')) {
            throw new Error("Le nom du channel ne peut pas contenir d'espaces");
        }

        const whitespaceRe = /\s/;
        if (whitespaceRe.test(name)) {
            throw new Error("Le nom du channel ne peut pas contenir d'espaces");
        }

        if (name.length > 20) {
            throw new Error('Le nom du channel ne peut pas dépasser 20 caractères');
        }

        if (!/^[a-zA-Z0-9_-]+$/.test(name)) {
            throw new Error('Le nom du channel ne peut contenir que des lettres, chiffres, tirets et underscores');
        }

        const existing = await this.channelModel.findOne({ name });
        if (existing) {
            throw new Error('Un channel avec ce nom existe déjà');
        }

        const newChannel = await this.channelModel.create({ name, creator, isPublic });
        return newChannel;
    }

    async listChannels() {
        const globalChannel = await this.channelModel.findOne({ name: 'global' });
        if (!globalChannel) {
            await this.channelModel.create({ name: 'global', creator: 'system', isPublic: true });
        }

        const channels = await this.channelModel.find().sort({ createdAt: -1 }).lean().exec();

        const globalIndex = channels.findIndex((channel) => channel.name === 'global');
        if (globalIndex > 0) {
            const global = channels.splice(globalIndex, 1)[0];
            channels.unshift(global);
        }

        return channels;
    }

    async deleteChannel(name: string) {
        if (name.toLowerCase() === 'global') {
            throw new Error('Cannot delete global channel');
        }

        const session = await this.channelModel.db.startSession();
        session.startTransaction();
        try {
            const channel = await this.channelModel.findOneAndDelete({ name }).session(session);
            if (!channel) {
                throw new Error('Channel not found');
            }

            await this.channelModel.db.collection('messages').deleteMany(
                {
                    roomType: 'channel',
                    roomId: name,
                },
                { session },
            );

            await session.commitTransaction();
            return channel;
        } catch (error) {
            await session.abortTransaction();
            throw error;
        } finally {
            session.endSession();
        }
    }

    async channelExists(name: string): Promise<boolean> {
        const channel = await this.channelModel.findOne({ name }).lean().exec();
        return !!channel;
    }
}
