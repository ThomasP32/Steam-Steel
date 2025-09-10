import { Injectable } from '@nestjs/common';

@Injectable()
export class UserSocketService {
    private connectedUsers = new Map<string, string>();

    setUserSocket(userId: string, socketId: string) {
        this.connectedUsers.set(userId, socketId);
    }

    getSocketId(userId: string): string | undefined {
        return this.connectedUsers.get(userId);
    }

    removeUser(userId: string) {
        this.connectedUsers.delete(userId);
    }

    getUserIdBySocket(socketId: string): string | undefined {
        for (const [userId, sId] of this.connectedUsers.entries()) {
            if (sId === socketId) return userId;
        }
        return undefined;
    }
}
