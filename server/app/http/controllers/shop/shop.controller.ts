import { Body, Controller, Get, HttpException, HttpStatus, Param, Post } from '@nestjs/common';
import { ShopService } from '../../../services/shop/shop.service';

@Controller('shop')
export class ShopController {
    constructor(private readonly shopService: ShopService) {
        this.shopService = shopService;
    }

    @Get('money/:userId')
    async getUserMoney(@Param('userId') userId: string): Promise<number> {
        const money = await this.shopService.getUserMoney(userId);
        if (money === null) {
            throw new HttpException('User not found', HttpStatus.NOT_FOUND);
        }
        return money;
    }

    @Post('check-afford')
    async checkAfford(@Body() body: { userId: string; amount: number }): Promise<{ canAfford: boolean }> {
        const canAfford = await this.shopService.canAfford(body.userId, body.amount);
        return { canAfford };
    }

    @Get('catalog')
    async getCatalog() {
        return this.shopService.getShopCatalog();
    }

    @Get('catalog/:userId')
    async getCatalogWithUserStatus(@Param('userId') userId: string) {
        return this.shopService.getCatalogWithUserStatus(userId);
    }

    @Get('user-items/:userId')
    async getUserItems(@Param('userId') userId: string) {
        return this.shopService.getUserItems(userId);
    }

    @Get('user-items-by-username/:username')
    async getUserItemsByUsername(@Param('username') username: string) {
        return this.shopService.getUserItemsByUsername(username);
    }

    @Post('purchase')
    async purchaseItem(@Body() body: { userId: string; itemId: string }) {
        return this.shopService.purchaseItem(body.userId, body.itemId);
    }

    @Post('equip')
    async equipItem(@Body() body: { userId: string; itemId: string }) {
        return this.shopService.equipItem(body.userId, body.itemId);
    }

    @Post('unequip')
    async unequipItem(@Body() body: { userId: string; itemId: string }) {
        return this.shopService.unequipItem(body.userId, body.itemId);
    }
}
