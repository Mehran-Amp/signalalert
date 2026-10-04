import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// FCMNotificationService handles Firebase Cloud Messaging (FCM) & Device Token management
class FCMNotificationService {
  static String? _cachedToken;
  static String? _storageDir;
  static bool _firebaseInitialized = false;

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

    // 2. Try fetching real Google FCM Token if Firebase is active
    if (_firebaseInitialized) {
      try {
        final fcm = FirebaseMessaging.instance;
        // Request permissions
        await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

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

  /// Get current Device / FCM Token
  static Future<String> getFCMToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken!;
    }
    await initialize();
    return _cachedToken ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
  }
}


