import 'package:flutter/material.dart';
import '../../features/settings/services/settings_service.dart';

/// Service managing optional Google Account Authentication and Cloud Sync preparation.
class GoogleAuthService {
  /// Prompt the user with a modern Google Sign-In account dialog
  static Future<bool> promptGoogleSignIn(
    BuildContext context,
    SettingsService settingsService,
    String lang,
  ) async {
    final theme = Theme.of(context);
    final isFa = lang == 'fa' || lang == 'ar' || lang == 'ckb';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Image.network(
                'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isFa ? 'ورود با حساب گوگل' : 'Sign in with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFa
                  ? 'این قابلیت اختیاری است. با ورود به حساب گوگل، اطلاعات هشدارهای شما به صورت امن ذخیره شده و حساب شما به عنوان «عضو طلایی (Premium Ready)» نشان‌دار خواهد شد.'
                  : 'This is completely optional. Signing in with Google safely syncs your alert rules and grants early Premium Ready status.',
              style: TextStyle(fontSize: 12, height: 1.4, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blueAccent,
                    child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Account',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface),
                        ),
                        Text(
                          'Mehran.Aminpoor@gmail.com',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isFa ? 'فعلاً نه (انصراف)' : 'Maybe Later',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: Text(isFa ? 'اتصال حساب گوگل' : 'Connect Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await settingsService.signInWithGoogle(
        email: 'Mehran.Aminpoor@gmail.com',
        displayName: 'Mehran',
        photoUrl: 'https://lh3.googleusercontent.com/a/default-user',
      );
      return true;
    }
    return false;
  }
}
