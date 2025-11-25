import { ProfilePicture } from '@common/game';

export interface ProfilePictureData {
    id: ProfilePicture;
    image: string;
    preview: string;
    isAvailable: boolean;
    isShopProfile?: boolean;
    shopItemId?: string;
}
