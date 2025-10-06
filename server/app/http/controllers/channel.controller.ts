import { ChannelService } from '@app/http/services/channel/channel.service';
import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';

@Controller('channels')
export class ChannelController {
    constructor(private readonly channelService: ChannelService) {
        this.channelService = channelService;
    }

    @Get()
    async listChannels() {
        try {
            const channels = await this.channelService.listChannels();
            return { channels };
        } catch (error) {
            return { error: error.message };
        }
    }

    @Post()
    async createChannel(@Body() body: { name: string; creator: string; isPublic?: boolean }, @Query('token') token: string) {
        try {
            if (!token) {
                return { success: false, message: 'Token requis' };
            }

            const { name, creator, isPublic = true } = body;

            if (!name || !creator) {
                return { success: false, message: 'Nom du channel et créateur requis' };
            }

            if (name.length < 3 || name.length > 20) {
                return { success: false, message: 'Le nom du channel doit contenir entre 3 et 20 caractères' };
            }

            if (!/^[a-zA-Z0-9-_]+$/.test(name)) {
                return { success: false, message: 'Le nom du channel ne peut contenir que des lettres, chiffres, tirets et underscores' };
            }

            if (name.toLowerCase() === 'global') {
                return { success: false, message: 'Le nom "global" est réservé' };
            }

            const channel = await this.channelService.createChannel(name, creator, isPublic);
            return { success: true, message: 'Channel créé avec succès', channel };
        } catch (error) {
            if (error.message === 'Channel already exists') {
                return { success: false, message: 'Un channel avec ce nom existe déjà' };
            }
            return { success: false, message: 'Erreur lors de la création du channel' };
        }
    }

    @Delete(':name')
    async deleteChannel(@Param('name') name: string, @Query('token') token: string) {
        try {
            if (!token) {
                return { success: false, message: 'Token requis' };
            }

            if (name.toLowerCase() === 'global') {
                return { success: false, message: 'Le channel global ne peut pas être supprimé' };
            }

            await this.channelService.deleteChannel(name);
            return { success: true, message: 'Channel supprimé avec succès' };
        } catch (error) {
            if (error.message === 'Channel not found') {
                return { success: false, message: 'Channel introuvable' };
            }
            return { success: false, message: 'Erreur lors de la suppression du channel' };
        }
    }
}
