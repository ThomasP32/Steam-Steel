import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { io, Socket } from 'socket.io-client';
import { environment } from 'src/environments/environment';

@Injectable({
    providedIn: 'root',
})
export class SocketService {
    public socket: Socket;
    private activeListeners: Map<string, number> = new Map();

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
            
            // Create a unique handler for this subscription
            const handler = (data: T) => {
                subscriber.next(data);
            };
            
            // Track listener creation
            const currentCount = this.activeListeners.get(eventName) || 0;
            this.activeListeners.set(eventName, currentCount + 1);
            
            this.socket.on(eventName, handler);
            
            return () => {
                this.socket.off(eventName, handler);
                
                const count = this.activeListeners.get(eventName) || 0;
                if (count > 0) {
                    this.activeListeners.set(eventName, count - 1);
                }
            };
        });
    }

    removeListener(eventName: string): void {
        if (!this.socket) {
            return;
        }
        this.socket.off(eventName);
        this.activeListeners.delete(eventName);
    }

    removeAllListeners(): void {
        if (!this.socket) {
            return;
        }
        this.socket.removeAllListeners();
        this.activeListeners.clear();
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
