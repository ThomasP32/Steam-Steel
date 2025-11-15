import { CommonModule } from '@angular/common';
import { Component, EventEmitter, OnInit, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '@app/services/auth/auth.service';
import { CharacterService } from '@app/services/character/character.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { Avatar } from '@common/game';
import { ProfilePictureComponent } from '../profile-picture/profile-picture.component';
@Component({
    selector: 'app-account',
    standalone: true,
    imports: [CommonModule, FormsModule, ProfilePictureComponent],
    templateUrl: './account.component.html',
    styleUrls: ['./account.component.scss'],
})
export class AccountComponent implements OnInit {
    userInfo: any;
    editMode = false;
    editEmail = '';
    editUsername = '';
    editAvatar: Avatar;
    editCustomAvatarPreview: string | undefined;
    editMessage = '';
    equippedShopAvatarPreview: string | undefined;

    @Output() closed = new EventEmitter<void>();

    constructor(
        private readonly authService: AuthService,
        private readonly characterService: CharacterService,
        private readonly shopHttpService: ShopHttpService,
    ) {
        this.authService = authService;
        this.characterService = characterService;
        this.shopHttpService = shopHttpService;
        this.editAvatar = Avatar.Avatar1;
    }

    ngOnInit(): void {
        void this.loadUserInfo();
    }

    private async loadUserInfo(): Promise<void> {
        this.userInfo = await this.authService.getUserInfo();
        await this.resetEditFields();
    }

    formatAvgTime(seconds: number): string {
        if (isNaN(seconds) || seconds < 0) return 'N/A';
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}m ${secs}s`;
    }

    statutInFrench(): string {
        return this.userInfo?.user?.status === 'online' ? 'en ligne' : 'hors ligne';
    }

    async resetEditFields() {
        if (this.userInfo?.user) {
            this.editEmail = this.userInfo.user.email;
            this.editUsername = this.userInfo.user.username;
            this.editAvatar = this.userInfo.user.avatar;
            this.editCustomAvatarPreview = this.userInfo.user.avatarCustom;

            try {
                const equippedShopAvatar = await this.characterService.getEquippedShopAvatarId();

                if (equippedShopAvatar) {
                    this.editAvatar = equippedShopAvatar;
                    const allAvatars = await this.characterService.getAllAvatars();
                    const shopAvatar = allAvatars.find((avatar) => avatar.id === equippedShopAvatar);
                    this.equippedShopAvatarPreview = shopAvatar?.preview;
                    await this.characterService.clearCustomAvatar();
                } else {
                    this.editAvatar = this.userInfo.user.avatar;
                    this.equippedShopAvatarPreview = undefined;
                }
            } catch (error) {
                console.error('Erreur lors de la récupération des items de boutique:', error);
                this.editAvatar = this.userInfo.user.avatar;
                this.equippedShopAvatarPreview = undefined;
            }
        }
        this.editMessage = '';
    }

    getAvatarPreview(avatar: Avatar): string {
        return this.userInfo?.user?.avatarCustom || this.characterService.getAvatarPreview(avatar);
    }

    enableEdit() {
        this.editMode = true;
        this.editMessage = '';
    }

    async saveEdit() {
        try {
            const allAvatars = await this.characterService.getAllAvatars();
            const selectedAvatar = allAvatars.find((avatar) => avatar.id === this.editAvatar);

            if (selectedAvatar?.isShopAvatar && selectedAvatar.shopItemId && this.userInfo?.user?._id && !this.editCustomAvatarPreview) {
                await this.shopHttpService.equipItem(this.userInfo.user._id, selectedAvatar.shopItemId).toPromise();
                await this.characterService.clearCustomAvatar();
                await this.characterService.refreshAvatars();
                this.editCustomAvatarPreview = undefined;
            } else {
                await this.characterService.unequipShopAvatars();
            }

            const result = await this.authService.updateAccount(this.editEmail, this.editUsername, this.editAvatar, this.editCustomAvatarPreview);
            if (result?.success === false) {
                this.editMessage = result?.message || 'Erreur lors de la modification.';
                return;
            }
            this.editMode = false;
            this.userInfo = await this.authService.getUserInfo();
            this.resetEditFields();
            this.editMessage = 'Modifications enregistrées !';
        } catch (e: any) {
            this.editMode = true;
            this.editMessage = 'Erreur lors de la modification.';
        }
    }


    async cancelEdit() {
        this.editMode = false;
        await this.resetEditFields();
    }

    deleteAccount(): void {
        this.authService.deleteAccount().then(() => {
            this.authService.logout();
            this.closed.emit();
        });
    }
}
