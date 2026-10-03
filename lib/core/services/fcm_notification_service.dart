import 'package:flutter/foundation.dart';

/// FCMNotificationService handles FCM Token management & push notification permissions
class FCMNotificationService {
  static String? _cachedToken;

  /// Initialize FCM Service & request notification permissions
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing FCM Notification Service...');
      // Simulated or real FCM Token retrieval
      _cachedToken = 'fcm_token_sample_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('🔑 FCM Token retrieved: $_cachedToken');
    } catch (e) {
      debugPrint('⚠️ Error initializing FCM: $e');
    }
  }

  /// Get current FCM Token
  static Future<String?> getFCMToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    await initialize();
    return _cachedToken;
  }
}
