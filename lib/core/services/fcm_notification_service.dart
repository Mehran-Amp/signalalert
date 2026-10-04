import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/notifications/services/notification_service.dart';
import '../../features/settings/services/sound_manager.dart';
import 'tts_service.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  debugPrint('⚡ [FCM Background] Received push message: ${message.messageId}');
  final title = message.notification?.title ?? message.data['title'] ?? '🚨 هشدار قیمت';
  final body = message.notification?.body ?? message.data['body'] ?? 'قیمت ارز به تارگت رسید!';
  final symbol = message.data['symbol'] ?? '';
  final priceStr = message.data['price'] ?? '';
  final note = message.data['note'] ?? '';

  // Show local notification with max priority alarm channel
  try {
    final notificationService = NotificationService();
    await notificationService.showCriticalAlert(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      soundName: message.data['sound'] ?? 'alarm_siren',
      soundEnabled: true,
      vibrationEnabled: true,
    );
  } catch (e) {
    debugPrint('⚠️ [FCM Background] Local notification error: $e');
  }

  // Vocalize speech via TTS if price/symbol is present
  try {
    final parsedPrice = double.tryParse(priceStr) ?? 0.0;
    final speechText = TtsService.buildAlertSpeech(
      symbol: symbol.isNotEmpty ? symbol : 'Price Alert',
      price: parsedPrice,
      customNote: note.isNotEmpty ? note : null,
    );
    await TtsService.instance.speak(text: speechText);
  } catch (_) {}
}

/// FCMNotificationService handles Firebase Cloud Messaging (FCM) & Device Token management
class FCMNotificationService {
  static String? _cachedToken;
  static String? _storageDir;
  static bool _firebaseInitialized = false;
  static bool _handlersRegistered = false;

  /// Initialize Firebase Core & Firebase Messaging to fetch real Google FCM Token
  static Future<void> initialize({String? storageDirectoryPath}) async {
    _storageDir = storageDirectoryPath;
    if (_storageDir == null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _storageDir = dir.path;
      } catch (_) {}
    }

    // 1. Try initializing Firebase Core (from google-services.json)
    try {
      await Firebase.initializeApp();
      _firebaseInitialized = true;
      debugPrint('🔥 Firebase Core initialized successfully on Android.');
    } catch (e) {
      debugPrint('ℹ️ Firebase Core init note: $e');
    }

    // 2. Register Background & Foreground Listeners if Firebase is active
    if (_firebaseInitialized && !_handlersRegistered) {
      _handlersRegistered = true;
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        final fcm = FirebaseMessaging.instance;
        // Request high-priority permissions
        await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: true,
          criticalAlert: true,
          provisional: false,
        );

        // Foreground push message listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 [FCM Foreground] Push received: ${message.notification?.title}');
          final title = message.notification?.title ?? message.data['title'] ?? '🚨 هشدار قیمت';
          final body = message.notification?.body ?? message.data['body'] ?? '';
          final symbol = message.data['symbol'] ?? '';
          final priceStr = message.data['price'] ?? '';
          final note = message.data['note'] ?? '';

          // 1. Show immediate high-importance banner with custom sound
          NotificationService().showCriticalAlert(
            id: message.messageId.hashCode,
            title: title,
            body: body,
            soundName: message.data['sound'] ?? 'alarm_siren',
            soundEnabled: true,
            vibrationEnabled: true,
          );

          // 2. Instant Voice Speech announcement
          final parsedPrice = double.tryParse(priceStr) ?? 0.0;
          final speechText = TtsService.buildAlertSpeech(
            symbol: symbol.isNotEmpty ? symbol : 'Price Alert',
            price: parsedPrice,
            customNote: note.isNotEmpty ? note : null,
          );
          TtsService.instance.enqueueSpeech(speechText);
        });

        final token = await fcm.getToken();
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          debugPrint('🔑 Real Google FCM Token received: $_cachedToken');
          await _saveTokenToDisk(token);

          // Listen for token updates
          fcm.onTokenRefresh.listen((newToken) {
            _cachedToken = newToken;
            _saveTokenToDisk(newToken);
            debugPrint('🔄 FCM Token refreshed: $newToken');
          });

          return;
        }
      } catch (e) {
        debugPrint('⚠️ Error retrieving real FCM Token from Google: $e');
      }
    }

    // 3. Fallback to cached token or persistent device ID
    if (_cachedToken == null) {
      final saved = await _loadTokenFromDisk();
      if (saved != null && saved.isNotEmpty) {
        _cachedToken = saved;
      } else {
        final newId = 'dev_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
        _cachedToken = newId;
        await _saveTokenToDisk(newId);
      }
    }
  }

  static Future<void> _saveTokenToDisk(String token) async {
    try {
      if (_storageDir != null) {
        final file = File('$_storageDir/device_token.txt');
        await file.writeAsString(token);
      }
    } catch (_) {}
  }

  static Future<String?> _loadTokenFromDisk() async {
    try {
      if (_storageDir != null) {
        final file = File('$_storageDir/device_token.txt');
        if (await file.exists()) {
          final content = (await file.readAsString()).trim();
          if (content.isNotEmpty) return content;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Set or update real device FCM Token manually
  static Future<void> setCustomToken(String token) async {
    if (token.isNotEmpty) {
      _cachedToken = token.trim();
      await _saveTokenToDisk(_cachedToken!);
      debugPrint('🔑 Custom Token updated to: $_cachedToken');
    }
  }

  /// Get current Device / FCM Token (attempts upgrade to real Google FCM token if currently on dev fallback)
  static Future<String> getFCMToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty && !_cachedToken!.startsWith('dev_')) {
      return _cachedToken!;
    }

    try {
      if (_firebaseInitialized) {
        final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 4));
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          await _saveTokenToDisk(token);
          debugPrint('🔑 Upgraded to Real Google FCM Token: $_cachedToken');
          return token;
        }
      }
    } catch (_) {}

    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken!;
    }

    await initialize();
    return _cachedToken ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
  }
}



