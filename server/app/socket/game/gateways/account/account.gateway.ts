import { Inject } from '@nestjs/common';
import { OnGatewayConnection, OnGatewayDisconnect, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import * as jwt from 'jsonwebtoken';
import { Server, Socket } from 'socket.io';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';
import { JWT_SECRET } from '@common/constants';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class AccountGateway implements OnGatewayConnection, OnGatewayDisconnect {
    
    @WebSocketServer() server: Server;
    @Inject(UserSocketService) private readonly userSocketSession: UserSocketService;

    async handleConnection(client: Socket) {
        const token = client.handshake.auth.token;
        const userId = await this.verifyToken(token);
       
        if (!userId) {
            client.emit('auth_error', 'Authentification échouée');
            client.disconnect();
            return;
        }
        (client as any).userId = userId;
        const oldSocketId = this.userSocketSession.getSocketId(userId);
        if (oldSocketId && oldSocketId !== client.id) {
            client.emit('auth_error', 'Ce compte est déjà connecté ailleurs.');
            client.disconnect();
            return;
        }
        this.userSocketSession.setUserSocket(userId, client.id);
    }

    handleDisconnect(client: Socket) {
        const userId = (client as any).userId;
        if (userId) {
            const currentSocketId = this.userSocketSession.getSocketId(userId);
            if (currentSocketId === client.id) {
                this.userSocketSession.removeUser(userId);
            } 
        } 
    }

    async verifyToken(token: string): Promise<string | null> {
        try {
            const payload = jwt.verify(token, JWT_SECRET) as { userId: string };
            return payload.userId;
        } catch {
            return null;
        }
    }
}
