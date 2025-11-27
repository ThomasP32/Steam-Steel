import { CommonModule } from '@angular/common';
import { Component, EventEmitter, OnInit, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AppComponent } from '@app/pages/app/app.component';
import { AudioService } from '@app/services/audio/audio.service';
import { AuthService } from '@app/services/auth/auth.service';
import { ProfilePictureService } from '@app/services/profile-picture/profile-picture.service';
import { ShopHttpService } from '@app/services/shop-http/shop-http.service';
import { ProfilePicture } from '@common/game';
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
    editProfilePicture: ProfilePicture;
    editCustomProfilePicturePreview: string | undefined;
    editMessage = '';
    equippedShopProfilePreview: string | undefined;
    selectedMusic = 'music2.mp3';
    ownsMinecraftMusic = false;

    @Output() closed = new EventEmitter<void>();
    @Output() deleteRequest = new EventEmitter<void>();

    constructor(
        private readonly appComponent: AppComponent,
        private readonly authService: AuthService,
        private readonly profilePictureService: ProfilePictureService,
        private readonly shopHttpService: ShopHttpService,
        public readonly audioService: AudioService,
    ) {
        this.appComponent = appComponent;
        this.authService = authService;
        this.profilePictureService = profilePictureService;
        this.shopHttpService = shopHttpService;
        this.audioService = audioService;
        this.editProfilePicture = ProfilePicture.Profile1;
    }

    get isDarkMode(): boolean {
        return this.appComponent.themeClass === 'theme-dark';
    }

    get themeIcon(): string {
        return this.isDarkMode ? 'light_mode' : 'dark_mode';
    }

    ngOnInit(): void {
        void this.loadUserInfo();
    }

    private async loadUserInfo(): Promise<void> {
        this.userInfo = await this.authService.getUserInfo();
        await this.resetEditFields();
        this.checkMusicOwnership();
        this.selectedMusic = this.audioService.equippedMusic || 'music2.mp3';
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

    logoutAccount(): void {
        this.authService.logout();
        this.closed.emit();
    }

    async resetEditFields() {
        if (this.userInfo?.user) {
            this.editEmail = this.userInfo.user.email;
            this.editUsername = this.userInfo.user.username;
            this.editProfilePicture = this.userInfo.user.profilePicture || ProfilePicture.Profile1;
            this.editCustomProfilePicturePreview = this.userInfo.user.profilePictureCustom;

            try {
                await this.profilePictureService.refreshProfilePictures();

                const equippedShopProfile = await this.profilePictureService.getEquippedShopProfileId();

                if (equippedShopProfile) {
                    this.editProfilePicture = equippedShopProfile;
                    const allProfiles = await this.profilePictureService.getAllProfilePictures();
                    const shopProfile = allProfiles.find((profile) => profile.id === equippedShopProfile);
                    this.equippedShopProfilePreview = shopProfile?.preview;
                    this.editCustomProfilePicturePreview = undefined;
                } else {
                    this.editProfilePicture = this.userInfo.user.profilePicture || ProfilePicture.Profile1;
                    this.equippedShopProfilePreview = undefined;
                }
            } catch (error) {
                console.error('Erreur lors de la récupération des items de boutique:', error);
                this.editProfilePicture = this.userInfo.user.profilePicture || ProfilePicture.Profile1;
                this.equippedShopProfilePreview = undefined;
            }
        }
        this.editMessage = '';
    }

    getProfilePicturePreview(profilePicture: ProfilePicture): string {
        return this.userInfo?.user?.profilePictureCustom || this.profilePictureService.getProfilePicturePreview(profilePicture);
    }

    async toggleTheme() {
        this.appComponent.toggleTheme();
    }

    enableEdit() {
        this.editMode = true;
        this.editMessage = '';
    }

    async saveEdit() {
        try {
            const allProfiles = await this.profilePictureService.getAllProfilePictures();
            const selectedProfile = allProfiles.find((profile) => profile.id === this.editProfilePicture);

            const result = await this.authService.updateAccount(
                this.editEmail,
                this.editUsername,
                undefined, // Keep old avatar for backward compatibility
                undefined, // Keep old avatarCustom for backward compatibility
                this.editProfilePicture,
                this.editCustomProfilePicturePreview,
            );

            if (result?.success === false) {
                this.editMessage = result?.message || 'Erreur lors de la modification.';
                return;
            }
            if (selectedProfile?.isShopProfile && selectedProfile.shopItemId && !this.editCustomProfilePicturePreview) {
                await this.shopHttpService.equipItem(this.userInfo.user._id, selectedProfile.shopItemId).toPromise();
                await this.profilePictureService.clearCustomProfile();
                this.editCustomProfilePicturePreview = undefined;
            }

            await this.profilePictureService.refreshProfilePictures();

            this.editMode = false;
            this.userInfo = await this.authService.getUserInfo();
            await this.resetEditFields();
            this.editMessage = 'Modifications enregistrées !';
        } catch (e: any) {
            console.error('Erreur lors de la sauvegarde:', e);
            this.editMode = true;
            this.editMessage = 'Erreur lors de la modification.';
        }
    }

    async cancelEdit() {
        this.editMode = false;
        await this.resetEditFields();
    }

    deleteAccount(): void {
        this.deleteRequest.emit();
    }

    toggleMusic(): void {
        this.audioService.musicEnabled = !this.audioService.isMusicEnabled;
    }

    toggleSoundEffects(): void {
        this.audioService.areSoundEffectsEnabled = !this.audioService.areSoundEffectsEnabled;
    }

    checkMusicOwnership(): void {
        if (this.userInfo?.user?.shopItems) {
            this.ownsMinecraftMusic = this.userInfo.user.shopItems.some((item: any) => item.itemId === 'sound_1');
        }
    }

    onMusicChange(): void {
        this.audioService.setEquippedMusic(this.selectedMusic);
    }
}
