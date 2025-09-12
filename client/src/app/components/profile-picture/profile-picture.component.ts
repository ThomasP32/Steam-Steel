import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CharacterService } from '@app/services/character/character.service';
import { Avatar } from '@common/game';

@Component({
    selector: 'app-profile-picture',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './profile-picture.component.html',
    styleUrls: ['./profile-picture.component.scss'],
})
export class ProfilePictureComponent {
    @Input() selectedAvatar: Avatar = Avatar.Avatar1;
    @Input() customAvatarPreview: string | undefined;
    @Output() selectedAvatarChange = new EventEmitter<Avatar>();
    @Output() customAvatarPreviewChange = new EventEmitter<string | undefined>();

    get avatars() {
        return this.characterService.characters;
    }

    constructor(public characterService: CharacterService) {}

    selectPredefinedAvatar(avatarId: Avatar) {
        this.selectedAvatar = avatarId;
        this.customAvatarPreview = undefined;
        this.selectedAvatarChange.emit(avatarId);
        this.customAvatarPreviewChange.emit(undefined);
        this.characterService.selectPredefinedAvatar(avatarId);
    }

    onAvatarFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files && input.files[0]) {
            const file = input.files[0];
            const reader = new FileReader();
            reader.onload = (e: any) => {
                this.customAvatarPreview = e.target.result;
                this.customAvatarPreviewChange.emit(this.customAvatarPreview);
                this.selectedAvatarChange.emit(this.selectedAvatar);
            };
            reader.readAsDataURL(file);
        }
    }

    removeCustomAvatar() {
        this.customAvatarPreview = undefined;
        this.customAvatarPreviewChange.emit(undefined);
        this.characterService.removeCustomAvatar();
    }
}
