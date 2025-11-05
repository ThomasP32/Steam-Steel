export enum ChatEvents {
    JoinChatRoom = 'joinChatRoom',
    PreviousMessages = 'previousMessages',
    Message = 'message',
    NewMessage = 'newMessage',
    DeleteMessage = 'deleteMessage',
    MessageDeleted = 'messageDeleted',
    MessageAuthorStatusUpdated = 'messageAuthorStatusUpdated',

    CreateChannel = 'createChannel',
    ChannelCreated = 'channelCreated',
    DeleteChannel = 'deleteChannel',
    ChannelDeleted = 'channelDeleted',
    JoinChannel = 'joinChannel',
    LeaveChannel = 'leaveChannel',
    ListChannels = 'listChannels',
    ChannelsList = 'channelsList',
}
