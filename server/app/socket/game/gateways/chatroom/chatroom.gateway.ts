import { ChatroomService } from '@app/services/chatroom/chatroom.service';
import { ChatEvents } from '@common/events/chat.events';
import { Message } from '@common/message';
import { Inject } from '@nestjs/common';
import { SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ namespace: '/game', cors: { origin: '*' } })
export class ChatRoomGateway {
    @WebSocketServer() server: Server;

    @Inject(ChatroomService) private readonly chatroomService: ChatroomService;

    @SubscribeMessage(ChatEvents.JoinChatRoom)
    async handleJoinRoom(client: Socket, roomId: string) {
        client.join(roomId);
        const existingMessages = await this.chatroomService.getMessages(roomId);
        this.server.to(roomId).emit(ChatEvents.PreviousMessages, existingMessages);
    }

    @SubscribeMessage(ChatEvents.Message)
    async handleMessage(client: Socket, data: { roomName: string; message: Message }) {
        const saved = await this.chatroomService.addMessage(data.roomName, data.message);
        const toEmit = saved ?? data.message;
        this.server.to(data.roomName).emit(ChatEvents.NewMessage, toEmit);
    }

    @SubscribeMessage(ChatEvents.DeleteMessage)
    async handleDeleteMessage(
        client: Socket,
        payload: { roomName?: string; messageId?: string; author?: string; text?: string; timestamp?: string },
    ) {
        const ok = await this.chatroomService.deleteMessage({
            messageId: payload.messageId,
            author: payload.author,
            text: payload.text,
            timestamp: payload.timestamp,
        });
        if (ok) {
            if (payload.roomName) {
                this.server.to(payload.roomName).emit(ChatEvents.MessageDeleted, {
                    messageId: payload.messageId,
                    author: payload.author,
                    text: payload.text,
                    timestamp: payload.timestamp,
                });
            } else {
                this.server.emit(ChatEvents.MessageDeleted, {
                    messageId: payload.messageId,
                    author: payload.author,
                    text: payload.text,
                    timestamp: payload.timestamp,
                });
            }
        }
    }
}
