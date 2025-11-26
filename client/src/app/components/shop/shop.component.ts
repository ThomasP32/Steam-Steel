import { CommonModule } from '@angular/common';
import { Component, EventEmitter, OnDestroy, OnInit, Output } from '@angular/core';
import { ShopEvents, ShopItem } from '@common/events/shop.events';
import { Subscription } from 'rxjs';
import { AuthService } from '../../services/auth/auth.service';
import { CharacterService } from '../../services/character/character.service';
import { SocketService } from '../../services/communication-socket/communication-socket.service';
import { ProfilePictureService } from '../../services/profile-picture/profile-picture.service';
import { ShopHttpService } from '../../services/shop-http/shop-http.service';
import { VirtualMoneyComponent } from '../virtual-money/virtual-money.component';

@Component({
    selector: 'app-shop',
    standalone: true,
    imports: [CommonModule, VirtualMoneyComponent],
    templateUrl: './shop.component.html',
    styleUrl: './shop.component.scss',
})
export class ShopComponent implements OnInit, OnDestroy {
    @Output() closed = new EventEmitter<void>();

    currentMoney = 0;
    selectedCategory = 'characters';
    private subscription: Subscription = new Subscription();

    allItems: ShopItem[] = [];
    userItems: { itemId: string; equipped: boolean; purchaseDate: Date }[] = [];

    categories = [
        { id: 'characters', name: 'Personnages', icon: '👤' },
        { id: 'profilePicture', name: 'Photo de profil', icon: '📸' },
        { id: 'banner', name: 'Bannières', icon: '🏳️' },
        { id: 'sound', name: 'Musique', icon: '🔊' },
    ];

    constructor(
        private readonly socketService: SocketService,
        private readonly authService: AuthService,
        private readonly shopHttpService: ShopHttpService,
        private readonly characterService: CharacterService,
        private readonly profilePictureService: ProfilePictureService,
    ) {
        this.socketService = socketService;
        this.authService = authService;
        this.shopHttpService = shopHttpService;
        this.characterService = characterService;
        this.profilePictureService = profilePictureService;
    }

    async ngOnInit(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();

            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;
            if (!user || !userId) {
                console.error('ID utilisateur introuvable dans la réponse:', userInfo);
                return;
            }
            this.currentMoney = user.virtualMoney || 0;

            await this.profilePictureService.refreshProfilePictures();

            await this.loadShopData(userId);

            await this.syncProfilePictureEquipState();
        } catch (error) {
            console.error("Erreur lors de la récupération de l'utilisateur:", error);
        }

        this.subscription.add(
            this.socketService.listen<number>(ShopEvents.UserMoneyUpdated).subscribe((money) => {
                this.currentMoney = money;
            }),
        );
    }

    private async loadShopData(userId: string): Promise<void> {
        try {
            const catalog = await this.shopHttpService.getCatalogWithUserStatus(userId).toPromise();
            if (catalog) {
                this.allItems = catalog;
            }

            const userItems = await this.shopHttpService.getUserItems(userId).toPromise();
            if (userItems) {
                this.userItems = userItems;
            }

            await this.syncProfilePictureEquipState();
        } catch (error) {
            console.error('Erreur lors du chargement des données de la boutique:', error);
            this.allItems = [];
        }
    }

    private async syncProfilePictureEquipState(): Promise<void> {
        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;

            if (!user) return;

            const currentProfilePicture = user.profilePicture;
            if (!currentProfilePicture) return;

            const profilePictureItems = this.allItems.filter((item) => item.category === 'profilePicture');

            profilePictureItems.forEach((item) => {
                const profileNumber = parseInt(item.id.replace('profile_', ''));

                if (profileNumber === currentProfilePicture) {
                    if (item.owned && !item.equipped) {
                        item.equipped = true;
                    }
                } else {
                    if (item.equipped) {
                        item.equipped = false;
                    }
                }
            });
        } catch (error) {
            console.error('Erreur lors de la synchronisation des photos de profil:', error);
        }
    }

    ngOnDestroy(): void {
        this.subscription.unsubscribe();
    }

    selectCategory(categoryId: string): void {
        this.selectedCategory = categoryId;
    }

    getCurrentCategory() {
        return this.categories.find((cat) => cat.id === this.selectedCategory) || this.categories[0];
    }

    getCurrentCategoryItems(): ShopItem[] {
        return this.allItems.filter((item) => item.category === this.selectedCategory);
    }

    canAfford(item: ShopItem): boolean {
        const hasEnoughMoney = this.currentMoney >= item.price && !item.owned;
        const hasRequiredLevel = !item.levelRequired || item.canPurchase !== false;
        return hasEnoughMoney && hasRequiredLevel;
    }

    async buyItem(item: ShopItem): Promise<void> {
        if (!this.canAfford(item)) {
            return;
        }

        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            const result = await this.shopHttpService.purchaseItem(userId, item.id).toPromise();

            if (result?.success) {
                item.owned = true;
                if (result.newBalance !== undefined) {
                    this.currentMoney = result.newBalance;
                }
                console.log('Achat réussi:', item.name);

                if (item.category === 'characters') {
                    await this.characterService.refreshAvatars();
                }

                if (item.category === 'profilePicture') {
                    await this.profilePictureService.refreshProfilePictures();
                }
            } else {
                console.error("Erreur d'achat:", result?.error);
            }
        } catch (error) {
            console.error("Erreur lors de l'achat:", error);
        }
    }

    async equipItem(item: ShopItem): Promise<void> {
        if (!item.owned) {
            return;
        }

        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!user || !userId) {
                console.error("ID utilisateur introuvable pour l'équipement:", userInfo);
                return;
            }

            const result = await this.shopHttpService.equipItem(userId, item.id).toPromise();

            if (result?.success) {
                this.allItems.filter((i) => i.category === item.category && i.id !== item.id).forEach((i) => (i.equipped = false));

                item.equipped = true;

                console.log('Équipement réussi:', item.name);

                if (item.category === 'characters') {
                    await this.characterService.refreshAvatars();
                }

                if (item.category === 'profilePicture') {
                    await this.profilePictureService.refreshProfilePictures();
                    await this.loadShopData(userId);
                }
            } else {
                console.error("Erreur d'équipement:", result?.error);
            }
        } catch (error) {
            console.error("Erreur lors de l'équipement:", error);
        }
    }

    async unequipItem(item: ShopItem): Promise<void> {
        if (!item.equipped) {
            return;
        }

        try {
            const userInfo = await this.authService.getUserInfo();
            const user = userInfo?.user || userInfo?.body?.user || userInfo;
            const userId = user?._id || user?.id;

            if (!user || !userId) {
                console.error('ID utilisateur introuvable pour le déséquipement:', userInfo);
                return;
            }

            const result = await this.shopHttpService.unequipItem(userId, item.id).toPromise();

            if (result?.success) {
                item.equipped = false;

                console.log('Déséquipement réussi:', item.name);

                if (item.category === 'characters') {
                    await this.characterService.refreshAvatars();
                }

                if (item.category === 'profilePicture') {
                    await this.profilePictureService.refreshProfilePictures();
                    // Recharger les données du shop pour synchroniser l'état
                    await this.loadShopData(userId);
                }
            } else {
                console.error('Erreur de déséquipement:', result?.error);
            }
        } catch (error) {
            console.error('Erreur lors du déséquipement:', error);
        }
    }

    closeShop(): void {
        this.closed.emit();
    }

    onOverlayClick(event: MouseEvent): void {
        if (event.target === event.currentTarget) {
            this.closeShop();
        }
    }

    onImageError(event: Event): void {
        const target = event.target as HTMLImageElement;
        target.style.display = 'none';
        target.parentElement!.style.backgroundColor = '#666';
        target.parentElement!.style.border = '2px dashed #999';
        target.parentElement!.innerHTML =
            '<div style="display: flex; align-items: center; justify-content: center; height: 80px; color: #ccc; font-size: 12px;">Image non trouvée</div>';
    }
}
