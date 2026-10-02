import 'package:flutter/services.dart';

/// Helper to send the Android activity into the background (mimicking pressing the Home button),
/// allowing the app's Dart background timers, WebSocket connections, and periodic polling services
/// to continue running without getting killed by the OS when the user presses Back.
class AppLifecycleHelper {
  static const MethodChannel _channel =
      MethodChannel('com.example.bitcoin_checker/app_lifecycle');

  static Future<void> moveToBackground() async {
    try {
      final success = await _channel.invokeMethod<bool>('sendToBackground');
      if (success != true) {
        await SystemNavigator.pop();
      }
    } catch (_) {
      try {
        await SystemNavigator.pop();
      } catch (_) {}
    }
  }
}
