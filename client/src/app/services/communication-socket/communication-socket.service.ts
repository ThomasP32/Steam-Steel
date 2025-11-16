import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { io, Socket } from 'socket.io-client';
import { environment } from 'src/environments/environment';

@Injectable({
    providedIn: 'root',
})
export class SocketService {
    public socket: Socket;

    connect() {
        const token = localStorage.getItem('authToken');
        if (this.socket) {
            this.socket.disconnect();
        }
        this.socket = io(environment.socketUrl, {
            transports: ['websocket'],
            auth: { token },
        });
        this.socket.connect();
    }

    isSocketAlive() {
        return this.socket && this.socket.connected;
    }

    sendMessage<T>(event: string, data?: T): void {
        if (!this.socket) {
            return;
        }
        this.socket.emit(event, data);
    }

    listen<T>(eventName: string): Observable<T> {
        return new Observable((subscriber) => {
            if (!this.socket) {
                return;
            }
            this.socket.on(eventName, (data: T) => {
                subscriber.next(data);
            });
        });
    }

    disconnect(): void {
        if (!this.socket) {
            return;
        }
        this.socket.disconnect();
    }

    async waitForConnection(timeoutMs: number = 1000): Promise<boolean> {
        if (this.isSocketAlive()) {
            return true;
        }
        if (!this.socket) {
            return false;
        }
        return new Promise((resolve) => {
            // Check if already connected before setting up listener
            if (this.socket.connected) {
                resolve(true);
                return;
            }
            const timeout = setTimeout(() => {
                resolve(this.isSocketAlive());
            }, timeoutMs);
            this.socket.once('connect', () => {
                clearTimeout(timeout);
                resolve(true);
            });
        });
    }
}
