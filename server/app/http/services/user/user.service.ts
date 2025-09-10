import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User } from '../../model/schemas/user/user.schema';

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

    async findById(id: string): Promise<User | null> {
        return this.userModel.findById(id).select('-password');
    }

    async deleteById(id: string): Promise<{ deleted: boolean; message?: string }> {
        const result = await this.userModel.deleteOne({ _id: id }).exec();
        if (result.deletedCount === 0) {
            return { deleted: false, message: 'Utilisateur non trouvé' };
        }
        return { deleted: true };
    }

    async updateById(id: string, email: string, pseudonyme: string, avatar?: string): Promise<User | null> {
        return this.userModel.findByIdAndUpdate(id, { email, pseudonyme, avatar }, { new: true }).select('-password').lean();
    }

    async updateStatsById(id: string, mode: string, isWin: boolean, duration: number): Promise<User | null> {
        const user = await this.userModel.findById(id);

        user.stats[mode].gamesPlayed += 1;
        if (isWin) {
            user.stats[mode].gamesWon += 1;
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
        pseudonyme: string,
        avatar?: string,
    ): Promise<{ success: boolean; message?: string; user?: User }> {
        if (!email || !password || !pseudonyme) {
            return { success: false, message: 'Email, mot de passe et pseudonyme sont obligatoires.' };
        }
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return { success: false, message: "Le format de l'email est invalide." };
        }
        const existingEmail = await this.findByEmail(email);
        if (existingEmail) {
            return { success: false, message: 'Cet email est déjà utilisé.' };
        }
        const existingPseudo = await this.findByPseudonyme(pseudonyme);
        if (existingPseudo) {
            return { success: false, message: 'Ce pseudonyme est déjà utilisé.' };
        }
        const user = await this.create(email, password, pseudonyme, avatar);
        return { success: true, user };
    }

    async updateUserWithChecks(user: User, email: string, pseudonyme: string, avatar?: string): Promise<{ success: boolean; message?: string }> {
        if (email && email !== user.email) {
            const existingEmail = await this.findByEmail(email);
            if (existingEmail && existingEmail._id.toString() !== user._id.toString()) {
                return { success: false, message: 'Cet email est déjà utilisé.' };
            }
        }
        if (pseudonyme && pseudonyme !== user.pseudonyme) {
            const existingPseudo = await this.findByPseudonyme(pseudonyme);
            if (existingPseudo && existingPseudo._id.toString() !== user._id.toString()) {
                return { success: false, message: 'Ce pseudonyme est déjà utilisé.' };
            }
        }
        await this.updateById(user._id.toString(), email, pseudonyme, avatar);
        return { success: true, message: 'Compte mis à jour avec succès' };
    }
}
