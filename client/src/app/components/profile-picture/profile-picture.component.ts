import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { ProfilePictureData } from '@app/interfaces/profile-picture';
import { ProfilePictureService } from '@app/services/profile-picture/profile-picture.service';
import { ProfilePicture } from '@common/game';

@Component({
    selector: 'app-profile-picture',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './profile-picture.component.html',
    styleUrls: ['./profile-picture.component.scss'],
})
export class ProfilePictureComponent implements OnInit {
    @Input() selectedProfilePicture: ProfilePicture = ProfilePicture.Profile1;
    @Input() customProfilePicturePreview: string | undefined;
    @Input() showOnlyFree: boolean = false;
    @Output() selectedProfilePictureChange = new EventEmitter<ProfilePicture>();
    @Output() customProfilePicturePreviewChange = new EventEmitter<string | undefined>();

    allProfilePictures: ProfilePictureData[] = [];
    userOwnedItems: { itemId: string; equipped: boolean }[] = [];

    get profilePictures() {
        if (this.showOnlyFree) {
            return this.allProfilePictures.filter((profile) => !profile.isShopProfile);
        }
        return this.allProfilePictures;
    }

    constructor(public profilePictureService: ProfilePictureService) {
        this.profilePictureService = profilePictureService;
    }

    async ngOnInit(): Promise<void> {
        this.allProfilePictures = this.profilePictureService.getAllProfilePictureData();
        this.userOwnedItems = await this.profilePictureService.getUserOwnedItems();
    }

    isSelected(profilePictureId: ProfilePicture): boolean {
        return this.selectedProfilePicture === profilePictureId && !this.customProfilePicturePreview;
    }

    isShopProfileOwned(profilePicture: ProfilePictureData): boolean {
        if (!profilePicture.isShopProfile || !profilePicture.shopItemId) {
            return true;
        }
        return this.userOwnedItems.some((item) => item.itemId === profilePicture.shopItemId);
    }

    canSelectProfile(profilePicture: ProfilePictureData): boolean {
        return !profilePicture.isShopProfile || this.isShopProfileOwned(profilePicture);
    }

    async selectPredefinedProfile(profilePictureId: ProfilePicture) {
        const selectedProfile = this.allProfilePictures.find((profile) => profile.id === profilePictureId);

        if (selectedProfile && !this.canSelectProfile(selectedProfile)) {
            return;
        }

        this.selectedProfilePicture = profilePictureId;
        this.customProfilePicturePreview = undefined;
        this.selectedProfilePictureChange.emit(profilePictureId);
        this.customProfilePicturePreviewChange.emit(undefined);
        this.profilePictureService.selectPredefinedProfile();

        if (selectedProfile && !selectedProfile.isShopProfile) {
            await this.profilePictureService.unequipShopProfiles();
        } else if (selectedProfile && selectedProfile.isShopProfile) {
            await this.profilePictureService.clearCustomProfile();
        }
    }

    async onProfileFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files && input.files[0]) {
            const file = input.files[0];
            const reader = new FileReader();
            reader.onload = async (e: any) => {
                this.customProfilePicturePreview = e.target.result;
                this.customProfilePicturePreviewChange.emit(this.customProfilePicturePreview);
                this.selectedProfilePictureChange.emit(this.selectedProfilePicture);
                await this.profilePictureService.unequipShopProfiles();
            };
            reader.readAsDataURL(file);
        }
    }

    async removeCustomProfile() {
        this.customProfilePicturePreview = undefined;
        this.customProfilePicturePreviewChange.emit(undefined);
        this.profilePictureService.removeCustomProfile();
    }
}
