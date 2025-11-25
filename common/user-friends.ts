export enum UserStatus {
    Online = 'online',
    Offline = 'offline',
    InGame = 'ingame',
}

export enum FriendRequestStatus {
    Pending = 'pending',
    Accepted = 'accepted',
    Rejected = 'rejected',
}

export interface Friend {
    username: string;
    status: UserStatus;
    avatar?: number | string;
    avatarCustom?: string;
    profilePicture?: number | string;
    profilePictureCustom?: string;
}

export interface FriendRequest {
    from: string;
    to: string;
    status: FriendRequestStatus;
}
