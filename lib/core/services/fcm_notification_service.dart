import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  /// Initialize FCM Service, request push notification permissions & fetch real FCM Token
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing FCM Notification Service...');

      // 1. Initialize Firebase App if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // 2. Request Notification Permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 FCM Notification Permission Status: ${settings.authorizationStatus}');

      // 3. Get Real FCM Device Token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        debugPrint('🔑 REAL Device FCM Token retrieved: $_cachedToken');
      }

      // 4. Listen to token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        debugPrint('🔑 FCM Token refreshed: $newToken');
      });
    } catch (e) {
      debugPrint('⚠️ Error initializing FCM (google-services.json pending): $e');
    }
  }

  /// Get current FCM Token
  static Future<String?> getFCMToken() async {
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      await initialize();
    }
    return _cachedToken;
  }
}
