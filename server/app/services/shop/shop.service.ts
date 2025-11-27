import { ShopItem } from '@common/events/shop.events';
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User } from '../../http/model/schemas/user/user.schema';
import { ChatroomService } from '../chatroom/chatroom.service';

@Injectable()
export class ShopService {
    constructor(
        @InjectModel(User.name) private readonly userModel: Model<User>,
        private readonly chatroomService: ChatroomService,
    ) {
        this.userModel = userModel;
        this.chatroomService = chatroomService;
    }

    private readonly shopCatalog: ShopItem[] = [
        // Avatars
        {
            id: 'avatar_1',
            name: 'Nyssara',
            price: 700,
            category: 'characters',
            imagePath: 'assets/characters/13.png',
            description: 'Un brave assassin avec ses dagues rapides',
        },
        {
            id: 'avatar_2',
            name: 'Lancelot',
            price: 500,
            category: 'characters',
            imagePath: 'assets/characters/14.png',
            description: 'Une puissante guerrière avec son épée et son bouclier',
        },
        {
            id: 'avatar_3',
            name: 'Legolas',
            price: 600,
            category: 'characters',
            imagePath: 'assets/characters/15.png',
            description: 'Une archère agile et précise avec son arc et ses flèches',
        },
        {
            id: 'avatar_4',
            name: 'Aetherion',
            price: 1000,
            category: 'characters',
            imagePath: 'assets/characters/16.png',
            description: 'Un dragon mystique avec des pouvoirs élémentaires',
        },
        {
            id: 'avatar_5',
            name: 'Luminova',
            price: 1500,
            category: 'characters',
            imagePath: 'assets/characters/17.png',
            description: 'Une licorne magique avec une crinière étincelante',
        },

        // Bannières
        {
            id: 'banner_1',
            name: 'Bannière Royale',
            price: 500,
            category: 'banner',
            imagePath: 'assets/banner/1.png',
            description: 'Une bannière digne des rois',
        },
        {
            id: 'banner_2',
            name: 'Bannière Amour',
            price: 600,
            category: 'banner',
            imagePath: 'assets/banner/2.png',
            description: "Une bannière aux pouvoirs d'amour",
        },
        {
            id: 'banner_3',
            name: 'Bannière Futuriste',
            price: 500,
            category: 'banner',
            imagePath: 'assets/banner/3.png',
            description: "Une bannière futuriste qui symbolise l'avenir",
        },
        {
            id: 'banner_4',
            name: 'Bannière Ténébreuse',
            price: 400,
            category: 'banner',
            imagePath: 'assets/banner/4.png',
            description: 'Une bannière qui symbolise les ténèbres',
        },
        {
            id: 'banner_5',
            name: 'Bannière Glaciale',
            price: 500,
            category: 'banner',
            imagePath: 'assets/banner/5.png',
            description: 'Une bannière qui évoque la glace et la résilience',
        },
        {
            id: 'banner_6',
            name: 'Bannière du Tonnerre',
            price: 600,
            category: 'banner',
            imagePath: 'assets/banner/6.png',
            description: 'Une bannière qui incarne la puissance du tonnerre',
            ChallengeRequired: 5,
        },
        {
            id: 'banner_7',
            name: 'Bannière Supreme',
            price: 700,
            category: 'banner',
            imagePath: 'assets/banner/7.png',
            description: 'Une bannière suprême qui domine toutes les autres',
            ChallengeRequired: 10,
        },
        {
            id: 'banner_8',
            name: 'Bannière Halloween',
            price: 800,
            category: 'banner',
            imagePath: 'assets/banner/8.png',
            description: 'Une bannière Halloween effrayante et mystérieuse',
            ChallengeRequired: 15,
        },
        {
            id: 'banner_9',
            name: 'Bannière Noel',
            price: 900,
            category: 'banner',
            imagePath: 'assets/banner/9.png',
            description: 'Une bannière de Noël festive et joyeuse',
            ChallengeRequired: 20,
        },
        {
            id: 'banner_10',
            name: 'Bannière Mulicolore',
            price: 1000,
            category: 'banner',
            imagePath: 'assets/banner/10.png',
            description: 'Une bannière multicolore qui brille de mille feux',
            ChallengeRequired: 25,
        },

        // Sons (pour le futur)
        {
            id: 'sound_1',
            name: 'Musique thème - Minecraft',
            price: 500,
            category: 'sound',
            imagePath: 'assets/icons/minecraft.png',
            description: 'Musique emblématique de Minecraft',
        },
        //Profiles
        {
            id: 'profile_4',
            name: 'Daphné',
            price: 150,
            category: 'profilePicture',
            imagePath: 'assets/profile/4.png',
            description: 'Une photo de profil feminine',
        },
        {
            id: 'profile_5',
            name: 'Pascal',
            price: 200,
            category: 'profilePicture',
            imagePath: 'assets/profile/5.png',
            description: 'Une photo de profil Pascal',
        },
        {
            id: 'profile_11',
            name: 'Fée',
            price: 250,
            category: 'profilePicture',
            imagePath: 'assets/profile/11.png',
            description: 'Une photo de profil Fée',
        },
        {
            id: 'profile_12',
            name: 'Pingouin',
            price: 300,
            category: 'profilePicture',
            imagePath: 'assets/profile/12.png',
            description: 'Une photo de profil Pingouin',
        },
        {
            id: 'profile_13',
            name: 'Marty',
            price: 350,
            category: 'profilePicture',
            imagePath: 'assets/profile/13.png',
            description: 'Une photo de profil Marty',
        },
        {
            id: 'profile_6',
            name: 'R2D2',
            price: 400,
            category: 'profilePicture',
            imagePath: 'assets/profile/6.png',
            description: 'Une photo de profil R2D2',
            levelRequired: 5,
        },
        {
            id: 'profile_7',
            name: 'Arc-en-ciel',
            price: 450,
            category: 'profilePicture',
            imagePath: 'assets/profile/7.png',
            description: 'Une photo de profil Arc-en-ciel',
            levelRequired: 10,
        },
        {
            id: 'profile_8',
            name: 'Krokmou',
            price: 500,
            category: 'profilePicture',
            imagePath: 'assets/profile/8.png',
            description: 'Une photo de profil Krokmou',
            levelRequired: 15,
        },
        {
            id: 'profile_9',
            name: 'Étudiant de Poly',
            price: 550,
            category: 'profilePicture',
            imagePath: 'assets/profile/9.png',
            description: 'Une photo de profil typique',
            levelRequired: 20,
        },
        {
            id: 'profile_10',
            name: 'Simba',
            price: 600,
            category: 'profilePicture',
            imagePath: 'assets/profile/10.png',
            description: 'Une photo de profil de Simba royal',
            levelRequired: 25,
        },
    ];

    async getUserMoney(userId: string): Promise<number | null> {
        if (!userId || userId === 'undefined') {
            console.error('getUserMoney: userId is invalid:', userId);
            return null;
        }
        const user = await this.userModel.findById(userId).select('virtualMoney');
        return user ? user.virtualMoney : null;
    }

    async addMoney(userId: string, amount: number): Promise<boolean> {
        try {
            const result = await this.userModel.findByIdAndUpdate(userId, { $inc: { virtualMoney: amount } }, { new: true });
            console.log('Add money result:', amount);

            return !!result;
        } catch (error) {
            console.error('Error adding money:', error);
            return false;
        }
    }

    async deductMoney(userId: string, amount: number): Promise<boolean> {
        try {
            const user = await this.userModel.findById(userId);
            if (!user || user.virtualMoney < amount) {
                return false;
            }

            const result = await this.userModel.findByIdAndUpdate(userId, { $inc: { virtualMoney: -amount } }, { new: true });
            console.log('Deduct money result:', amount);
            return !!result;
        } catch (error) {
            console.error('Error deducting money:', error);
            return false;
        }
    }

    async canAfford(userId: string, amount: number): Promise<boolean> {
        const userMoney = await this.getUserMoney(userId);
        return userMoney !== null && userMoney >= amount;
    }

    async distributeGameWinnings(
        totalPrizePool: number,
        winners: string[],
        activePlayers: string[],
    ): Promise<{ success: boolean; winnerAmount: number; consolationAmount: number }> {
        if (totalPrizePool <= 0 || winners.length === 0) {
            return { success: false, winnerAmount: 0, consolationAmount: 0 };
        }

        try {
            const session = await this.userModel.db.startSession();
            session.startTransaction();

            try {
                // 2/3 du prize pool pour les gagnants
                const winnersShare = Math.round((totalPrizePool * 2) / 3);
                const winnerAmount = Math.floor(winnersShare / winners.length);
                console.log('Winner prize:', winnerAmount);

                // 1/3 du prize pool pour les autres joueurs actifs (lots de consolation)
                const consolationShare = totalPrizePool - winnersShare;
                const otherPlayers = activePlayers.filter((id) => !winners.includes(id));
                const consolationAmount = otherPlayers.length > 0 ? Math.floor(consolationShare / otherPlayers.length) : 0;
                console.log('Consolation prize:', consolationAmount);

                for (const winnerId of winners) {
                    await this.userModel.findByIdAndUpdate(winnerId, { $inc: { virtualMoney: winnerAmount } }, { session });
                }

                for (const playerId of otherPlayers) {
                    await this.userModel.findByIdAndUpdate(playerId, { $inc: { virtualMoney: consolationAmount } }, { session });
                }

                await session.commitTransaction();
                return { success: true, winnerAmount, consolationAmount };
            } catch (error) {
                await session.abortTransaction();
                throw error;
            } finally {
                session.endSession();
            }
        } catch (error) {
            console.error('Error distributing game winnings:', error);
            return { success: false, winnerAmount: 0, consolationAmount: 0 };
        }
    }

    async distributeLastPlayerWinnings(totalPrizePool: number, lastPlayerId: string): Promise<{ success: boolean; amount: number }> {
        if (totalPrizePool <= 0) {
            return { success: false, amount: 0 };
        }

        try {
            await this.userModel.findByIdAndUpdate(lastPlayerId, { $inc: { virtualMoney: totalPrizePool } });
            return { success: true, amount: totalPrizePool };
        } catch (error) {
            console.error('Error distributing last player winnings:', error);
            return { success: false, amount: 0 };
        }
    }

    async refundPlayer(userId: string, amount: number): Promise<boolean> {
        return await this.addMoney(userId, amount);
    }

    async purchaseItem(userId: string, itemId: string): Promise<{ success: boolean; newBalance?: number; error?: string }> {
        if (!userId || userId === 'undefined') {
            console.error('purchaseItem: userId is invalid:', userId);
            return { success: false, error: 'ID utilisateur invalide' };
        }

        const item = this.shopCatalog.find((i) => i.id === itemId);
        if (!item) {
            return { success: false, error: 'Item non trouvé' };
        }

        const user = await this.userModel.findById(userId);
        if (!user) {
            return { success: false, error: 'Utilisateur non trouvé' };
        }

        const alreadyOwned = user.shopItems?.some((userItem) => userItem.itemId === itemId);
        if (alreadyOwned) {
            return { success: false, error: 'Vous possédez déjà cet item' };
        }

        // Vérifier le niveau requis
        if (item.levelRequired && user.stats.level < item.levelRequired) {
            return { success: false, error: `Niveau ${item.levelRequired} requis` };
        }

        if (item.ChallengeRequired && user.stats.challengesCompleted < item.ChallengeRequired) {
            return { success: false, error: `Défis ${item.ChallengeRequired} requis` };
        }

        if (user.virtualMoney < item.price) {
            return { success: false, error: 'Fonds insuffisants' };
        }

        try {
            const session = await this.userModel.db.startSession();
            session.startTransaction();

            try {
                const newBalance = user.virtualMoney - item.price;
                const newItem = {
                    itemId: itemId,
                    equipped: false,
                    purchaseDate: new Date(),
                };

                await this.userModel.findByIdAndUpdate(
                    userId,
                    {
                        $inc: { virtualMoney: -item.price },
                        $push: { shopItems: newItem },
                    },
                    { session },
                );

                await session.commitTransaction();
                return { success: true, newBalance };
            } catch (error) {
                await session.abortTransaction();
                throw error;
            } finally {
                session.endSession();
            }
        } catch (error) {
            console.error("Erreur lors de l'achat:", error);
            return { success: false, error: "Erreur serveur lors de l'achat" };
        }
    }

    async equipItem(userId: string, itemId: string): Promise<{ success: boolean; error?: string }> {
        if (!userId || userId === 'undefined') {
            console.error('equipItem: userId is invalid:', userId);
            return { success: false, error: 'ID utilisateur invalide' };
        }

        const item = this.shopCatalog.find((i) => i.id === itemId);
        if (!item) {
            return { success: false, error: 'Item non trouvé' };
        }

        const user = await this.userModel.findById(userId);
        if (!user) {
            return { success: false, error: 'Utilisateur non trouvé' };
        }

        const userItem = user.shopItems?.find((ui) => ui.itemId === itemId);
        if (!userItem) {
            return { success: false, error: 'Vous ne possédez pas cet item' };
        }

        try {
            await this.userModel.updateOne(
                { _id: userId },
                { $set: { 'shopItems.$[elem].equipped': false } },
                { arrayFilters: [{ 'elem.itemId': { $in: this.getItemsByCategory(item.category).map((i) => i.id) } }] },
            );

            await this.userModel.updateOne({ _id: userId, 'shopItems.itemId': itemId }, { $set: { 'shopItems.$.equipped': true } });

            if (item.category === 'characters') {
                const avatarId = this.mapShopItemToAvatar(itemId);
                if (avatarId) {
                    await this.userModel.updateOne({ _id: userId }, { $set: { avatar: avatarId } });

                    await this.chatroomService.updateMessageAuthorAvatar(user.username, avatarId, user.avatarCustom);
                }
            }

            if (item.category === 'profilePicture') {
                const profilePictureId = this.mapShopItemToProfilePicture(itemId);
                if (profilePictureId) {
                    await this.unequipAllProfilePicturesForUser(userId);

                    await this.userModel.updateOne({ _id: userId, 'shopItems.itemId': itemId }, { $set: { 'shopItems.$.equipped': true } });
                    await this.userModel.updateOne({ _id: userId }, { $set: { profilePicture: profilePictureId } });

                    await this.chatroomService.updateMessageAuthorProfilePicture(user.username, profilePictureId, user.profilePictureCustom);
                }
            }

            return { success: true };
        } catch (error) {
            console.error("Erreur lors de l'équipement:", error);
            return { success: false, error: "Erreur serveur lors de l'équipement" };
        }
    }

    async unequipItem(userId: string, itemId: string): Promise<{ success: boolean; error?: string }> {
        if (!userId || userId === 'undefined') {
            console.error('unequipItem: userId is invalid:', userId);
            return { success: false, error: 'ID utilisateur invalide' };
        }

        const item = this.shopCatalog.find((i) => i.id === itemId);
        if (!item) {
            return { success: false, error: 'Item non trouvé' };
        }

        const user = await this.userModel.findById(userId);
        if (!user) {
            return { success: false, error: 'Utilisateur non trouvé' };
        }

        const userItem = user.shopItems?.find((ui) => ui.itemId === itemId);
        if (!userItem) {
            return { success: false, error: 'Vous ne possédez pas cet item' };
        }

        if (!userItem.equipped) {
            return { success: false, error: "Cet item n'est pas équipé" };
        }

        try {
            await this.userModel.updateOne({ _id: userId, 'shopItems.itemId': itemId }, { $set: { 'shopItems.$.equipped': false } });

            if (item.category === 'characters') {
                let newAvatarId = 1;

                await this.userModel.updateOne({ _id: userId }, { $set: { avatar: 1 } });

                await this.chatroomService.updateMessageAuthorAvatar(user.username, newAvatarId, user.avatarCustom);
            }

            if (item.category === 'profilePicture') {
                // Retourner à Profile1 par défaut
                let newProfilePictureId = 1;

                await this.userModel.updateOne({ _id: userId }, { $set: { profilePicture: 1 } });

                await this.chatroomService.updateMessageAuthorProfilePicture(user.username, newProfilePictureId, user.profilePictureCustom);
            }

            return { success: true };
        } catch (error) {
            console.error('Erreur lors du déséquipement:', error);
            return { success: false, error: 'Erreur serveur lors du déséquipement' };
        }
    }

    getShopCatalog(): ShopItem[] {
        return this.shopCatalog;
    }

    async getCatalogWithUserStatus(userId: string): Promise<ShopItem[]> {
        if (!userId || userId === 'undefined') {
            console.error('getCatalogWithUserStatus: userId is invalid:', userId);
            return this.shopCatalog.map((item) => ({ ...item, owned: false, equipped: false, canPurchase: true }));
        }

        const user = await this.userModel.findById(userId).select('shopItems stats');
        if (!user) {
            return this.shopCatalog.map((item) => ({ ...item, owned: false, equipped: false, canPurchase: true }));
        }

        const userItems = user.shopItems || [];
        const userLevel = user.stats?.level || 1;
        const userChallengesCompleted = user.stats?.challengesCompleted || 0;
        return this.shopCatalog.map((item) => {
            const userItem = userItems.find((ui) => ui.itemId === item.id);
            const canPurchase = (!item.levelRequired || userLevel >= item.levelRequired) && (!item.ChallengeRequired || userChallengesCompleted >= item.ChallengeRequired);
            return {
                ...item,
                owned: !!userItem,
                equipped: userItem?.equipped || false,
                canPurchase,
                userLevel,
                userChallengesCompleted
            };
        });
    }

    getItemById(itemId: string): ShopItem | undefined {
        return this.shopCatalog.find((item) => item.id === itemId);
    }

    getItemsByCategory(category: string): ShopItem[] {
        return this.shopCatalog.filter((item) => item.category === category);
    }

    private mapShopItemToAvatar(itemId: string): number | null {
        const mapping: { [key: string]: number } = {
            avatar_1: 13,
            avatar_2: 14,
            avatar_3: 15,
            avatar_4: 16,
            avatar_5: 17,
        };

        return mapping[itemId] || null;
    }

    private mapShopItemToProfilePicture(itemId: string): number | null {
        const mapping: { [key: string]: number } = {
            profile_4: 4,
            profile_5: 5,
            profile_6: 6,
            profile_7: 7,
            profile_8: 8,
            profile_9: 9,
            profile_10: 10,
            profile_11: 11,
            profile_12: 12,
            profile_13: 13,
        };

        return mapping[itemId] || null;
    }

    async getUserItems(userId: string): Promise<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        if (!userId || userId === 'undefined') {
            console.error('getUserItems: userId is invalid:', userId);
            return [];
        }

        const user = await this.userModel.findById(userId).select('shopItems');
        return user?.shopItems || [];
    }

    async getUserItemsByUsername(username: string): Promise<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        if (!username) {
            console.error('getUserItemsByUsername: username is invalid:', username);
            return [];
        }

        const user = await this.userModel.findOne({ username }).select('shopItems');
        return user?.shopItems || [];
    }

    async unequipAllProfilePicturesForUser(userId: string): Promise<{ success: boolean; error?: string }> {
        if (!userId || userId === 'undefined') {
            console.error('unequipAllProfilePicturesForUser: userId is invalid:', userId);
            return { success: false, error: 'ID utilisateur invalide' };
        }

        try {
            const profilePictureItems = this.getItemsByCategory('profilePicture').map((item) => item.id);

            await this.userModel.updateOne(
                { _id: userId },
                { $set: { 'shopItems.$[elem].equipped': false } },
                { arrayFilters: [{ 'elem.itemId': { $in: profilePictureItems } }] },
            );

            return { success: true };
        } catch (error) {
            console.error('Erreur lors du déséquipement des photos de profil:', error);
            return { success: false, error: 'Erreur serveur lors du déséquipement' };
        }
    }

    async isProfilePictureFromEquippedShopItem(userId: string, profilePictureId: number): Promise<boolean> {
        if (!userId || userId === 'undefined') {
            return false;
        }

        try {
            const user = await this.userModel.findById(userId).select('shopItems');
            if (!user || !user.shopItems) return false;

            const equippedProfileItem = user.shopItems.find((item) => {
                if (!item.equipped) return false;

                const shopItem = this.getItemById(item.itemId);
                if (!shopItem || shopItem.category !== 'profilePicture') return false;

                const mappedProfileId = this.mapShopItemToProfilePicture(item.itemId);
                return mappedProfileId === profilePictureId;
            });

            return !!equippedProfileItem;
        } catch (error) {
            console.error('Erreur lors de la vérification de la photo de profil équipée:', error);
            return false;
        }
    }
}
