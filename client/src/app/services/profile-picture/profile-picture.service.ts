import { Injectable } from '@angular/core';
import { ProfilePictureData } from '@app/interfaces/profile-picture';
import { AuthService } from '@app/services/auth/auth.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { ProfilePicture } from '@common/game';

@Injectable({
    providedIn: 'root',
})
export class ProfilePictureService {
    profilePictures: ProfilePictureData[] = [
        // Photos de profil gratuites par défaut (Profile1-3)
        {
            id: ProfilePicture.Profile1,
            image: './assets/profile/1.png',
            preview: './assets/profile/1.png',
            isAvailable: true,
        },
        {
            id: ProfilePicture.Profile2,
            image: './assets/profile/2.png',
            preview: './assets/profile/2.png',
            isAvailable: true,
        },
        {
            id: ProfilePicture.Profile3,
            image: './assets/profile/3.png',
            preview: './assets/profile/3.png',
            isAvailable: true,
        },
        // Photos de profil achetables dans le shop (Profile4-10)
        {
            id: ProfilePicture.Profile4,
            image: './assets/profile/4.png',
            preview: './assets/profile/4.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_4',
        },
        {
            id: ProfilePicture.Profile5,
            image: './assets/profile/5.png',
            preview: './assets/profile/5.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_5',
        },
        {
            id: ProfilePicture.Profile6,
            image: './assets/profile/6.png',
            preview: './assets/profile/6.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_6',
        },
        {
            id: ProfilePicture.Profile7,
            image: './assets/profile/7.png',
            preview: './assets/profile/7.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_7',
        },
        {
            id: ProfilePicture.Profile8,
            image: './assets/profile/8.png',
            preview: './assets/profile/8.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_8',
        },
        {
            id: ProfilePicture.Profile9,
            image: './assets/profile/9.png',
            preview: './assets/profile/9.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_9',
        },
        {
            id: ProfilePicture.Profile10,
            image: './assets/profile/10.png',
            preview: './assets/profile/10.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_10',
        },
        {
            id: ProfilePicture.Profile11,
            image: './assets/profile/11.png',
            preview: './assets/profile/11.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_11',
        },
        {
            id: ProfilePicture.Profile12,
            image: './assets/profile/12.png',
            preview: './assets/profile/12.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_12',
        },
        {
            id: ProfilePicture.Profile13,
            image: './assets/profile/13.png',
            preview: './assets/profile/13.png',
            isAvailable: false,
            isShopProfile: true,
            shopItemId: 'profile_13',
        },
    ];

    private _availableProfilePictures: ProfilePictureData[] = [];
    private _isInitialized = false;

    customProfilePictureFile: File | null = null;
    customProfilePicturePreview: string | undefined;

    constructor(
        private authService: AuthService,
        private shopHttpService: ShopHttpService,
    ) {
        this.authService = authService;
        this.shopHttpService = shopHttpService;
    }

    private async initializeProfilePictures(): Promise<void> {
        if (this._isInitialized) return;

        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            this._availableProfilePictures = this.profilePictures.filter((pic) => !pic.isShopProfile);

            if (userId) {
                const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
                if (userItems) {
                    this.profilePictures
                        .filter((pic) => pic.isShopProfile)
                        .forEach((shopProfile) => {
                            const hasItem = userItems.some((item) => item.itemId === shopProfile.shopItemId);
                            if (hasItem) {
                                this._availableProfilePictures.push(shopProfile);
                            }
                        });
                }
            }

            this._isInitialized = true;
        } catch (error) {
            console.error("Erreur lors de l'initialisation des photos de profil:", error);
            this._availableProfilePictures = this.profilePictures.filter((pic) => !pic.isShopProfile);
            this._isInitialized = true;
        }
    }

    async getAllProfilePictures(): Promise<ProfilePictureData[]> {
        await this.initializeProfilePictures();
        return this._availableProfilePictures;
    }

    getAllProfilePictureData(): ProfilePictureData[] {
        return this.profilePictures;
    }

    async getUserOwnedItems(): Promise<{ itemId: string; equipped: boolean; purchaseDate: Date }[]> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (userId) {
                return (await this.shopHttpService.getUserItems(userId).toPromise()) || [];
            }
            return [];
        } catch (error) {
            console.error('Erreur lors du chargement des items utilisateur:', error);
            return [];
        }
    }

    async refreshProfilePictures(): Promise<void> {
        this._isInitialized = false;
        this._availableProfilePictures = [];
        await this.initializeProfilePictures();
    }

    async isShopProfileEquipped(profileId: ProfilePicture): Promise<boolean> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return false;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return false;

            const profile = this.profilePictures.find((pic) => pic.id === profileId && pic.isShopProfile);
            if (!profile || !profile.shopItemId) return false;

            const profileItem = userItems.find((item) => item.itemId === profile.shopItemId && item.equipped);
            return !!profileItem;
        } catch (error) {
            console.error('Erreur lors de la vérification du profil équipé:', error);
            return false;
        }
    }

    async getEquippedShopProfileId(): Promise<ProfilePicture | null> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return null;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return null;

            // Chercher spécifiquement un item de photo de profil équipé
            const equippedProfileItem = userItems.find((item) => {
                if (!item.equipped) return false;

                // Vérifier que cet item correspond à une photo de profil du shop
                const profile = this.profilePictures.find((pic) => pic.shopItemId === item.itemId && pic.isShopProfile);
                return !!profile;
            });

            if (!equippedProfileItem) return null;

            const profile = this.profilePictures.find((pic) => pic.shopItemId === equippedProfileItem.itemId && pic.isShopProfile);
            console.log('Profil de shop équipé récupéré:', profile);
            return profile ? profile.id : null;
        } catch (error) {
            console.error('Erreur lors de la récupération du profil équipé:', error);
            return null;
        }
    }

    resetProfilePictureAvailability(): void {
        this.profilePictures.forEach((profile) => {
            profile.isAvailable = true;
        });
    }

    getProfilePicturePreview(profilePicture: ProfilePicture): string {
        return this.profilePictures.find((profile) => profile.id === profilePicture)?.preview || '';
    }

    selectPredefinedProfile() {
        this.customProfilePictureFile = null;
        this.customProfilePicturePreview = undefined;
    }

    onProfileFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files && input.files[0]) {
            const file = input.files[0];
            this.customProfilePictureFile = file;
            const reader = new FileReader();
            reader.onload = (e: any) => {
                this.customProfilePicturePreview = e.target.result;
            };
            reader.readAsDataURL(file);
        }
    }

    async unequipShopProfiles(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!userId) return;

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (!userItems) return;

            // Déséquiper tous les items de photos de profil équipés
            const equippedProfileItems = userItems.filter((item) => {
                if (!item.equipped) return false;

                // Vérifier que cet item correspond à une photo de profil du shop
                const shopProfile = this.profilePictures.find((pic) => pic.shopItemId === item.itemId && pic.isShopProfile);
                return !!shopProfile;
            });

            for (const equippedItem of equippedProfileItems) {
                const shopProfile = this.profilePictures.find((pic) => pic.shopItemId === equippedItem.itemId && pic.isShopProfile);
                if (shopProfile) {
                    await this.shopHttpService.unequipItem(userId, equippedItem.itemId).toPromise();
                    console.log('Profil de shop déséquipé:', shopProfile);
                }
            }
        } catch (error) {
            console.error('Erreur lors du déséquipement du profil de shop:', error);
        }
    }

    async clearCustomProfile(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;

            if (user) {
                await this.authService.updateAccount(user.email, user.username, user.profilePicture, undefined);
                this.customProfilePictureFile = null;
                this.customProfilePicturePreview = undefined;
            }
        } catch (error) {
            console.error('Erreur lors du vidage du profil personnalisé:', error);
        }
    }

    removeCustomProfile() {
        this.customProfilePictureFile = null;
        this.customProfilePicturePreview = undefined;
    }
}
