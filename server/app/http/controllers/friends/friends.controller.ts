import { JWT_SECRET } from '@common/constants';
import { Body, Controller, Delete, Get, HttpStatus, Inject, Param, Post, Res } from '@nestjs/common';
import { ApiCreatedResponse, ApiNotFoundResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import * as jwt from 'jsonwebtoken';
import { FriendsService } from '../../services/friends/friends.service';

@ApiTags('Friends')
@Controller('friends')
export class FriendsController {
    @Inject(FriendsService) private readonly friendsService: FriendsService;

    @ApiCreatedResponse({
        description: "Demande d'amitié envoyée avec succès.",
    })
    @ApiNotFoundResponse({
        description: 'Utilisateur non trouvé ou demande déjà en cours.',
    })
    @Post('add')
    async sendFriendRequest(@Body() body: { username: string; token: string }, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(body.token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const result = await this.friendsService.sendFriendRequest(userId!, body.username);

            response.status(HttpStatus.CREATED).json(result);
        } catch (error) {
            console.error('Error in sendFriendRequest:', error);
            response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: `Erreur lors de l'envoi de la demande d'ami: ${error.message}`,
            });
        }
    }

    @ApiOkResponse({
        description: "Demande d'amitié acceptée avec succès.",
    })
    @ApiNotFoundResponse({
        description: 'Demande non trouvée ou utilisateur introuvable.',
    })
    @Post('accept/:username')
    async acceptFriendRequest(@Param('username') fromUsername: string, @Body() body: { token: string }, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(body.token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const result = await this.friendsService.acceptFriendRequest(userId!, fromUsername);

            if (result.success) {
                const friends = await this.friendsService.getFriends(userId!);
                response.status(HttpStatus.OK).json({ success: true, message: result.message, friends });
            } else {
                response.status(HttpStatus.BAD_REQUEST).json(result);
            }
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({ success: false, message: "Erreur lors de l'acceptation de la demande" });
        }
    }

    @ApiOkResponse({
        description: "Demande d'amitié refusée avec succès.",
    })
    @ApiNotFoundResponse({
        description: 'Demande non trouvée.',
    })
    @Post('reject/:username')
    async rejectFriendRequest(@Param('username') fromUsername: string, @Body() body: { token: string }, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(body.token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const result = await this.friendsService.rejectFriendRequest(userId!, fromUsername);
            response.status(HttpStatus.OK).json(result);
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({ success: false, message: 'Erreur lors du refus de la demande' });
        }
    }

    @ApiOkResponse({
        description: 'Ami supprimé avec succès.',
    })
    @ApiNotFoundResponse({
        description: 'Ami non trouvé.',
    })
    @Delete('remove/:username')
    async removeFriend(@Param('username') friendUsername: string, @Body() body: { token: string }, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(body.token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const result = await this.friendsService.removeFriend(userId!, friendUsername);

            if (!result) {
                return response.status(HttpStatus.NOT_FOUND).json({ success: false, message: 'Utilisateur non trouvé' });
            }

            const friends = await this.friendsService.getFriends(userId!);
            response.status(HttpStatus.OK).json({ success: true, friends });
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({ success: false, message: "Erreur lors de la suppression de l'ami" });
        }
    }

    @ApiOkResponse({
        description: 'Liste des amis récupérée.',
    })
    @ApiNotFoundResponse({
        description: 'Utilisateur non trouvé.',
    })
    @Get('/:token')
    async getFriends(@Param('token') token: string, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const friends = await this.friendsService.getFriends(userId!);
            response.status(HttpStatus.OK).json({ success: true, friends });
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({ success: false, message: 'Erreur lors de la récupération des amis' });
        }
    }

    @ApiOkResponse({
        description: "Liste des demandes d'amitié récupérée.",
    })
    @ApiNotFoundResponse({
        description: 'Utilisateur non trouvé.',
    })
    @Get('requests/:token')
    async getFriendRequests(@Param('token') token: string, @Res() response: Response) {
        try {
            const { userId, error } = await this.getUserIdFromToken(token);

            if (error) {
                return response.status(HttpStatus.UNAUTHORIZED).json({ success: false, message: error });
            }

            const friendRequests = await this.friendsService.getFriendRequests(userId!);
            response.status(HttpStatus.OK).json({ success: true, friendRequests });
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({ success: false, message: "Erreur lors de la récupération des demandes d'amitié" });
        }
    }

    private async getUserIdFromToken(token: string): Promise<{ userId?: string; error?: string }> {
        if (!token) {
            return { error: 'Token manquant' };
        }
        try {
            const decoded: any = jwt.verify(token, JWT_SECRET);
            if (!decoded || !decoded.userId) {
                return { error: 'Token invalide' };
            }
            return { userId: decoded.userId };
        } catch (e) {
            return { error: 'Token invalide ou expiré' };
        }
    }
}
