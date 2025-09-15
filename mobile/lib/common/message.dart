class Message {
  Message({
    required this.author,
    required this.text,
    required this.timestamp,
    required this.gameId,
  });
  final String author;
  final String text;
  final DateTime timestamp;
  final String gameId;
}
