import 'package:flutter/foundation.dart';

class DebugLogger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag] ' : '';
      debugPrint('$tagStr$message');
    }
  }
}
