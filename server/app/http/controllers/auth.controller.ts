import { JWT_SECRET } from '@common/constants';
import { Avatar, ProfilePicture } from '@common/game';
import { UserStatus } from '@common/user-friends';
import { Body, Controller, Delete, Get, HttpStatus, Inject, Patch, Post, Req, Res } from '@nestjs/common';
import { ApiCreatedResponse, ApiNotFoundResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import * as jwt from 'jsonwebtoken';
import { ChatroomService } from '../../services/chatroom/chatroom.service';
import { ShopService } from '../../services/shop/shop.service';
import { FriendsGateway } from '../../socket/game/gateways/friends/friends.gateway';
import { AdminService } from '../services/admin/admin.service';
import { FriendsService } from '../services/friends/friends.service';
import { UserService } from '../services/user/user.service';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
    @Inject(UserService) private readonly userService: UserService;
    @Inject(AdminService) private readonly adminService: AdminService;
    @Inject(FriendsService) private readonly friendsService: FriendsService;
    @Inject(ChatroomService) private readonly chatroomService: ChatroomService;
    @Inject(ShopService) private readonly shopService: ShopService;
    @Inject(FriendsGateway) private readonly friendsGateway: FriendsGateway;

    @ApiCreatedResponse({
        description: 'Register a new user',
    })
    @ApiNotFoundResponse({
        description: 'Return BAD_REQUEST http status when registration fails',
    })
    @Post('register')
    async register(
        @Body('email') email: string,
        @Body('password') password: string,
        @Body('username') username: string,
        @Body('avatar') avatar: Avatar,
        @Body('avatarCustom') avatarCustom: string,
        @Body('profilePicture') profilePicture: ProfilePicture,
        @Body('profilePictureCustom') profilePictureCustom: string,
        @Res() response: Response,
    ) {
        try {
            const result = await this.userService.registerUser(email, password, username, avatar, avatarCustom, profilePicture, profilePictureCustom);
            if (!result.success) {
                return response.status(HttpStatus.BAD_REQUEST).json(result);
            }

            if (result.user) {
                await this.friendsGateway.notifyNewUserRegistered({
                    username: result.user.username,
                    level: result.user.stats?.level || 1,
                });
            }

            response.status(HttpStatus.CREATED).json({ success: true, message: 'Inscription réussie !', user: result.user });
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: error.message || 'Registration failed',
                error,
            });
        }
    }

    @ApiOkResponse({
        description: 'Login user',
    })
    @ApiNotFoundResponse({
        description: 'Return UNAUTHORIZED http status when login fails',
    })
    @Post('login')
    async login(@Body('username') username: string, @Body('password') password: string, @Res() response: Response) {
        try {
            const result = await this.userService.validateUserLogin(username, password);
            if (!result.success) {
                const status = result.message === 'Pseudo ou mot de passe incorrect.' ? HttpStatus.UNAUTHORIZED : HttpStatus.BAD_REQUEST;
                return response.status(status).json(result);
            }

            const token = jwt.sign({ userId: result.user._id }, JWT_SECRET, { expiresIn: '1d' });
            const userId = String(result.user._id);

            this.userService.registerUserSession(userId, token);
            response.status(HttpStatus.OK).json({
                success: true,
                message: 'Connexion réussie !',
                user: result.user,
                token,
            });
            const user = await this.userService.findById(userId);
            if (user) {
                await this.friendsService.updateUserStatus(user.username, UserStatus.Online);
            }
        } catch (error) {
            response.status(HttpStatus.BAD_REQUEST).json({
                success: false,
                message: error.message || 'Login failed',
            });
        }
    }

    @Get('me')
    async getProfile(@Req() req) {
        const { userId, error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };
        const user = await this.userService.findById(userId);
        if (!user) return { success: false, message: 'Utilisateur non trouvé' };
        if (user.password) delete user.password;
        return { success: true, user };
    }

    @Delete('delete')
    async deleteAccount(@Req() req) {
        const { userId, error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };
        const user = await this.userService.findById(userId);
        if (!user) return { success: false, message: 'Utilisateur non trouvé' };

        this.userService.removeUserSession(userId);
        await this.chatroomService.updateMessageAuthor(user.username, '[supprimé]');
        await this.chatroomService.updateMessageAuthorProfilePicture(user.username, undefined, undefined);
        await this.chatroomService.updateMessageAuthorAvatar(user.username, undefined, undefined);
        await this.adminService.deleteAllMapsByCreator(userId);
        await this.friendsService.removeUserFromAllFriendLists(user.username);
        await this.userService.deleteById(userId);
        return { success: true, message: 'Compte supprimé avec succès' };
    }

    @Post('logout')
    async logout(@Req() req) {
        const { userId, error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };

        const user = await this.userService.findById(userId);
        if (user) {
            await this.friendsService.updateUserStatus(user.username, UserStatus.Offline);
        }

        this.userService.removeUserSession(userId);
        return { success: true, message: 'Déconnexion réussie' };
    }

    @Patch('update')
    async updateAccount(
        @Req() req,
        @Body('email') email: string,
        @Body('username') username: string,
        @Body('avatar') avatar: Avatar,
        @Body('avatarCustom') avatarCustom: string,
        @Body('profilePicture') profilePicture: ProfilePicture,
        @Body('profilePictureCustom') profilePictureCustom: string,
    ) {
        const { userId, error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };
        const user = await this.userService.findById(userId);
        if (!user) return { success: false, message: 'Utilisateur non trouvé' };

        const oldUsername = user.username;
        const oldAvatar = user.avatar;
        const oldAvatarCustom = user.avatarCustom;
        const oldProfilePicture = user.profilePicture;
        const oldProfilePictureCustom = user.profilePictureCustom;

        const result = await this.userService.updateUserWithChecks(user, email, username, avatar, avatarCustom, profilePicture, profilePictureCustom);

        if (result.success) {
            try {
                if (username && username !== oldUsername) {
                    await this.chatroomService.updateMessageAuthor(oldUsername, username);
                }

                const avatarChanged = avatar !== oldAvatar || avatarCustom !== oldAvatarCustom;
                const profilePictureChanged = profilePicture !== oldProfilePicture || profilePictureCustom !== oldProfilePictureCustom;

                if (avatarChanged) {
                    const currentUsername = username || oldUsername;
                    await this.chatroomService.updateMessageAuthorAvatar(currentUsername, avatar, avatarCustom);
                }

                if (profilePictureChanged) {
                    const currentUsername = username || oldUsername;
                    await this.chatroomService.updateMessageAuthorProfilePicture(currentUsername, profilePicture, profilePictureCustom);

                    const isFromEquippedShopItem = await this.shopService.isProfilePictureFromEquippedShopItem(userId, profilePicture);
                    if (!isFromEquippedShopItem) {
                        await this.shopService.unequipAllProfilePicturesForUser(userId);
                    }
                }
            } catch (error) {
                console.error('Erreur lors de la mise à jour des messages:', error);
            }
        }

        return result;
    }

    @Patch('stats')
    async updateStats(@Req() req, @Body() stats: { mode: string; isWin: boolean; duration: number }) {
        const { userId, error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };
        const user = await this.userService.updateStatsById(userId, stats.mode, stats.isWin, stats.duration);
        if (!user) return { success: false, message: 'Utilisateur non trouvé' };
        return { success: true, user };
    }

    @Get('users/search')
    async searchUsers(@Req() req) {
        const { error } = await this.getUserIdFromToken(req);
        if (error) return { success: false, message: error };

        const query = req.query.q || '';
        const users = await this.userService.searchUsersByUsername(query);

        return { success: true, users };
    }

    private async getUserIdFromToken(req: any): Promise<{ userId?: string; error?: string }> {
        let token = req.query.token;
        if (!token && req.headers.authorization) {
            const authHeader = req.headers.authorization;
            if (authHeader.startsWith('Bearer ')) {
                token = authHeader.substring(7);
            }
        }
        if (!token && req.body && req.body.token) {
            token = req.body.token;
        }
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
