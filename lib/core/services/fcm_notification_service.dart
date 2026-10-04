import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// FCMNotificationService handles FCM / Device Token management & push credentials
class FCMNotificationService {
  static String? _cachedToken;
  static String? _storageDir;

  /// Initialize and load or generate a persistent Device Token
  static Future<void> initialize({String? storageDirectoryPath}) async {
    try {
      _storageDir = storageDirectoryPath;
      if (_storageDir == null) {
        final dir = await getApplicationDocumentsDirectory();
        _storageDir = dir.path;
      }

      final file = File('$_storageDir/device_token.txt');
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) {
          _cachedToken = saved;
          debugPrint('🔑 Loaded existing Device Token: $_cachedToken');
          return;
        }
      }

      // Generate a persistent unique Device ID if none exists
      final newId = 'dev_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
      _cachedToken = newId;
      await file.writeAsString(newId);
      debugPrint('🔑 Generated & Saved new Device Token: $_cachedToken');
    } catch (e) {
      debugPrint('⚠️ Error initializing Device Token service: $e');
      _cachedToken ??= 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Set or update real device FCM Token
  static Future<void> setCustomToken(String token) async {
    if (token.isNotEmpty) {
      _cachedToken = token.trim();
      debugPrint('🔑 Token updated to: $_cachedToken');
      try {
        if (_storageDir == null) {
          final dir = await getApplicationDocumentsDirectory();
          _storageDir = dir.path;
        }
        final file = File('$_storageDir/device_token.txt');
        await file.writeAsString(_cachedToken!);
      } catch (e) {
        debugPrint('⚠️ Error saving custom token: $e');
      }
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

