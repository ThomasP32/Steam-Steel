import 'package:mobile/common/message.dart';
import 'package:mobile/services/socket_service.dart';

class ChatService {
  Message ensureMessage(dynamic raw) {
    if (raw is Message) return raw;
    if (raw is Map<String, dynamic>) return messageFromMap(raw);
    return Message(
      author: 'User',
      text: raw?.toString() ?? '',
      timestamp: DateTime.now(),
      roomType: 'global',
    );
  }

  Message messageFromMap(Map<String, dynamic> m) {
    var msgMap = m;
    if (m['message'] is Map<String, dynamic>) {
      msgMap = Map<String, dynamic>.from(m['message'] as Map);
    }

    DateTime ts;
    final dynamic raw =
        msgMap['timestamp'] ??
        msgMap['createdAt'] ??
        msgMap['created_at'] ??
        msgMap['created'] ??
        m['timestamp'];
    try {
      if (raw is int) {
        final ms = (raw.abs() <= 10000000000) ? raw * 1000 : raw;
        ts = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      } else if (raw is double) {
        final asInt = raw.toInt();
        final ms = (asInt.abs() <= 10000000000) ? asInt * 1000 : asInt;
        ts = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      } else if (raw is String) {
        final numVal = int.tryParse(raw);
        if (numVal != null) {
          final ms = (numVal.abs() <= 10000000000) ? numVal * 1000 : numVal;
          ts = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
        } else {
          final parsed = DateTime.tryParse(raw);
          ts = (parsed != null) ? parsed.toLocal() : DateTime.now().toLocal();
        }
      } else {
        ts = DateTime.now().toLocal();
      }
    } on Object catch (_) {
      ts = DateTime.now().toLocal();
    }

    final author =
        (msgMap['author'] as String?) ??
        (m['author'] as String?) ??
        (m['user']?['username'] as String?) ??
        'User';
    final text = (msgMap['text'] as String?) ?? (m['text'] as String?) ?? '';
    final roomType =
        (msgMap['roomType'] as String?) ??
        (m['roomType'] as String?) ??
        'global';
    final roomId = (msgMap['roomId'] as String?) ?? (m['roomId'] as String?);
    final gameId = (msgMap['gameId'] as String?) ?? (m['gameId'] as String?);
    final channel = (msgMap['channel'] as String?) ?? (m['channel'] as String?);
    // support MongoDB _id or id fields
    final id =
        (msgMap['_id'] as String?) ??
        (msgMap['id'] as String?) ??
        (m['_id'] as String?) ??
        (m['id'] as String?);

    final authorAvatar =
        (msgMap['authorAvatar'] as int?) ?? (m['authorAvatar'] as int?);
    final authorAvatarCustom =
        (msgMap['authorAvatarCustom'] as String?) ??
        (m['authorAvatarCustom'] as String?);
    final authorProfilePicture =
        (msgMap['authorProfilePicture'] as int?) ??
        (m['authorProfilePicture'] as int?);
    final authorProfilePictureCustom =
        (msgMap['authorProfilePictureCustom'] as String?) ??
        (m['authorProfilePictureCustom'] as String?);
    final authorStatus =
        (msgMap['authorStatus'] as String?) ?? (m['authorStatus'] as String?);

    return Message(
      id: id,
      author: author,
      text: text,
      timestamp: ts,
      roomType: roomType,
      roomId: roomId,
      gameId: gameId,
      channel: channel,
      authorAvatar: authorAvatar,
      authorAvatarCustom: authorAvatarCustom,
      authorProfilePicture: authorProfilePicture,
      authorProfilePictureCustom: authorProfilePictureCustom,
      authorStatus: authorStatus,
    );
  }

  Future<void> deleteMessage(Message message) async {
    final payload = {
      'roomName': message.roomId ?? 'global',
      'messageId': message.id,
      'author': message.author,
      'text': message.text,
      'timestamp': message.timestamp.toIso8601String(),
    };
    SocketService().send('deleteMessage', payload);
  }
}
