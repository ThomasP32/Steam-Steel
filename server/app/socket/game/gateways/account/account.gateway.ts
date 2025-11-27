import { FriendsService } from '@app/http/services/friends/friends.service';
import { JWT_SECRET } from '@common/constants';
import { Inject } from '@nestjs/common';
import { OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import * as jwt from 'jsonwebtoken';
import { Server, Socket } from 'socket.io';
import { UserService } from '../../../../http/services/user/user.service';
import { UserSocketService } from '../../../../services/user-socket/user-socket.service';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class AccountGateway implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit {
    @WebSocketServer() server: Server;
    @Inject(UserSocketService) private readonly userSocketSession: UserSocketService;

    constructor(
        private readonly userService: UserService,
        private readonly friendsService: FriendsService,
    ) {
        this.userService = userService;
        this.friendsService = friendsService;
    }

    afterInit() {
        this.server.setMaxListeners(25);
        this.server.on('connection', (socket: Socket) => {
            socket.setMaxListeners(25);
        });
    }

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
            if (this.server?.sockets?.sockets) {
                const oldSocket = this.server.sockets.sockets.get(oldSocketId);
                if (oldSocket && oldSocket.connected) {
                    client.emit('auth_error', 'Ce compte est déjà connecté ailleurs.');
                    client.disconnect();
                    return;
                }
            }
            this.userSocketSession.removeUser(userId);
        }

        this.userSocketSession.setUserSocket(userId, client.id);
    }

    async handleDisconnect(client: Socket) {
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
