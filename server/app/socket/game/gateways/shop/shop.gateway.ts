import { ShopEvents } from '@common/events/shop.events';
import { Inject } from '@nestjs/common';
import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';
import { ShopService } from '../../../../services/shop/shop.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';

@WebSocketGateway({ namespace: '/game', cors: true })
export class ShopGateway {
    @WebSocketServer() server: Server;

    constructor(
        private readonly shopService: ShopService,
        @Inject(UserSocketService) private readonly userSocketService: UserSocketService,
    ) {
        this.shopService = shopService;
        this.userSocketService = userSocketService;
    }

    async notifyMoneyUpdate(userId: string): Promise<void> {
        const money = await this.shopService.getUserMoney(userId);
        if (money !== null) {
            const socketId = this.userSocketService.getSocketId(userId);
            if (socketId) {
                this.server.to(socketId).emit(ShopEvents.UserMoneyUpdated, money);
                console.log(`[ShopGateway] Money update sent to user ${userId} (socket: ${socketId}): ${money}`);
            }
        }
    }
}
