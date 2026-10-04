import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Configures Android 14+ Foreground Service with FOREGROUND_SERVICE_DATA_SYNC
/// using an ultra-compact, minimal-height notification to keep market monitoring alive 24/7
/// without exhausting or cluttering the user's notification tray.
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
          isForegroundMode: false,
          notificationChannelId: notificationChannelId,
          initialNotificationTitle: '',
          initialNotificationContent: '',
          foregroundServiceNotificationId: notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );
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

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}
