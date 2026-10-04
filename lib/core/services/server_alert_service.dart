import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/alert_engine/models/alert_rule.dart';
import '../../features/watchlist/pages/create_alert_flow.dart' show CheckUnit;
import 'fcm_notification_service.dart';

/// ServerAlertService handles communication with the Python Alert Engine backend
class ServerAlertService {
  // Configurable base URL for the Python server (Primary domain: https://aisocialfeed.com)
  static String _baseUrl = 'https://aisocialfeed.com';

  /// Set or update the server base URL dynamically
  static void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      // Remove trailing slash if present
      _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      debugPrint('🌐 ServerAlertService Base URL updated to: $_baseUrl');
    }
  }

  /// Bulk sync all local alert rules to Python server with real FCM Token
  static Future<bool> syncAllRulesToServer(List<AlertRule> rules, {String userId = 'user_default'}) async {
    try {
      final fcmToken = await FCMNotificationService.getFCMToken();
      final activeRules = rules.where((r) => r.isActive).toList();
      
      final alertsPayload = activeRules.map((rule) {
        final effectiveTarget = rule.targetPrice ?? rule.upperTargetPrice ?? rule.lowerTargetPrice ?? 0.0;
        final conditionStr = (rule.direction == AlertDirection.below) ? 'BELOW' : 'ABOVE';
        return {
          'id': rule.uuid,
          'exchange': rule.exchangeId.toLowerCase(),
          'symbol': rule.marketSymbol.toUpperCase(),
          'target_price': effectiveTarget,
          'condition': conditionStr,
          'check_interval_seconds': rule.checkIntervalSeconds,
          'note': rule.customNote ?? rule.upperNote ?? rule.lowerNote,
          'is_active': rule.isActive,
          'fcm_token': fcmToken,
        };
      }).toList();

      final url = Uri.parse('$_baseUrl/api/alerts/sync');
      final payload = {
        'user_id': userId,
        'fcm_token': fcmToken,
        'alerts': alertsPayload,
      };

      debugPrint('📤 Bulk syncing ${alertsPayload.length} alert(s) to server with FCM Token: ${fcmToken.substring(0, fcmToken.length > 20 ? 20 : fcmToken.length)}...');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ All alerts successfully synced to Python server for 24/7 background FCM monitoring!');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error bulk syncing alerts to server: $e');
    }
    return false;
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

  /// Fetch live price via Python server proxy for filtered exchanges (Binance, MEXC, Yahoo Finance, etc.)
  static Future<double?> fetchPriceViaServer(String exchange, String symbol) async {
    try {
      final sanitizedSym = symbol.replaceAll('/', '').replaceAll(' ', '');
      final url = Uri.parse('$_baseUrl/api/price/${exchange.toLowerCase()}/$sanitizedSym');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('price') && data['price'] is num) {
          final p = (data['price'] as num).toDouble();
          if (p > 0) return p;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error proxying price via server ($exchange / $symbol): $e');
    }
    return null;
  }

  /// Run deep server-side diagnostics on a specific exchange & market symbol
  static Future<Map<String, dynamic>?> inspectMarketSource(String exchange, String symbol) async {
    try {
      final sanitizedSym = symbol.replaceAll('/', '').replaceAll(' ', '');
      final url = Uri.parse('$_baseUrl/api/debug/inspect/${exchange.toLowerCase()}/$sanitizedSym');
      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      debugPrint('❌ Error running deep server inspection: $e');
    }
    return null;
  }

  /// Fetch recent server diagnostic logs
  static Future<List<Map<String, dynamic>>> fetchDebugLogs() async {
    try {
      final url = Uri.parse('$_baseUrl/api/debug/logs');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('logs') && data['logs'] is List) {
          return (data['logs'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching debug logs: $e');
    }
    return [];
  }

  /// Sends a test verification push notification from server to verify live mobile delivery
  static Future<Map<String, dynamic>> sendTestPush({String? customTitle, String? customBody}) async {
    try {
      final token = await FCMNotificationService.getFCMToken();
      final uri = Uri.parse('$_baseUrl/api/test/push').replace(
        queryParameters: {
          if (token != null && token.isNotEmpty) 'fcm_token': token,
          if (customTitle != null && customTitle.isNotEmpty) 'title': customTitle,
          if (customBody != null && customBody.isNotEmpty) 'body': customBody,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
      return {'success': false, 'error': 'Server returned HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('❌ Error sending test push: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
