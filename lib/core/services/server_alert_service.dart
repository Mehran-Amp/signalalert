import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../features/alert_engine/models/alert_rule.dart';
import '../../features/alert_engine/repositories/json_alert_rule_repository.dart';
import '../../features/exchanges/base/currency_pair.dart';
import '../../features/watchlist/pages/create_alert_flow.dart' show CheckUnit;
import 'fcm_notification_service.dart';

/// ServerAlertService handles communication with the Python Alert Engine backend
class ServerAlertService {
  // Configurable base URL for the Python server (Empty by default until user provides IP/URL)
  static String _baseUrl = '';
  static bool _initialized = false;
  static DateTime? _circuitBreakerUntil;

  /// Whether server calls should be attempted
  static bool get isServerAvailable {
    if (_baseUrl.isEmpty) return false;
    if (_circuitBreakerUntil != null && DateTime.now().isBefore(_circuitBreakerUntil!)) {
      return false;
    }
    return true;
  }

  /// Load persisted server URL from disk on startup
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/server_url.txt');
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) {
          _baseUrl = saved.endsWith('/') ? saved.substring(0, saved.length - 1) : saved;
          debugPrint('🌐 Loaded persisted Server Base URL: $_baseUrl');
        }
      }
    } catch (_) {}
  }

  /// Set or update the server base URL dynamically and persist to disk
  static Future<void> setBaseUrl(String url) async {
    if (url.trim().isNotEmpty) {
      final cleanUrl = url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();
      _baseUrl = cleanUrl;
      _circuitBreakerUntil = null; // Reset circuit breaker
      debugPrint('🌐 ServerAlertService Base URL updated to: $_baseUrl');
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/server_url.txt');
        await file.writeAsString(cleanUrl);
      } catch (_) {}
    }
  }

  /// Get current base URL
  static String get baseUrl => _baseUrl;

  /// Bulk sync all local alert rules to Python server with real FCM Token
  static Future<bool> syncAllRulesToServer(List<AlertRule> rules, {String? userId}) async {
    if (!isServerAvailable) return false;
    try {
      final fcmToken = await FCMNotificationService.getFCMToken();
      final activeRules = rules.where((r) => r.isActive).toList();

      // Retrieve userEmail & telegram_chat_id from settings.json
      String effectiveUserId = userId ?? 'user_default';
      String? telegramChatId;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final sFile = File('${dir.path}/settings.json');
        if (await sFile.exists()) {
          final sData = jsonDecode(await sFile.readAsString());
          telegramChatId = sData['telegramChatId'] as String?;
          final savedEmail = sData['userEmail'] as String?;
          if (savedEmail != null && savedEmail.trim().isNotEmpty) {
            effectiveUserId = savedEmail.trim().toLowerCase();
          }
        }
      } catch (_) {}
      
      final alertsPayload = activeRules.map((rule) {
        final effectiveTarget = rule.targetPrice ?? rule.upperTargetPrice ?? rule.lowerTargetPrice ?? 0.0;
        final conditionStr = (rule.direction == AlertDirection.below) ? 'BELOW' : 'ABOVE';
        final trigMode = (rule.triggerMode == TriggerMode.recurring) ? 'recurring' : 'oneShot';
        return {
          'id': rule.uuid,
          'exchange': rule.exchangeId.toLowerCase(),
          'symbol': rule.marketSymbol.toUpperCase(),
          'target_price': effectiveTarget,
          'condition': conditionStr,
          'check_interval_seconds': rule.checkIntervalSeconds,
          'note': rule.customNote ?? rule.upperNote ?? rule.lowerNote,
          'trigger_mode': trigMode,
          'sound_enabled': rule.soundEnabled,
          'vibration_enabled': rule.vibrationEnabled,
          'tts_enabled': rule.ttsEnabled,
          'sound': rule.customSound ?? 'alarm_siren',
          'is_active': rule.isActive,
          'fcm_token': fcmToken,
          if (telegramChatId != null && telegramChatId.isNotEmpty) 'telegram_chat_id': telegramChatId,
        };
      }).toList();

      final url = Uri.parse('$_baseUrl/api/alerts/sync');
      final payload = {
        'user_id': effectiveUserId,
        'fcm_token': fcmToken,
        'alerts': alertsPayload,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _circuitBreakerUntil = null;
        debugPrint('✅ All alerts successfully synced to Python server for user $effectiveUserId');
        return true;
      }
    } catch (_) {
      _circuitBreakerUntil = DateTime.now().add(const Duration(minutes: 2));
    }
    return false;
  }

  /// Helper to sync all rules in context repository to server
  static Future<bool> syncWithServer(BuildContext context) async {
    try {
      final repo = context.read<JsonAlertRuleRepository>();
      return await syncAllRulesToServer(repo.allRules);
    } catch (e) {
      debugPrint('Sync with server error: $e');
      return false;
    }
  }

  /// Restores user alerts from cloud server when signing in or reinstalling app
  static Future<int> restoreUserAlertsFromCloud({
    required BuildContext context,
    required String userEmail,
  }) async {
    if (!isServerAvailable || userEmail.trim().isEmpty) return 0;
    try {
      final cleanUser = userEmail.trim().toLowerCase();
      final url = Uri.parse('$_baseUrl/api/alerts/$cleanUser');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final repo = context.read<JsonAlertRuleRepository>();
          int imported = 0;
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              try {
                final symbol = item['symbol'] as String? ?? 'BTCUSDT';
                final exchange = item['exchange'] as String? ?? 'binance';
                final target = (item['target_price'] as num?)?.toDouble() ?? 0.0;
                final condition = item['condition'] as String? ?? 'ABOVE';
                final note = item['note'] as String?;
                final interval = item['check_interval_seconds'] as int? ?? 10;
                final ruleId = item['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
                final sound = item['sound'] as String? ?? 'alarm_siren';
                final soundEnabled = item['sound_enabled'] as bool? ?? true;
                final vibEnabled = item['vibration_enabled'] as bool? ?? true;
                final ttsEnabled = item['tts_enabled'] as bool? ?? false;
                final isActive = item['is_active'] as bool? ?? true;

                final direction = condition.toUpperCase() == 'BELOW' ? AlertDirection.below : AlertDirection.above;

                String base = 'BTC';
                String counter = 'USDT';
                if (symbol.contains('/')) {
                  final parts = symbol.split('/');
                  base = parts[0];
                  counter = parts.length > 1 ? parts[1] : 'USDT';
                } else {
                  for (final q in ['USDT', 'USDC', 'BUSD', 'FDUSD', 'EUR', 'USD', 'TMN', 'IRT', 'BTC', 'ETH']) {
                    if (symbol.endsWith(q) && symbol.length > q.length) {
                      base = symbol.substring(0, symbol.length - q.length);
                      counter = q;
                      break;
                    }
                  }
                }

                final rule = AlertRule(
                  uuid: ruleId,
                  baseCurrency: base,
                  counterCurrency: counter,
                  marketSymbol: symbol,
                  exchangeId: exchange,
                  checkIntervalSeconds: interval,
                  conditionType: AlertConditionType.priceThreshold,
                  direction: direction,
                  triggerMode: TriggerMode.oneShot,
                  targetPrice: target,
                  customNote: note,
                  customSound: sound,
                  soundEnabled: soundEnabled,
                  vibrationEnabled: vibEnabled,
                  ttsEnabled: ttsEnabled,
                  isActive: isActive,
                  createdAt: DateTime.now(),
                );

                await repo.saveRule(rule, syncToServer: false);
                imported++;
              } catch (e) {
                debugPrint('⚠️ Error parsing cloud alert: $e');
              }
            }
          }
          debugPrint('☁️ Successfully restored $imported alert(s) from cloud for $cleanUser');
          return imported;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error restoring alerts from cloud: $e');
    }
    return 0;
  }

  /// Completely purge all alerts stored on the Python server
  static Future<bool> purgeAllServerAlerts() async {
    try {
      final url = Uri.parse('$_baseUrl/api/alerts');
      final response = await http.delete(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Helper method to convert (unitValue, CheckUnit) into total seconds (minimum 180 seconds = 3 mins)
  static int calculateIntervalInSeconds(int unitValue, CheckUnit unit) {
    switch (unit) {
      case CheckUnit.minutes:
        final secs = unitValue * 60;
        return secs < 180 ? 180 : secs;
      case CheckUnit.hours:
        final secs = unitValue * 3600;
        return secs < 180 ? 180 : secs;
    }
  }

  /// Create and register a new alert on the Python server
  static Future<bool> createAlertOnServer({
    String? ruleId,
    required String userId,
    required String exchange,
    required String symbol,
    required double targetPrice,
    required String condition, // 'ABOVE' or 'BELOW'
    required int checkIntervalSeconds,
    String? note,
    String triggerMode = 'oneShot',
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    bool ttsEnabled = false,
    String sound = 'alarm_siren',
  }) async {
    try {
      // Get the device's FCM token
      final fcmToken = await FCMNotificationService.getFCMToken();
      if (fcmToken.isEmpty) {
        debugPrint('⚠️ FCM Token not available yet. Using fallback token for registration.');
      }

      // Retrieve telegram_chat_id if saved in settings.json
      String? telegramChatId;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final sFile = File('${dir.path}/settings.json');
        if (await sFile.exists()) {
          final sData = jsonDecode(await sFile.readAsString());
          telegramChatId = sData['telegramChatId'] as String?;
        }
      } catch (_) {}

      final url = Uri.parse('$_baseUrl/api/alerts');
      final payload = {
        if (ruleId != null && ruleId.isNotEmpty) 'id': ruleId,
        'user_id': userId,
        'exchange': exchange.toLowerCase(),
        'symbol': symbol.toUpperCase(),
        'target_price': targetPrice,
        'condition': condition.toUpperCase(),
        'fcm_token': fcmToken.isNotEmpty ? fcmToken : 'device_token_pending',
        'check_interval_seconds': checkIntervalSeconds,
        'trigger_mode': triggerMode,
        'sound_enabled': soundEnabled,
        'vibration_enabled': vibrationEnabled,
        'tts_enabled': ttsEnabled,
        'sound': sound,
        if (note != null && note.isNotEmpty) 'note': note,
        if (telegramChatId != null && telegramChatId.isNotEmpty) 'telegram_chat_id': telegramChatId,
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
    if (!isServerAvailable) return null;
    try {
      final sanitizedSym = symbol.replaceAll('/', '').replaceAll(' ', '');
      final url = Uri.parse('$_baseUrl/api/price/${exchange.toLowerCase()}/$sanitizedSym');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        _circuitBreakerUntil = null;
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('price') && data['price'] is num) {
          final p = (data['price'] as num).toDouble();
          if (p > 0) return p;
        }
      }
    } catch (_) {
      // Temporarily trip circuit breaker so local scheduler doesn't retry unreachable host
      _circuitBreakerUntil = DateTime.now().add(const Duration(minutes: 2));
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
          if (token.isNotEmpty) 'fcm_token': token,
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

  /// Dispatches a real test message to verify the user's Telegram Chat ID connection
  static Future<Map<String, dynamic>> sendTelegramTestAlert(String chatId) async {
    const defaultBotToken = '8597547058:AAFNRkiAnCU3NLdTgRs_Oz4p8GKkV-fR7jg';
    final cleanId = chatId.trim();
    if (cleanId.isEmpty) {
      return {'success': false, 'error': 'Chat ID is empty'};
    }

    // 1. If custom server is configured, try server endpoint first
    if (isServerAvailable) {
      try {
        final url = Uri.parse('$_baseUrl/api/telegram/test-message');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'chat_id': cleanId}),
        ).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          return {'success': true, 'message': 'پیام تست به تلگرام ارسال شد.'};
        }
      } catch (_) {}
    }

    // 2. Direct Telegram Bot API fallback
    try {
      final nowUtc = DateTime.now().toUtc();
      final timeStr = '${nowUtc.year}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')} ${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
      final url = Uri.parse('https://api.telegram.org/bot$defaultBotToken/sendMessage');
      final testMsg = '🚨 <b>هشدار فعال شد:</b>\n'
          '📊🟢 <b>^TNX/USD \$5.31 ▲3.12%</b>\n'
          '🎯 <b>قیمت تارگت:</b> \$5.90\n'
          '🏛️ Global Stocks\n'
          '🕒 <b>زمان:</b> <code>$timeStr</code>\n'
          '⚡ <i>ارسال شده توسط ربات هوشمند SignalAlert Enterprise</i>';
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': cleanId,
          'text': testMsg,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'پیام تست به تلگرام ارسال شد.'};
      } else {
        return {'success': false, 'error': 'کد چت آیدی نامعتبر است یا هنوز دکمه Start را در ربات نزده‌اید.'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

