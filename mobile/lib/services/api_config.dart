import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration helper.
///
/// Resolution precedence:
/// 1. dotenv (API_URL)
/// 2. dart-define (String.fromEnvironment('API_URL'))
/// 3. debug emulator fallback (10.0.2.2:3000) when running on Android emulator in debug
/// 4. production default (https://your-aws-api.amazonaws.com)
class ApiConfig {
  static const bool isDebug = kDebugMode;

  static String get baseUrl {
    final envValue = dotenv.env['API_URL'];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    const defineValue = String.fromEnvironment('API_URL');
    if (defineValue.isNotEmpty) return defineValue;

    // Debug emulator fallback
    if (isDebug) {
      return 'http://10.0.2.2:3000';
    }
    // Production default
    return 'http://ec2-35-183-61-112.ca-central-1.compute.amazonaws.com:3000';
  }
}
