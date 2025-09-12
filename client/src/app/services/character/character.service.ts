import { Injectable } from '@angular/core';
import { Character } from '@app/interfaces/character';
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
    ];

    customAvatarFile: File | null = null;
    customAvatarPreview: string | undefined;

    resetCharacterAvailability(): void {
        this.characters.forEach((character) => {
            character.isAvailable = true;
        });
    }

    getAvatarPreview(avatar: Avatar): string {
        return this.characters.find((character) => character.id === avatar)?.preview || '';
    }

    selectPredefinedAvatar(avatarId: Avatar) {
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

    removeCustomAvatar() {
        this.customAvatarFile = null;
        this.customAvatarPreview = undefined;
    }
    //
}
