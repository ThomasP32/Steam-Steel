import { JWT_SECRET, MAX_LEVEL, N_LEVEL_BANNER, N_WINS_PER_LEVEL } from '@common/constants';
import { GameManagerEvents } from '@common/events/game-manager.events';
import { Avatar, ProfilePicture } from '@common/game';
import { Inject, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import * as jwt from 'jsonwebtoken';
import { Model } from 'mongoose';
import { Server } from 'socket.io';
import { UserSocketService } from '../../../services/user-socket/user-socket.service';
import { User } from '../../model/schemas/user/user.schema';

@Injectable()
export class UserService {
    private readonly activeSessions: Map<string, string> = new Map();
    server: Server;

    constructor(
        @InjectModel(User.name) private readonly userModel: Model<User>,
        @Inject(UserSocketService) private readonly userSocketService: UserSocketService,
    ) {
        this.userModel = userModel;
        this.userSocketService = userSocketService;
    }

    setServer(server: Server): void {
        this.server = server;
    }

    async create(
        email: string,
        password: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<User> {
        const user = new this.userModel({
            email,
            password,
            username,
            avatar,
            avatarCustom,
            profilePicture: profilePicture || ProfilePicture.Profile1,
            profilePictureCustom,
        });
        return user.save();
    }

    async findByEmail(email: string): Promise<User | null> {
        return this.userModel.findOne({ email }).exec();
    }

    async findByUsername(username: string): Promise<User | null> {
        return this.userModel.findOne({ username }).exec();
    }

    async findById(id: string): Promise<User | null> {
        return this.userModel.findById(id).select('-password');
    }

    async validateUser(username: string, password: string): Promise<User | null> {
        const user = await this.findByUsername(username);
        if (user && user.password === password) {
            return user;
        }
        return null;
    }

    async deleteById(id: string): Promise<{ deleted: boolean; message?: string }> {
        const result = await this.userModel.deleteOne({ _id: id }).exec();
        if (result.deletedCount === 0) {
            return { deleted: false, message: 'Utilisateur non trouvé' };
        }
        return { deleted: true };
    }

    async updateById(
        id: string,
        email: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<User | null> {
        const update: any = { email, username };
        if (avatar !== undefined) update.avatar = avatar;
        if (avatarCustom !== undefined) update.avatarCustom = avatarCustom;
        if (profilePicture !== undefined) update.profilePicture = profilePicture;
        if (profilePictureCustom !== undefined) update.profilePictureCustom = profilePictureCustom;
        return this.userModel.findByIdAndUpdate(id, update, { new: true }).select('-password').lean();
    }

    async updateStatsById(id: string, mode: string, isWin: boolean, duration: number): Promise<User | null> {
        const user = await this.userModel.findById(id);

        user.stats[mode].gamesPlayed += 1;
        if (isWin) {
            user.stats[mode].gamesWon += 1;
            const totalGamesWon = user.stats.classique.gamesWon + user.stats.ctf.gamesWon;
            if (totalGamesWon % N_WINS_PER_LEVEL === 0) {
                if (!user.stats.level) {
                    user.stats.level = 1;
                }
                user.stats.level = Math.min(user.stats.level + 1, MAX_LEVEL);
                const bannerUnlocked = user.stats.level % N_LEVEL_BANNER === 0;
                const socketId = this.userSocketService.getSocketId(id);
                if (socketId) {
                    this.server.to(socketId).emit(GameManagerEvents.PlayerLeveledUp, {
                        newLevel: user.stats.level,
                        bannerUnlocked,
                    });
                }
            }
        }
        const totalGames = (user.stats.classique?.gamesPlayed || 0) + (user.stats.ctf?.gamesPlayed || 0);
        if (!user.stats.avgTime || user.stats.avgTime === 0) {
            user.stats.avgTime = duration;
        } else if (totalGames > 1) {
            user.stats.avgTime = (user.stats.avgTime * (totalGames - 1) + duration) / totalGames;
        }
        user.markModified('stats');
        await user.save();
        return user.toObject();
    }

    async registerUser(
        email: string,
        password: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<{ success: boolean; message?: string; user?: User }> {
        const validationError = this.validateInputs(email, password, username);
        if (validationError) {
            return { success: false, message: validationError };
        }

        const existingEmail = await this.findByEmail(email);
        if (existingEmail) {
            return { success: false, message: 'Cet email est déjà utilisé.' };
        }
        const existingUsername = await this.findByUsername(username);
        if (existingUsername) {
            return { success: false, message: 'Ce pseudo est déjà utilisé.' };
        }
        const user = await this.create(email, password, username, avatar, avatarCustom, profilePicture, profilePictureCustom);
        return { success: true, user };
    }

    async updateUserWithChecks(
        user: User,
        email: string,
        username: string,
        avatar?: Avatar,
        avatarCustom?: string,
        profilePicture?: ProfilePicture,
        profilePictureCustom?: string,
    ): Promise<{ success: boolean; message?: string }> {
        const validationError = this.validateUpdateInputs(email, username);
        if (validationError) {
            return { success: false, message: validationError };
        }

        if (email && email !== user.email) {
            const existingEmail = await this.findByEmail(email);
            if (existingEmail && String(existingEmail._id) !== String(user._id)) {
                return { success: false, message: 'Cet email est déjà utilisé.' };
            }
        }
        if (username && username !== user.username) {
            const existingPseudo = await this.findByUsername(username);
            if (existingPseudo && String(existingPseudo._id) !== String(user._id)) {
                return { success: false, message: 'Ce pseudo est déjà utilisé.' };
            }
        }
        await this.updateById(String(user._id), email, username, avatar, avatarCustom, profilePicture, profilePictureCustom);
        return { success: true, message: 'Compte mis à jour avec succès' };
    }

    async validateUserLogin(username: string, password: string): Promise<{ success: boolean; message?: string; user?: User }> {
        const validationError = this.validateLoginInputs(username, password);
        if (validationError) {
            return { success: false, message: validationError };
        }

        const user = await this.validateUser(username, password);
        if (!user) {
            return { success: false, message: 'Pseudo ou mot de passe incorrect.' };
        }

        const userId = String(user._id);
        const existingSession = this.activeSessions.get(userId);

        if (existingSession) {
            return {
                success: false,
                message: 'Ce compte est déjà connecté ailleurs.',
            };
        }

        return { success: true, user };
    }

    registerUserSession(userId: string, sessionToken: string): void {
        this.activeSessions.set(userId, sessionToken);
    }

    removeUserSession(userId: string): void {
        this.activeSessions.delete(userId);
    }

    getUserSession(userId: string): string | undefined {
        return this.activeSessions.get(userId);
    }

    isUserConnected(userId: string): boolean {
        return this.activeSessions.has(userId);
    }

    private validateInputs(email: string, password: string, username: string): string | null {
        // Normalize inputs and explicitly reject fields that are empty or
        // contain only whitespace. Also reject any fields that contain
        // whitespace characters (space, tab, newline) anywhere.
        const emailRaw = email ?? '';
        const passwordRaw = password ?? '';
        const usernameRaw = username ?? '';

        const emailTrim = emailRaw.trim();
        const passwordTrim = passwordRaw.trim();
        const usernameTrim = usernameRaw.trim();

        if (emailTrim.length === 0 || passwordTrim.length === 0 || usernameTrim.length === 0) {
            return 'Tous les champs sont obligatoires';
        }

        const whitespaceRe = /\s/; // detects spaces, tabs, newlines
        if (whitespaceRe.test(emailRaw) || whitespaceRe.test(passwordRaw) || whitespaceRe.test(usernameRaw)) {
            return "Les champs ne peuvent pas contenir d'espaces";
        }

        const emailRegex = /^(?=[a-zA-Z0-9._-]*[a-zA-Z0-9])[a-zA-Z0-9._-]+@(?![a-zA-Z0-9.-]+\.$)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        if (!emailRegex.test(email)) {
            return "Format d'email invalide";
        }

        if (email.length > 50) {
            return "L'email ne peut pas dépasser 50 caractères";
        }
        if (password.length > 30) {
            return 'Le mot de passe ne peut pas dépasser 30 caractères';
        }
        if (username.length > 10) {
            return 'Le pseudonyme ne peut pas dépasser 10 caractères';
        }

        if (password.length < 6) {
            return 'Le mot de passe doit contenir au moins 6 caractères';
        }
        if (username.length < 3) {
            return 'Le pseudonyme doit contenir au moins 3 caractères';
        }

        return null;
    }

    private validateUpdateInputs(email: string, username: string): string | null {
        const emailRaw = email ?? '';
        const usernameRaw = username ?? '';

        const emailTrim = emailRaw.trim();
        const usernameTrim = usernameRaw.trim();

        if (emailTrim.length === 0 || usernameTrim.length === 0) {
            return "L'email et le pseudo sont obligatoires";
        }

        const whitespaceRe = /\s/;
        if (whitespaceRe.test(emailRaw) || whitespaceRe.test(usernameRaw)) {
            return "Les champs ne peuvent pas contenir d'espaces";
        }

        if (email.length > 50) {
            return "L'email ne peut pas dépasser 50 caractères";
        }
        if (username.length > 10) {
            return 'Le pseudonyme ne peut pas dépasser 10 caractères';
        }

        if (username.length < 3) {
            return 'Le pseudonyme doit contenir au moins 3 caractères';
        }

        const emailRegex = /^(?=[a-zA-Z0-9._-]*[a-zA-Z0-9])[a-zA-Z0-9._-]+@(?![a-zA-Z0-9.-]+\.$)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
        if (!emailRegex.test(email)) {
            return "Format d'email invalide";
        }

        return null;
    }

    private validateLoginInputs(username: string, password: string): string | null {
        if (!username || !password) {
            return 'Tous les champs sont obligatoires';
        }

        if (username.includes(' ') || password.includes(' ')) {
            return "Les champs ne peuvent pas contenir d'espaces";
        }

        if (username.length > 50 || password.length > 30) {
            return 'Longueur des champs invalide';
        }

        return null;
    }

    async validateToken(token: string): Promise<User | null> {
        try {
            const decoded: any = jwt.verify(token, JWT_SECRET);
            if (!decoded || !decoded.userId) {
                return null;
            }
            return await this.findById(decoded.userId);
        } catch (e) {
            return null;
        }
    }

    async getUserById(id: string): Promise<User | null> {
        return this.userModel.findById(id).exec();
    }

    async getUsersWithFriend(friendUsername: string): Promise<User[]> {
        const friendUser = await this.findByUsername(friendUsername);
        if (!friendUser) return [];

        return this.userModel.find({ friends: friendUser._id.toString() }).exec();
    }

    async searchUsersByUsername(query: string): Promise<{ username: string; level: number }[]> {
        let searchQuery: any = {};

        if (query && query.length > 0) {
            searchQuery.username = { $regex: `^${query}`, $options: 'i' };
        }

        const users = await this.userModel
            .find(searchQuery)
            .select('username stats.level')
            .limit(query ? 10 : 100)
            .sort({ username: 1 })
            .exec();

        return users.map((user) => ({
            username: user.username,
            level: user.stats.level ?? 1,
        }));
    }

    async incrementChallengesCompleted(userId: string): Promise<User | null> {
        const user = await this.userModel.findById(userId);
        if (!user) return null;

        if (!user.stats.challengesCompleted) {
            user.stats.challengesCompleted = 0;
        }
        user.stats.challengesCompleted += 1;
        user.markModified('stats');
        await user.save();
        return user.toObject();
    }
}
