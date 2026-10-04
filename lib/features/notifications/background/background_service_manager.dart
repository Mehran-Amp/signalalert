import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../../alert_engine/repositories/json_alert_rule_repository.dart';
import '../../alert_engine/scheduler/scheduler_service.dart';
import '../../exchanges/registry/exchange_catalog.dart';
import '../../exchanges/registry/exchange_registry.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../../settings/services/settings_service.dart';

/// Configures Android 14+ Foreground Service
/// using a persistent background task to keep market monitoring alive 24/7
/// even when the app UI is closed by the user.
class BackgroundServiceManager {
  static const String notificationChannelId = 'alarmer_foreground_service';
  static const int notificationId = 777;

  static Future<void> initializeService() async {
    if (kIsWeb) return;

    try {
      final service = FlutterBackgroundService();

      // Create low-noise, compact persistent notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        'Alarmer Service',
        description: 'Permanent background monitoring',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onBackgroundServiceStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: notificationChannelId,
          initialNotificationTitle: 'SignalAlert',
          initialNotificationContent: 'سرویس پایش ۲۴/۷ بازار فعال است',
          foregroundServiceNotificationId: notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );

      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onBackgroundServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });

      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'SignalAlert',
        content: 'سرویس پایش ۲۴/۷ بازار فعال است',
      );
    }

    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final dir = await getApplicationDocumentsDirectory();
      final alertRuleRepository = JsonAlertRuleRepository(dir.path);
      await alertRuleRepository.load();

      final notificationRepository = NotificationRepository(dir.path);
      await notificationRepository.load();

      final settingsService = SettingsService(dir.path);
      await settingsService.load();

      final exchangeRegistry = ExchangeRegistry();
      for (final ex in ExchangeCatalog.buildAllExchanges()) {
        exchangeRegistry.register(ex);
      }

      final schedulerService = SchedulerService(
        alertRuleRepository: alertRuleRepository,
        exchangeRegistry: exchangeRegistry,
        notificationService: notificationService,
        notificationRepository: notificationRepository,
        settingsService: settingsService,
      );

      // Background periodic loop checking prices every 5s even when app is closed!
      Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          await alertRuleRepository.load();
          final rules = alertRuleRepository.allRules.where((r) => r.isActive).toList();
          if (rules.isNotEmpty) {
            for (final rule in rules) {
              await schedulerService.checkRuleNow(rule);
            }
          }
        } catch (_) {}
      });
    } catch (_) {}

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}
