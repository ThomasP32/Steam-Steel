class Message {
  Message({
    required this.author,
    required this.text,
    required this.timestamp,
    required this.roomType,
    this.id,
    this.roomId,
    this.gameId,
    this.channel,
    this.authorAvatar,
    this.authorAvatarCustom,
    this.authorProfilePicture,
    this.authorProfilePictureCustom,
    this.authorStatus,
  });
  final String? id;
  final String author;
  final String text;
  final DateTime timestamp;

  final String roomType; // 'global', 'game', 'channel'
  final String? roomId;

  // backward compatibility
  final String? gameId;
  final String? channel;

  // Author info
  final int? authorAvatar;
  final String? authorAvatarCustom;
  final int? authorProfilePicture;
  final String? authorProfilePictureCustom;
  final String? authorStatus;
}
