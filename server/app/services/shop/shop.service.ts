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
            category: 'avatar',
            imagePath: 'assets/characters/13.png',
            description: 'Un brave assassin avec ses dagues rapides',
        },
        {
            id: 'avatar_2',
            name: 'Lancelot',
            price: 500,
            category: 'avatar',
            imagePath: 'assets/characters/14.png',
            description: 'Une puissante guerrière avec son épée et son bouclier',
        },
        {
            id: 'avatar_3',
            name: 'Legolas',
            price: 600,
            category: 'avatar',
            imagePath: 'assets/characters/15.png',
            description: 'Une archère agile et précise avec son arc et ses flèches',
        },
        {
            id: 'avatar_4',
            name: 'Aetherion',
            price: 1000,
            category: 'avatar',
            imagePath: 'assets/characters/16.png',
            description: 'Un dragon mystique avec des pouvoirs élémentaires',
        },
        {
            id: 'avatar_5',
            name: 'Luminova',
            price: 1500,
            category: 'avatar',
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
            levelRequired: 5,
        },
        {
            id: 'banner_4',
            name: 'Bannière Ténébreuse',
            price: 400,
            category: 'banner',
            imagePath: 'assets/banner/4.png',
            description: 'Une bannière qui symbolise les ténèbres',
            levelRequired: 10,
        },
        {
            id: 'banner_5',
            name: 'Bannière Glaciale',
            price: 500,
            category: 'banner',
            imagePath: 'assets/banner/5.png',
            description: 'Une bannière qui évoque la glace et la résilience',
            levelRequired: 15,
        },
        {
            id: 'banner_6',
            name: 'Bannière du Tonnerre',
            price: 600,
            category: 'banner',
            imagePath: 'assets/banner/6.png',
            description: 'Une bannière qui incarne la puissance du tonnerre',
            levelRequired: 20,
        },
        {
            id: 'banner_7',
            name: 'Bannière Supreme',
            price: 700,
            category: 'banner',
            imagePath: 'assets/banner/7.png',
            description: 'Une bannière suprême qui domine toutes les autres',
            levelRequired: 25,
        },

        // Sons (pour le futur)
        {
            id: 'sound_1',
            name: 'Pack Médiéval',
            price: 50,
            category: 'sound',
            imagePath: 'assets/icons/shield_icon.png',
            description: "Sons d'ambiance médiévale (À venir)",
        },
        {
            id: 'sound_2',
            name: 'Pack Fantastique',
            price: 60,
            category: 'sound',
            imagePath: 'assets/icons/fighting.png',
            description: 'Sons magiques et fantastiques (À venir)',
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

    async distributeGameWinnings(totalPrizePool: number, winners: string[], activePlayers: string[]): Promise<boolean> {
        if (totalPrizePool <= 0 || winners.length === 0) {
            return false;
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
                return true;
            } catch (error) {
                await session.abortTransaction();
                throw error;
            } finally {
                session.endSession();
            }
        } catch (error) {
            console.error('Error distributing game winnings:', error);
            return false;
        }
    }

    async distributeLastPlayerWinnings(totalPrizePool: number, lastPlayerId: string): Promise<boolean> {
        if (totalPrizePool <= 0) {
            return false;
        }

        try {
            await this.userModel.findByIdAndUpdate(lastPlayerId, { $inc: { virtualMoney: totalPrizePool } });
            return true;
        } catch (error) {
            console.error('Error distributing last player winnings:', error);
            return false;
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

            if (item.category === 'avatar') {
                const avatarId = this.mapShopItemToAvatar(itemId);
                if (avatarId) {
                    await this.userModel.updateOne({ _id: userId }, { $set: { avatar: avatarId } });

                    await this.chatroomService.updateMessageAuthorAvatar(user.username, avatarId, user.avatarCustom);
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

            if (item.category === 'avatar') {
                let newAvatarId = 1;

                await this.userModel.updateOne({ _id: userId }, { $set: { avatar: 1 } });

                await this.chatroomService.updateMessageAuthorAvatar(user.username, newAvatarId, user.avatarCustom);
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

        return this.shopCatalog.map((item) => {
            const userItem = userItems.find((ui) => ui.itemId === item.id);
            const canPurchase = !item.levelRequired || userLevel >= item.levelRequired;
            return {
                ...item,
                owned: !!userItem,
                equipped: userItem?.equipped || false,
                canPurchase,
                userLevel,
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
}
