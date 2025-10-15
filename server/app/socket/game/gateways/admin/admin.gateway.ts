import { AdminEvents } from '@common/events/admin.events';
import { Injectable } from '@nestjs/common';
import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
@Injectable()
export class AdminGateway {
    @WebSocketServer()
    server: Server;

    notifyMapListUpdate(): void {
        this.server.emit(AdminEvents.MapListUpdated);
    }
}
