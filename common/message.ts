export interface Message {
    author: string;
    text: string;
    timestamp: Date;
    // canonical room representation
    roomType?: 'game' | 'channel' | 'global';
    roomId?: string;

    // backward compatibility
    gameId?: string;
    channel?: string;
}
