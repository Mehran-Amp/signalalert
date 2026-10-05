import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/tts_service.dart';
import '../../settings/services/sound_manager.dart';

/// Helper to read persisted master settings from settings.json
Future<Map<String, dynamic>> _loadMasterSettingsFromDisk() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/settings.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        return jsonDecode(content) as Map<String, dynamic>;
      }
    }
  } catch (_) {}
  return {};
}

/// Service responsible for dispatching mission-critical system notifications.
/// Uses Time-Sensitive notifications on iOS and Maximum High-Priority Alarm channels on Android
/// with public lockscreen visibility to guarantee it displays at the top of the lock screen.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'alarmer_critical_price_alerts';
  static const String channelName = 'Price & Market Alerts';
  static const String channelDescription =
      'High-priority urgent alerts when crypto or market price targets and percentage changes occur.';

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS configuration using Time-Sensitive Interruption Level
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Deep-link handling
      },
    );

    // Create Dedicated Android Notification Channels to strictly enforce OS-level sound and vibration rules
    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);
    
    // Channel 1: Sound & Vibration
    const soundVibrateChannel = AndroidNotificationChannel(
      'alarmer_channel_sound_vibrate_v3',
      'Price Alerts (Sound & Vibration)',
      description: 'High-priority price alerts with audible ringtone and vibration.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    // Channel 2: Sound Only (Vibration 100% Disabled at OS level)
    const soundOnlyChannel = AndroidNotificationChannel(
      'alarmer_channel_sound_only_v3',
      'Price Alerts (Sound Only)',
      description: 'High-priority price alerts with audible chime and zero vibration.',
      importance: Importance.max,
      playSound: true,
      enableVibration: false,
      showBadge: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    // Channel 3: Vibration Only (Muted ringtone, vibration enabled)
    const vibrateOnlyChannel = AndroidNotificationChannel(
      'alarmer_channel_vibrate_only_v3',
      'Price Alerts (Vibration Only)',
      description: 'High-priority price alerts with vibration only.',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    // Channel 4: Silent / Voice Only (Zero sound tone and Zero OS vibration)
    const silentVoiceChannel = AndroidNotificationChannel(
      'alarmer_channel_silent_voice_v3',
      'Price Alerts (Silent & Voice Only)',
      description: 'High-priority price alerts for voice announcements with zero vibration.',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
      enableLights: false,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(soundVibrateChannel);
    await androidImplementation?.createNotificationChannel(soundOnlyChannel);
    await androidImplementation?.createNotificationChannel(vibrateOnlyChannel);
    await androidImplementation?.createNotificationChannel(silentVoiceChannel);

    // Explicitly request notification & alarm permissions on Android 13+ (API 33+)
    await requestPermissions();

    // Show minimal ongoing notification to keep app executing in background
    await showPersistentServiceNotification();
  }

  /// Displays an ultra-compact, single-line ongoing notification so Android keeps background tasks running 24/7
  /// with minimal height so it does not clutter or tire the user.
  Future<void> showPersistentServiceNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'alarmer_foreground_service',
      'Alarmer Service',
      channelDescription: 'Permanent background monitoring',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      enableVibration: false,
      playSound: false,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    try {
      await _notificationsPlugin.show(
        777,
        'Alarmer',
        '● Active',
        platformDetails,
      );
    } catch (_) {}
  }

  /// Request runtime permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted = await androidPlugin?.requestNotificationsPermission() ?? true;
      await androidPlugin?.requestExactAlarmsPermission();

      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? true;

      return androidGranted && iosGranted;
    } catch (_) {
      return false;
    }
  }

  final List<Future<void> Function()> _alertQueue = [];
  bool _isProcessingAlertQueue = false;

  /// Enqueues critical alert notifications so simultaneous triggers appear sequentially
  /// and wait for voice reading to finish completely before the next notification displays.
  void enqueueCriticalAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    String soundName = 'alarm_siren',
    double volume = 1.0,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    bool ttsEnabled = false,
    String? speechText,
  }) {
    _alertQueue.add(() async {
      // Enforce Master Settings from settings.json as primary gatekeeper
      final master = await _loadMasterSettingsFromDisk();
      final masterSound = master['soundEnabled'] as bool? ?? true;
      final masterVibration = master['vibrationEnabled'] as bool? ?? true;
      final masterTts = master['ttsEnabled'] as bool? ?? true;
      final masterVol = (master['alarmVolume'] as num?)?.toDouble() ?? volume;

      final effectiveSound = masterSound && soundEnabled;
      final effectiveVibration = masterVibration && vibrationEnabled;
      final effectiveTts = masterTts && ttsEnabled;

      // 1. Show notification banner with optional sound & vibration
      await showCriticalAlert(
        id: id,
        title: title,
        body: body,
        payload: payload,
        soundName: soundName,
        volume: masterVol,
        soundEnabled: effectiveSound,
        vibrationEnabled: effectiveVibration,
      );

      // 2. If TTS is enabled by both master & alert, vocalize and wait for speech utterance to finish completely
      if (effectiveTts && speechText != null && speechText.trim().isNotEmpty) {
        await TtsService.instance.speak(text: speechText);
        final wordCount = speechText.split(RegExp(r'\s+')).length;
        final estimatedDurationMs = (wordCount * 280 + 2000).clamp(2800, 15000);
        await Future.delayed(Duration(milliseconds: estimatedDurationMs));
      } else {
        await Future.delayed(const Duration(milliseconds: 1800));
      }
    });

    if (!_isProcessingAlertQueue) {
      _processAlertQueue();
    }
  }

  Future<void> _processAlertQueue() async {
    if (_alertQueue.isEmpty) {
      _isProcessingAlertQueue = false;
      return;
    }
    _isProcessingAlertQueue = true;
    final task = _alertQueue.removeAt(0);
    try {
      await task();
    } catch (_) {}
    // Spacing between multiple notifications so they display one by one
    await Future.delayed(const Duration(milliseconds: 1800));
    _processAlertQueue();
  }

  /// Dispatches an immediate high-priority alert notification with sound and vibration
  Future<void> showCriticalAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    String soundName = 'alarm_siren',
    double volume = 1.0,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {
    // Master Settings check
    final master = await _loadMasterSettingsFromDisk();
    final masterSound = master['soundEnabled'] as bool? ?? true;
    final masterVibration = master['vibrationEnabled'] as bool? ?? true;

    final effectiveSound = masterSound && soundEnabled;
    final effectiveVibration = masterVibration && vibrationEnabled;

    // 1. Play Full Synthetic Alarm Audio Tone
    if (effectiveSound) {
      try {
        await SoundManager().playPreset(soundName, volume: volume);
      } catch (_) {}
    }

    // 2. Heavy Haptic Feedback
    if (effectiveVibration) {
      try {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    // 3. System Level Notification Banner with exact matching Channel ID
    final String selectedChannelId;
    final String selectedChannelName;

    if (effectiveSound && effectiveVibration) {
      selectedChannelId = 'alarmer_channel_sound_vibrate_v3';
      selectedChannelName = 'Price Alerts (Sound & Vibration)';
    } else if (effectiveSound && !effectiveVibration) {
      selectedChannelId = 'alarmer_channel_sound_only_v3';
      selectedChannelName = 'Price Alerts (Sound Only)';
    } else if (!effectiveSound && effectiveVibration) {
      selectedChannelId = 'alarmer_channel_vibrate_only_v3';
      selectedChannelName = 'Price Alerts (Vibration Only)';
    } else {
      selectedChannelId = 'alarmer_channel_silent_voice_v3';
      selectedChannelName = 'Price Alerts (Silent & Voice Only)';
    }

    final vibrationPattern = effectiveVibration
        ? Int64List.fromList([0, 500, 200, 500, 200, 500])
        : null;
    final androidDetails = AndroidNotificationDetails(
      selectedChannelId,
      selectedChannelName,
      channelDescription: channelDescription,
      importance: (effectiveSound || effectiveVibration) ? Importance.max : Importance.high,
      priority: Priority.max,
      ticker: '⚡ Price Alert Triggered',
      enableVibration: effectiveVibration,
      vibrationPattern: vibrationPattern,
      playSound: effectiveSound,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: effectiveSound ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      visibility: NotificationVisibility.public,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      color: const Color(0xFF0284C7),
      colorized: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'SignalAlert',
      ),
    );

    // Time-Sensitive Interruption Level allows breaking through Focus Modes on iOS
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
