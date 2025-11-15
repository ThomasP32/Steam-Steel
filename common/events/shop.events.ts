export enum ShopEvents {
    UserMoneyUpdated = 'userMoneyUpdated',
    BuyItem = 'buyItem',
    EquipItem = 'equipItem',
}

export interface ShopItem {
    id: string;
    name: string;
    price: number;
    category: 'avatar' | 'banner' | 'sound';
    imagePath: string;
    description: string;
    owned?: boolean;
    equipped?: boolean;
    levelRequired?: number;
    canPurchase?: boolean;
    userLevel?: number;
}
