import 'package:flutter/foundation.dart';

/// FCMNotificationService handles FCM Token management & push notification credentials
class FCMNotificationService {
  static String? _cachedToken;

  /// Set or update real device FCM Token
  static void setCustomToken(String token) {
    if (token.isNotEmpty) {
      _cachedToken = token.trim();
      debugPrint('🔑 FCM Token updated to: $_cachedToken');
    }
  }

  /// Initialize FCM Service
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 FCM Notification Service initialized.');
    } catch (e) {
      debugPrint('⚠️ Error initializing FCM: $e');
    }
  }

  /// Get current FCM Token
  static Future<String?> getFCMToken() async {
    return _cachedToken;
  }
}
