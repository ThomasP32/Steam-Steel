import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { Character } from '@app/interfaces/character';
import { CharacterService } from '@app/services/character/character.service';
import { Avatar } from '@common/game';

@Component({
    selector: 'app-profile-picture',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './profile-picture.component.html',
    styleUrls: ['./profile-picture.component.scss'],
})
export class ProfilePictureComponent implements OnInit {
    @Input() selectedAvatar: Avatar = Avatar.Avatar1;
    @Input() customAvatarPreview: string | undefined;
    @Output() selectedAvatarChange = new EventEmitter<Avatar>();
    @Output() customAvatarPreviewChange = new EventEmitter<string | undefined>();

    allAvatars: Character[] = [];
    userOwnedItems: { itemId: string; equipped: boolean }[] = [];

    get avatars() {
        return this.allAvatars;
    }

    constructor(public characterService: CharacterService) {
        this.characterService = characterService;
    }

    async ngOnInit(): Promise<void> {
        this.allAvatars = this.characterService.getAllCharacters();
        this.userOwnedItems = await this.characterService.getUserOwnedItems();
    }

    isSelected(avatarId: Avatar): boolean {
        return this.selectedAvatar === avatarId && !this.customAvatarPreview;
    }

    isShopAvatarOwned(avatar: Character): boolean {
        if (!avatar.isShopAvatar || !avatar.shopItemId) {
            return true;
        }
        return this.userOwnedItems.some((item) => item.itemId === avatar.shopItemId);
    }

    canSelectAvatar(avatar: Character): boolean {
        return !avatar.isShopAvatar || this.isShopAvatarOwned(avatar);
    }

    async selectPredefinedAvatar(avatarId: Avatar) {
        const selectedAvatar = this.allAvatars.find((avatar) => avatar.id === avatarId);

        if (selectedAvatar && !this.canSelectAvatar(selectedAvatar)) {
            return;
        }

        this.selectedAvatar = avatarId;
        this.customAvatarPreview = undefined;
        this.selectedAvatarChange.emit(avatarId);
        this.customAvatarPreviewChange.emit(undefined);
        this.characterService.selectPredefinedAvatar();

        if (selectedAvatar && !selectedAvatar.isShopAvatar) {
            await this.characterService.unequipShopAvatars();
        } else if (selectedAvatar && selectedAvatar.isShopAvatar) {
            await this.characterService.clearCustomAvatar();
        }
    }

    async onAvatarFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files && input.files[0]) {
            const file = input.files[0];
            const reader = new FileReader();
            reader.onload = async (e: any) => {
                this.customAvatarPreview = e.target.result;
                this.customAvatarPreviewChange.emit(this.customAvatarPreview);
                this.selectedAvatarChange.emit(this.selectedAvatar);
                await this.characterService.unequipShopAvatars();
            };
            reader.readAsDataURL(file);
        }
    }

    async removeCustomAvatar() {
        this.customAvatarPreview = undefined;
        this.customAvatarPreviewChange.emit(undefined);
        this.characterService.removeCustomAvatar();
    }
}
