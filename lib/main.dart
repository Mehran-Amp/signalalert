import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app/navigation/app_shell.dart';
import 'core/localization/app_strings.dart';
import 'core/services/native_widget_sync_service.dart';
import 'features/alert_engine/bloc/alert_rules_bloc.dart';
import 'features/alert_engine/bloc/alert_rules_event.dart';
import 'features/alert_engine/repositories/json_alert_rule_repository.dart';
import 'features/alert_engine/scheduler/scheduler_service.dart';
import 'features/exchanges/registry/exchange_catalog.dart';
import 'features/exchanges/registry/exchange_registry.dart';
import 'features/notifications/background/background_service_manager.dart';
import 'features/notifications/repositories/notification_repository.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/settings/models/app_settings.dart';
import 'features/settings/services/settings_service.dart';

void main() async {
  // 1. Ensure Flutter engine and native bindings are fully initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize System Notification Service & Background Foreground Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await BackgroundServiceManager.initializeService();

  // 3. Initialize Local-First Repositories (Alerts + Notification History + Settings)
  final dir = await getApplicationDocumentsDirectory();
  final alertRuleRepository = JsonAlertRuleRepository(dir.path);
  await alertRuleRepository.load();

  final notificationRepository = NotificationRepository(dir.path);
  await notificationRepository.load();

  final settingsService = SettingsService(dir.path);
  await settingsService.load();

  // Sync initial widget state with loaded alerts and active theme
  await NativeWidgetSyncService.syncAlerts(
    alertRuleRepository.allRules,
    themePalette: settingsService.settings.themePalette,
  );

  // 4. Initialize Central Exchange Registry (inspired by BitcoinChecker DataModule)
  final exchangeRegistry = ExchangeRegistry();
  for (final ex in ExchangeCatalog.buildAllExchanges()) {
    exchangeRegistry.register(ex);
  }

  // 5. Initialize & Start Periodic Polling Scheduler Service
  final schedulerService = SchedulerService(
    alertRuleRepository: alertRuleRepository,
    exchangeRegistry: exchangeRegistry,
    notificationService: notificationService,
    notificationRepository: notificationRepository,
  )..start();

  runApp(BitcoinCheckerApp(
    exchangeRegistry: exchangeRegistry,
    alertRuleRepository: alertRuleRepository,
    notificationRepository: notificationRepository,
    settingsService: settingsService,
    schedulerService: schedulerService,
    notificationService: notificationService,
  ));
}

/// Root Application Widget with Global Repository & BLoC Dependency Injection
class BitcoinCheckerApp extends StatelessWidget {
  final ExchangeRegistry exchangeRegistry;
  final JsonAlertRuleRepository alertRuleRepository;
  final NotificationRepository notificationRepository;
  final SettingsService settingsService;
  final SchedulerService schedulerService;
  final NotificationService notificationService;

  const BitcoinCheckerApp({
    super.key,
    required this.exchangeRegistry,
    required this.alertRuleRepository,
    required this.notificationRepository,
    required this.settingsService,
    required this.schedulerService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsService>.value(
      value: settingsService,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ExchangeRegistry>.value(value: exchangeRegistry),
          RepositoryProvider<JsonAlertRuleRepository>.value(value: alertRuleRepository),
          RepositoryProvider<NotificationRepository>.value(value: notificationRepository),
          RepositoryProvider<SchedulerService>.value(value: schedulerService),
          RepositoryProvider<NotificationService>.value(value: notificationService),
        ],
        child: MultiBlocProvider(
          providers: [
            // AlertRulesBloc: Pure local CRUD manager talking directly to JSON repository
            BlocProvider<AlertRulesBloc>(
              create: (ctx) => AlertRulesBloc(
                repository: alertRuleRepository,
              )..add(const LoadAlertRules()),
            ),
          ],
          child: AnimatedBuilder(
            animation: settingsService,
            builder: (context, _) {
              final isLight = settingsService.settings.themePalette == AppThemePalette.lightGreen ||
                  settingsService.settings.themePalette == AppThemePalette.lightOrange;
              final lang = settingsService.settings.language;
              final isRtl = AppStrings.isRtl(lang);
              return MaterialApp(
                title: 'Alarmer',
                debugShowCheckedModeBanner: false,
                themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
                theme: settingsService.settings.buildThemeData(),
                darkTheme: settingsService.settings.buildThemeData(),
                locale: Locale(lang),
                builder: (context, child) {
                  return Directionality(
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const AppShell(),
              );
            },
          ),
        ),
      ),
    );
  }
}
