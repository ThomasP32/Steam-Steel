import { Avatar } from '@common/game';

export interface Character {
    id: Avatar;
    image: string;
    preview: string;
    isAvailable: boolean;
    isShopAvatar?: boolean; // Indique si c'est un avatar de boutique
    shopItemId?: string; // ID de l'item dans le catalogue de boutique
}
