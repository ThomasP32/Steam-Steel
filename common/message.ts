import { Avatar, ProfilePicture } from './game';

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

    // author information
    authorAvatar?: Avatar;
    authorAvatarCustom?: string;
    authorProfilePicture?: ProfilePicture;
    authorProfilePictureCustom?: string;
    authorStatus?: 'online' | 'offline' | 'ingame';
}
