class JournalEntry {
  JournalEntry({
    required this.message,
    required this.timestamp,
    required this.playersInvolved,
  });
  final String message;
  final DateTime timestamp;
  final List<String> playersInvolved;
}
