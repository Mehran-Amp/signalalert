import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/watchlist/pages/create_alert_flow.dart' show CheckUnit;
import 'fcm_notification_service.dart';

/// ServerAlertService handles communication with the Python Alert Engine backend
class ServerAlertService {
  // Configurable base URL for the Python server (server60 port 8000)
  static String _baseUrl = 'http://server60.webtook.com:8000';

  /// Set or update the server base URL dynamically
  static void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      // Remove trailing slash if present
      _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      debugPrint('🌐 ServerAlertService Base URL updated to: $_baseUrl');
    }
  }

  /// Get current base URL
  static String get baseUrl => _baseUrl;

  /// Helper method to convert (unitValue, CheckUnit) into total seconds
  static int calculateIntervalInSeconds(int unitValue, CheckUnit unit) {
    final val = unitValue <= 0 ? 10 : unitValue;
    switch (unit) {
      case CheckUnit.seconds:
        return val;
      case CheckUnit.minutes:
        return val * 60;
      case CheckUnit.hours:
        return val * 3600;
    }
  }

  /// Create and register a new alert on the Python server
  static Future<bool> createAlertOnServer({
    required String userId,
    required String exchange,
    required String symbol,
    required double targetPrice,
    required String condition, // 'ABOVE' or 'BELOW'
    required int checkIntervalSeconds,
    String? note,
  }) async {
    try {
      // Get the device's FCM token
      final fcmToken = await FCMNotificationService.getFCMToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ FCM Token not available yet. Using fallback token for registration.');
      }

      final url = Uri.parse('$_baseUrl/api/alerts');
      final payload = {
        'user_id': userId,
        'exchange': exchange.toLowerCase(),
        'symbol': symbol.toUpperCase(),
        'target_price': targetPrice,
        'condition': condition.toUpperCase(),
        'fcm_token': fcmToken ?? 'device_token_pending',
        'check_interval_seconds': checkIntervalSeconds,
        if (note != null && note.isNotEmpty) 'note': note,
      };

      debugPrint('📤 Sending alert to Python server: $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Alert successfully created on Python server: ${response.body}');
        return true;
      } else {
        debugPrint('❌ Failed to create alert on server. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error connecting to Python Alert Server: $e');
    }
    return false;
  }

  /// Fetch all active alerts for a user from the Python server
  static Future<List<Map<String, dynamic>>> fetchUserAlerts(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/alerts/$userId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('❌ Error fetching alerts from Python server: $e');
    }
    return [];
  }

  /// Delete an alert from the Python server by ID
  static Future<bool> deleteAlertFromServer(String alertId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/alerts/$alertId');
      final response = await http.delete(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Alert $alertId deleted from Python server.');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting alert from Python server: $e');
    }
    return false;
  }
}
