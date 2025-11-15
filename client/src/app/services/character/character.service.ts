import { Injectable } from '@angular/core';
import { Character } from '@app/interfaces/character';
import { AuthService } from '@app/services/auth/auth.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { Avatar } from '@common/game';
@Injectable({
    providedIn: 'root',
})
export class CharacterService {
    characters: Character[] = [
        {
            id: Avatar.Avatar1,
            image: './assets/characters/1.png',
            preview: './assets/previewcharacters/1_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar2,
            image: './assets/characters/2.png',
            preview: './assets/previewcharacters/2_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar3,
            image: './assets/characters/3.png',
            preview: './assets/previewcharacters/3_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar4,
            image: './assets/characters/4.png',
            preview: './assets/previewcharacters/4_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar5,
            image: './assets/characters/5.png',
            preview: './assets/previewcharacters/5_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar6,
            image: './assets/characters/6.png',
            preview: './assets/previewcharacters/6_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar7,
            image: './assets/characters/7.png',
            preview: './assets/previewcharacters/7_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar8,
            image: './assets/characters/8.png',
            preview: './assets/previewcharacters/8_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar9,
            image: './assets/characters/9.png',
            preview: './assets/previewcharacters/9_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar10,
            image: './assets/characters/10.png',
            preview: './assets/previewcharacters/10_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar11,
            image: './assets/characters/11.png',
            preview: './assets/previewcharacters/11_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar12,
            image: './assets/characters/12.png',
            preview: './assets/previewcharacters/12_preview.png',
            isAvailable: true,
        },
        {
            id: Avatar.Avatar13,
            image: './assets/characters/13.png',
            preview: './assets/previewcharacters/13_preview.png',
            isAvailable: true,
            isShopAvatar: true,
            shopItemId: 'avatar_1',
        },
        {
            id: Avatar.Avatar14,
            image: './assets/characters/14.png',
            preview: './assets/previewcharacters/14_preview.png',
            isAvailable: true,
            isShopAvatar: true,
            shopItemId: 'avatar_2',
        },
        {
            id: Avatar.Avatar15,
            image: './assets/characters/15.png',
            preview: './assets/previewcharacters/15_preview.png',
            isAvailable: true,
            isShopAvatar: true,
            shopItemId: 'avatar_3',
        },
        {
            id: Avatar.Avatar16,
            image: './assets/characters/16.png',
            preview: './assets/previewcharacters/16_preview.png',
            isAvailable: true,
            isShopAvatar: true,
            shopItemId: 'avatar_4',
        },
        {
            id: Avatar.Avatar17,
            image: './assets/characters/17.png',
            preview: './assets/previewcharacters/17_preview.png',
            isAvailable: true,
            isShopAvatar: true,
            shopItemId: 'avatar_5',
        },
    ];

    private _availableAvatars: Character[] = [];
    private _isInitialized = false;

    customAvatarFile: File | null = null;
    customAvatarPreview: string | undefined;

    constructor(
        private authService: AuthService,
        private shopHttpService: ShopHttpService,
    ) {
        this.authService = authService;
        this.shopHttpService = shopHttpService; 
    }

    private async initializeAvatars(): Promise<void> {
        if (this._isInitialized) return;

        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            this._availableAvatars = this.characters.filter((char) => !char.isShopAvatar);

            if (userId) {
                const userItems = await this.shopHttpService.getUserItems(userId).toPromise();

                if (userItems) {
                    this.characters
                        .filter((char) => char.isShopAvatar)
                        .forEach((shopAvatar) => {
                            const hasItem = userItems.some((item) => item.itemId === shopAvatar.shopItemId);
                            if (hasItem) {
                                this._availableAvatars.push(shopAvatar);
                            }
                        });
                }
            }

            this._isInitialized = true;
        } catch (error) {
            console.error("Erreur lors de l'initialisation des avatars:", error);
            this._availableAvatars = this.characters.filter((char) => !char.isShopAvatar);
            this._isInitialized = true;
        }
    }

    async getAllAvatars(): Promise<Character[]> {
        await this.initializeAvatars();
        return this._availableAvatars;
    }

    getAllCharacters(): Character[] {
        return this.characters;
    }

    async getUserOwnedItems(): Promise<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (userId) {
                return await this.shopHttpService.getUserItems(userId).toPromise() || [];
            }
            return [];
        } catch (error) {
            console.error('Erreur lors du chargement des items utilisateur:', error);
            return [];
        }
    }

    async refreshAvatars(): Promise<void> {
        this._isInitialized = false;
        await this.initializeAvatars();
    }

    async isShopAvatarEquipped(avatarId: Avatar): Promise<boolean> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return false;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return false;

            const avatar = this.characters.find((char) => char.id === avatarId && char.isShopAvatar);
            if (!avatar || !avatar.shopItemId) return false;

            const avatarItem = userItems.find((item) => item.itemId === avatar.shopItemId && item.equipped);
            return !!avatarItem;
        } catch (error) {
            console.error("Erreur lors de la vérification de l'avatar équipé:", error);
            return false;
        }
    }

    async getEquippedShopAvatarId(): Promise<Avatar | null> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return null;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return null;

            const equippedItem = userItems.find((item) => item.equipped);
            if (!equippedItem) return null;

            const avatar = this.characters.find((char) => char.shopItemId === equippedItem.itemId && char.isShopAvatar);
            return avatar ? avatar.id : null;
        } catch (error) {
            console.error("Erreur lors de la récupération de l'avatar équipé:", error);
            return null;
        }
    }

    resetCharacterAvailability(): void {
        this.characters.forEach((character) => {
            character.isAvailable = true;
        });
    }

    getAvatarPreview(avatar: Avatar): string {
        return this.characters.find((character) => character.id === avatar)?.preview || '';
    }

    selectPredefinedAvatar() {
        this.customAvatarFile = null;
        this.customAvatarPreview = undefined;
    }

    onAvatarFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files && input.files[0]) {
            const file = input.files[0];
            this.customAvatarFile = file;
            const reader = new FileReader();
            reader.onload = (e: any) => {
                this.customAvatarPreview = e.target.result;
            };
            reader.readAsDataURL(file);
        }
    }

    async unequipShopAvatars(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return;

            const equippedAvatarItem = userItems.find((item) => item.equipped);
            if (equippedAvatarItem) {
                const shopAvatar = this.characters.find((char) => char.shopItemId === equippedAvatarItem.itemId && char.isShopAvatar);
                if (shopAvatar) {
                    await this.shopHttpService.unequipItem(userId, equippedAvatarItem.itemId).toPromise();
                }
            }
        } catch (error) {
            console.error("Erreur lors du déséquipement de l'avatar de shop:", error);
        }
    }

    async clearCustomAvatar(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;

            if (user) {
                await this.authService.updateAccount(user.email, user.username, user.avatar, undefined);
                this.customAvatarFile = null;
                this.customAvatarPreview = undefined;
            }
        } catch (error) {
            console.error("Erreur lors du vidage de l'avatar personnalisé:", error);
        }
    }

    removeCustomAvatar() {
        this.customAvatarFile = null;
        this.customAvatarPreview = undefined;
    }
}
