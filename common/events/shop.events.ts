export enum ShopEvents {
    UserMoneyUpdated = 'userMoneyUpdated',
    BuyItem = 'buyItem',
    EquipItem = 'equipItem',
}

export interface ShopItem {
    id: string;
    name: string;
    price: number;
    category: 'characters' | 'banner' | 'sound' | 'profilePicture';
    imagePath: string;
    description: string;
    owned?: boolean;
    equipped?: boolean;
    levelRequired?: number;
    canPurchase?: boolean;
    userLevel?: number;
    ChallengeRequired?: number;
    userChallengesCompleted?: number;
}
