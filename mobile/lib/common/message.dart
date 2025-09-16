class Message {
  Message({
    required this.author,
    required this.text,
    required this.timestamp,
    required this.roomType,
    this.roomId,
    this.gameId,
    this.channel,
  });
  final String author;
  final String text;
  final DateTime timestamp;

  final String roomType; // 'global', 'game', 'channel'
  final String? roomId;

  // backward compatibility
  final String? gameId;
  final String? channel;
}
