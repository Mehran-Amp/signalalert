import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/tokens.dart';
import '../../alert_engine/repositories/json_alert_rule_repository.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/sound_manager.dart';
import '../../../core/services/tts_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBatteryExempt = false;

  final List<Map<String, String>> _supportedLanguages = const [
    {'code': 'fa', 'name': 'فارسی', 'native': 'فارسی', 'flag': '🇮🇷'},
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    {'code': 'ckb', 'name': 'Kurdish Sorani', 'native': 'کوردی سۆرانی', 'flag': '☀️'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'fr', 'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
    {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文', 'flag': '🇨🇳'},
    {'code': 'ko', 'name': 'Korean', 'native': '한국어', 'flag': '🇰🇷'},
  ];

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (mounted) {
        setState(() {
          _isBatteryExempt = status.isGranted;
        });
      }
    }
  }

  Future<void> _requestBatteryExemption(String lang) async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (mounted) {
      setState(() {
        _isBatteryExempt = status.isGranted;
      });
      if (status.isGranted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(AppStrings.get('battery_exempt_success', lang)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      }
    }
  }

  void _showLanguagePicker(BuildContext context, SettingsService settingsService, String currentLang) {
    final theme = Theme.of(context);
    final isRtl = AppStrings.isRtl(currentLang);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.get('select_language', currentLang),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _supportedLanguages.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    final l = _supportedLanguages[index];
                    final isSelected = currentLang == l['code'];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Text(l['flag']!, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          l['native']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          l['name']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : null,
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                        onTap: () async {
                          await settingsService.setLanguage(l['code']!);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoundPicker(BuildContext context, SettingsService settingsService, String currentSoundId, String lang) {
    final theme = Theme.of(context);
    final isFa = lang == 'fa' || lang == 'ar' || lang == 'ckb';
    final isRtl = AppStrings.isRtl(lang);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.get('select_alarm_sound', lang),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      onPressed: () {
                        SoundManager().stop();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: SoundManager.presets.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (context, index) {
                      final preset = SoundManager.presets[index];
                      final isSelected = currentSoundId == preset.id;
                      final isPlaying = SoundManager().isSoundPlaying(preset.id);
                      final title = preset.getTitle(lang);

                      return InkWell(
                        onTap: () async {
                          await SoundManager().playPreset(preset.id, volume: settingsService.settings.alarmVolume);
                          await settingsService.setSoundName(preset.id);
                          if (ctx.mounted) {
                            setModalState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(preset.icon, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded,
                                  color: isPlaying ? AppTokens.negative : theme.colorScheme.primary,
                                  size: 28,
                                ),
                                onPressed: () async {
                                  if (isPlaying) {
                                    await SoundManager().stop();
                                  } else {
                                    await SoundManager().playPreset(preset.id, volume: settingsService.settings.alarmVolume);
                                  }
                                  setModalState(() {});
                                },
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      SoundManager().stop();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(AppStrings.get('confirm_sound_btn', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      SoundManager().stop();
    });
  }

  Future<void> _testAlarm(BuildContext context, String lang) async {
    final notifService = context.read<NotificationService>();
    final settingsService = context.read<SettingsService>();
    final theme = Theme.of(context);

    // Ensure permissions are granted
    await notifService.requestPermissions();

    await notifService.showCriticalAlert(
      id: 99999,
      title: '🟢 BTC/USDT +3.52% \$87,420.00 ▲',
      body: '📝 ${AppStrings.get('test_alert_body', lang)}',
      soundName: settingsService.settings.soundName,
      volume: settingsService.settings.alarmVolume,
      soundEnabled: settingsService.settings.soundEnabled,
      vibrationEnabled: settingsService.settings.vibrationEnabled,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('test_alert_body', lang)),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _exportBackup(BuildContext context, String lang) async {
    final repo = context.read<JsonAlertRuleRepository>();
    final theme = Theme.of(context);
    final jsonString = await repo.exportAlertsToJson();
    await Clipboard.setData(ClipboardData(text: jsonString));

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('backup_copied', lang)),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, String lang) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final isRtl = AppStrings.isRtl(lang);

    final jsonString = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppStrings.get('restore_backup', lang),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('restore_dialog_hint', lang),
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '[{"uuid": "...", "marketSymbol": "BTCUSDT", ...}]',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                AppStrings.get('cancel', lang),
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(AppStrings.get('restore_dialog_btn', lang)),
            ),
          ],
        ),
      ),
    );

    if (jsonString != null && jsonString.isNotEmpty && context.mounted) {
      try {
        final repo = context.read<JsonAlertRuleRepository>();
        final count = await repo.importAlertsFromJson(jsonString);
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 $count ${AppStrings.get('restore_success', lang)}'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.get('format_error_json', lang)),
              backgroundColor: AppTokens.negative,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearHistory(BuildContext context, String lang) async {
    final theme = Theme.of(context);
    final isRtl = AppStrings.isRtl(lang);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppStrings.get('clear_history', lang),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
          ),
          content: Text(
            AppStrings.get('clear_history_confirm', lang),
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                AppStrings.get('cancel', lang),
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.negative,
                foregroundColor: Colors.white,
              ),
              child: Text(AppStrings.get('clear_history_btn', lang)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = context.read<NotificationRepository>();
      await repo.clearAllLogs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('clear_history_success', lang)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final settings = settingsService.settings;
    final lang = settings.language;
    final isFa = lang == 'fa' || lang == 'ar' || lang == 'ckb';
    final theme = Theme.of(context);

    final currentLangObj = _supportedLanguages.firstWhere(
      (l) => l['code'] == lang,
      orElse: () => _supportedLanguages[0],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          AppStrings.get('settings', lang),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16, vertical: AppTokens.space20),
        children: [
          // Section 1: Languages (10 Languages)
          _buildSectionHeader(AppStrings.get('select_language', lang), theme),
          const SizedBox(height: AppTokens.space8),

          InkWell(
            onTap: () => _showLanguagePicker(context, settingsService, lang),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16, vertical: AppTokens.space12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Text(currentLangObj['flag']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppTokens.space12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentLangObj['native']!,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                      ),
                      Text(
                        '${currentLangObj['name']} (10 Languages)',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space20),

          // Section 2: Sound, Ringtone & Vibration
          _buildSectionHeader(isFa ? 'تنظیمات صدای آلارم و زنگ هشدار' : 'Alarm Sound & Ringtone', theme),
          const SizedBox(height: AppTokens.space8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16, vertical: AppTokens.space12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Current Selected Sound Tile
                Builder(builder: (context) {
                  final currentPreset = SoundManager.presets.firstWhere(
                    (p) => p.id == settings.soundName,
                    orElse: () => SoundManager.presets.first,
                  );
                  final soundTitle = currentPreset.getTitle(lang);
                  final isPlaying = SoundManager().isSoundPlaying(currentPreset.id);

                  return InkWell(
                    onTap: () => _showSoundPicker(context, settingsService, settings.soundName, lang),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Text(currentPreset.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.get('selected_sound_label', lang),
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  soundTitle,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_filled_rounded,
                              color: isPlaying ? AppTokens.negative : theme.colorScheme.primary,
                              size: 30,
                            ),
                            onPressed: () async {
                              if (isPlaying) {
                                await SoundManager().stop();
                              } else {
                                await SoundManager().playPreset(currentPreset.id, volume: settings.alarmVolume);
                              }
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppStrings.get('change_sound_btn', lang),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // 2. Volume Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.volume_up_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.get('alarm_volume_label', lang),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Text(
                      '${(settings.alarmVolume * 100).toInt()}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    thumbColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.dividerColor,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: settings.alarmVolume,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    onChanged: (val) => settingsService.setAlarmVolume(val),
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),

                // 3. Sound & Vibration Switches
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary),
                  title: Text(
                    AppStrings.get('sound_alert', lang),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  value: settings.soundEnabled,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => settingsService.toggleSound(val),
                ),
                Divider(height: 1, color: theme.dividerColor),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.vibration_rounded, color: theme.colorScheme.primary),
                  title: Text(
                    AppStrings.get('vibrate_alert', lang),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  value: settings.vibrationEnabled,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => settingsService.toggleVibration(val),
                ),
                const SizedBox(height: 10),

                // Test Alarm & Voice Speech Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _testAlarm(context, lang),
                        icon: const Icon(Icons.notifications_active_rounded, size: 16),
                        label: Text(
                          isFa ? 'تست زنگ هشدار' : 'Test Alarm',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await TtsService.instance.testVoice();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFa
                                      ? 'پخش گفتار صوتی: Bitcoin 87,420 dollars'
                                      : 'Speaking voice announcement: Bitcoin 87,420 dollars',
                                ),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.record_voice_over_rounded, size: 16),
                        label: Text(
                          isFa ? 'تست گفتار صوتی' : 'Test Voice',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space20),

          // Section 3: Themes & Colors (Theme & Color Schema)
          _buildSectionHeader(AppStrings.get('theme_and_colors', lang), theme),
          const SizedBox(height: AppTokens.space8),

          Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.3,
                  children: [
                    _buildThemeCard(
                      palette: AppThemePalette.darkGreen,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_dark_green', lang),
                      bgPreview: const Color(0xFF090D16),
                      accent: const Color(0xFF10B981),
                      onSelect: () => settingsService.setPalette(AppThemePalette.darkGreen),
                    ),
                    _buildThemeCard(
                      palette: AppThemePalette.lightGreen,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_light_green', lang),
                      bgPreview: const Color(0xFFF3F4F6),
                      accent: const Color(0xFF059669),
                      onSelect: () => settingsService.setPalette(AppThemePalette.lightGreen),
                    ),
                    _buildThemeCard(
                      palette: AppThemePalette.darkOrange,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_dark_orange', lang),
                      bgPreview: const Color(0xFF0C0A09),
                      accent: const Color(0xFFF97316),
                      onSelect: () => settingsService.setPalette(AppThemePalette.darkOrange),
                    ),
                    _buildThemeCard(
                      palette: AppThemePalette.lightOrange,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_light_orange', lang),
                      bgPreview: const Color(0xFFFAF8F5),
                      accent: const Color(0xFFEA580C),
                      onSelect: () => settingsService.setPalette(AppThemePalette.lightOrange),
                    ),
                    _buildThemeCard(
                      palette: AppThemePalette.darkPurpleBlue,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_dark_purple_blue', lang),
                      bgPreview: const Color(0xFF0B0D1B),
                      accent: const Color(0xFF8B5CF6),
                      onSelect: () => settingsService.setPalette(AppThemePalette.darkPurpleBlue),
                    ),
                    _buildThemeCard(
                      palette: AppThemePalette.lightPurpleBlue,
                      currentPalette: settings.themePalette,
                      title: AppStrings.get('theme_light_purple_blue', lang),
                      bgPreview: const Color(0xFFF5F6FF),
                      accent: const Color(0xFF7C3AED),
                      onSelect: () => settingsService.setPalette(AppThemePalette.lightPurpleBlue),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space20),

          // Section 4: Backup & Restore
          _buildSectionHeader(AppStrings.get('backup_and_restore', lang), theme),
          const SizedBox(height: AppTokens.space8),

          _buildActionTile(
            context: context,
            title: AppStrings.get('export_backup', lang),
            subtitle: AppStrings.get('export_backup_desc', lang),
            icon: Icons.cloud_upload_rounded,
            color: theme.colorScheme.primary,
            onTap: () => _exportBackup(context, lang),
          ),
          const SizedBox(height: AppTokens.space8),

          _buildActionTile(
            context: context,
            title: AppStrings.get('restore_backup', lang),
            subtitle: AppStrings.get('restore_backup_desc', lang),
            icon: Icons.cloud_download_rounded,
            color: theme.colorScheme.secondary,
            onTap: () => _importBackup(context, lang),
          ),
          const SizedBox(height: AppTokens.space8),

          _buildActionTile(
            context: context,
            title: AppStrings.get('clear_history', lang),
            subtitle: AppStrings.get('clear_history_desc', lang),
            icon: Icons.delete_outline_rounded,
            color: AppTokens.negative,
            onTap: () => _clearHistory(context, lang),
          ),
          const SizedBox(height: AppTokens.space20),

          // Section 5: Battery Optimization Exemption
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            _buildSectionHeader(AppStrings.get('battery_settings', lang), theme),
            const SizedBox(height: AppTokens.space8),

            Container(
              padding: const EdgeInsets.all(AppTokens.space16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isBatteryExempt
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : AppTokens.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isBatteryExempt ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                        color: _isBatteryExempt ? theme.colorScheme.primary : AppTokens.warning,
                        size: 24,
                      ),
                      const SizedBox(width: AppTokens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('battery_exempt_title', lang),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
                            ),
                            Text(
                              _isBatteryExempt
                                  ? AppStrings.get('battery_exempt_active', lang)
                                  : AppStrings.get('battery_exempt_inactive', lang),
                              style: TextStyle(
                                fontSize: 11,
                                color: _isBatteryExempt ? theme.colorScheme.primary : AppTokens.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_isBatteryExempt) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _requestBatteryExemption(lang),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppStrings.get('battery_request', lang)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildThemeCard({
    required AppThemePalette palette,
    required AppThemePalette currentPalette,
    required String title,
    required Color bgPreview,
    required Color accent,
    required VoidCallback onSelect,
  }) {
    final isSelected = currentPalette == palette;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgPreview,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: bgPreview.computeLuminance() > 0.5 ? const Color(0xFF111827) : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16, vertical: AppTokens.space12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
