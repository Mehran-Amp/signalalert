import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/strings.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/crypto_icons.dart';
import '../../../core/utils/format_utils.dart';
import '../../alert_engine/models/alert_rule.dart';
import '../../alert_engine/models/trigger_mode.dart';
import '../../alert_engine/repositories/json_alert_rule_repository.dart';
import '../../alert_engine/scheduler/scheduler_service.dart';
import '../../exchanges/registry/exchange_registry.dart';
import '../../settings/services/settings_service.dart';
import '../../widgets/alert_home_widget.dart';
import 'create_alert_flow.dart';

/// The Main Screen of Alarmer: Personal Price Alerts.
/// Highlights the latest checked price prominently (large and bold).
/// Supports full tap-to-edit and a 100% reliable in-app floating undo toast.
class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  final Set<String> _checkingRuleUuids = {};
  AlertRule? _recentlyDeletedRule;
  Timer? _undoToastTimer;
  Timer? _countdownTimer;
  bool _isRefreshingAll = false;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _undoToastTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllAlerts(
    BuildContext context,
    JsonAlertRuleRepository repository,
    SchedulerService scheduler,
    String lang,
  ) async {
    if (_isRefreshingAll) return;
    setState(() => _isRefreshingAll = true);
    final theme = Theme.of(context);
    final isFa = lang == 'fa' || lang == 'ar' || lang == 'ckb';

    try {
      final activeRules = repository.allRules.where((r) => r.isActive).toList();
      if (activeRules.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text(isFa ? 'هیچ هشدار فعالی برای بروزرسانی وجود ندارد.' : 'No active alerts to refresh.'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      int successCount = 0;
      for (final rule in activeRules) {
        final ok = await scheduler.checkRuleNow(rule);
        if (ok) successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              isFa
                  ? 'بروزرسانی همگانی انجام شد ($successCount از ${activeRules.length} نماد بروز شدند)'
                  : 'Refreshed $successCount of ${activeRules.length} symbols successfully.',
            ),
            backgroundColor: theme.colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAll = false);
      }
    }
  }

  void _openCreateFlow() {
    final registry = context.read<ExchangeRegistry>();
    final repository = context.read<JsonAlertRuleRepository>();

    CreateAlertFlow.open(
      context,
      registry: registry,
      repository: repository,
    );
  }

  void _openEditFlow(AlertRule rule) {
    final registry = context.read<ExchangeRegistry>();
    final repository = context.read<JsonAlertRuleRepository>();

    CreateAlertFlow.open(
      context,
      registry: registry,
      repository: repository,
      initialRule: rule,
    );
  }

  void _onRuleDismissed(AlertRule rule, JsonAlertRuleRepository repository) {
    _undoToastTimer?.cancel();
    repository.deleteRule(rule.uuid);
    setState(() {
      _recentlyDeletedRule = rule;
    });

    _undoToastTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        setState(() {
          _recentlyDeletedRule = null;
        });
      }
    });
  }

  void _undoDelete(JsonAlertRuleRepository repository) {
    if (_recentlyDeletedRule != null) {
      _undoToastTimer?.cancel();
      repository.saveRule(_recentlyDeletedRule!);
      setState(() {
        _recentlyDeletedRule = null;
      });
    }
  }

  void _dismissUndoToast() {
    _undoToastTimer?.cancel();
    setState(() {
      _recentlyDeletedRule = null;
    });
  }

  Future<void> _manualCheck(AlertRule rule, SchedulerService scheduler, String lang) async {
    setState(() => _checkingRuleUuids.add(rule.uuid));
    try {
      final success = await scheduler.checkRuleNow(rule);
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text('${AppStrings.get('check_price_done', lang)}${rule.pair.displayName}'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text(AppStrings.get('offline_error', lang)),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _checkingRuleUuids.remove(rule.uuid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<JsonAlertRuleRepository>();
    final scheduler = context.read<SchedulerService>();
    final settingsService = context.watch<SettingsService>();
    final lang = settingsService.settings.language;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.space6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: AppTokens.borderSmall,
              ),
              child: Icon(Icons.alarm_on_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.get('my_alerts', lang),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppStrings.get('smart_alerts_desc', lang),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshingAll
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.sync_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
            tooltip: lang == 'fa' ? 'به‌روزرسانی آنی تمامی نمادها' : 'Refresh All Symbols',
            onPressed: _isRefreshingAll
                ? null
                : () => _refreshAllAlerts(context, repository, scheduler, lang),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: ElevatedButton.icon(
              onPressed: _openCreateFlow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                AppStrings.get('new_alert', lang),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<AlertRule>>(
            stream: repository.watchAllRules(),
            builder: (context, snapshot) {
              final rules = snapshot.data ?? repository.allRules;

              if (rules.isEmpty) {
                return _buildEmptyState(lang, theme);
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16,
                  AppTokens.space12,
                  AppTokens.space16,
                  80.0,
                ),
                itemCount: rules.length,
                onReorder: (oldIndex, newIndex) {
                  repository.reorderRules(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return Padding(
                    key: ValueKey(rule.uuid),
                    padding: const EdgeInsets.only(bottom: AppTokens.space12),
                    child: _buildAlertCard(rule, repository, scheduler, lang),
                  );
                },
              );
            },
          ),

          // 100% Reliable In-App Floating Undo Toast
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            bottom: _recentlyDeletedRule != null ? 20 : -100,
            child: _buildUndoToast(lang, theme, repository),
          ),
        ],
      ),
    );
  }

  Widget _buildUndoToast(String lang, ThemeData theme, JsonAlertRuleRepository repository) {
    if (_recentlyDeletedRule == null) return const SizedBox.shrink();

    final ruleName = _recentlyDeletedRule!.pair.displayName;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerHighest,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppTokens.negative, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${AppStrings.get('alert_deleted_msg', lang)}$ruleName',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => _undoDelete(repository),
              icon: Icon(Icons.undo_rounded, size: 16, color: theme.colorScheme.primary),
              label: Text(
                AppStrings.get('undo_action', lang),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              onPressed: _dismissUndoToast,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    AlertRule rule,
    JsonAlertRuleRepository repository,
    SchedulerService scheduler,
    String lang,
  ) {
    final theme = Theme.of(context);
    final isTriggeredOneShot = rule.isTriggered && rule.triggerMode == TriggerMode.oneShot;
    final isChecking = _checkingRuleUuids.contains(rule.uuid);
    final textMuted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final displayPrice = rule.currentDisplayPrice;
    final basePrice = rule.basePrice;

    double? changePercent;
    if (displayPrice != null && basePrice != null && basePrice > 0) {
      changePercent = ((displayPrice - basePrice) / basePrice) * 100.0;
    }

    return Dismissible(
      key: Key(rule.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.space20),
        decoration: BoxDecoration(
          color: AppTokens.negative,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _onRuleDismissed(rule, repository),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openEditFlow(rule),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isTriggeredOneShot
                    ? AppTokens.warning.withValues(alpha: 0.7)
                    : theme.dividerColor,
                width: isTriggeredOneShot ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Row 1: Logo + Coin info & Exchange Name + Live Price + Switch
                Row(
                  children: [
                    CryptoIcons.buildLogo(rule.baseCurrency, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  rule.pair.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: rule.isActive ? theme.colorScheme.onSurface : textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit_note_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 12, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _getExchangeDisplayName(rule.exchangeId, lang),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: rule.isActive ? textSecondary : textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          displayPrice != null ? FormatUtils.formatPrice(displayPrice, currencySymbol: rule.counterCurrency) : '---',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: rule.isActive
                                ? (changePercent != null && changePercent >= 0 ? theme.colorScheme.primary : theme.colorScheme.onSurface)
                                : textMuted,
                          ),
                        ),
                        if (changePercent != null)
                          Text(
                            '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: changePercent >= 0 ? AppTokens.positive : AppTokens.negative,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: isTriggeredOneShot
                          ? IconButton(
                              icon: const Icon(Icons.replay_rounded, color: AppTokens.warning),
                              onPressed: () => repository.rearmRule(rule.uuid),
                            )
                          : Switch(
                              value: rule.isActive,
                              activeThumbColor: Colors.white,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (val) => repository.saveRule(rule.copyWith(isActive: val)),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: Condition Summary Tag
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        rule.conditionType == AlertConditionType.priceThreshold
                            ? Icons.flag_rounded
                            : Icons.show_chart_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _buildConditionSummary(rule, lang),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: rule.isActive ? theme.colorScheme.onSurface : textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Row 3: Interval Tag + Baseline + Remaining Time to Next Check + Quick Check Now Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 11, color: theme.colorScheme.primary),
                          const SizedBox(width: 3),
                          Text(
                            _formatInterval(rule.checkIntervalSeconds, lang),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    if (rule.basePrice != null && rule.basePrice! > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${AppStrings.get('baseline', lang)}: ${_formatPrice(rule.basePrice!)}',
                        style: TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Remaining Time until Next Scheduled Check
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 11,
                            color: rule.isActive ? theme.colorScheme.primary : textMuted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _formatNextCheckTime(rule, lang),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: rule.isActive ? theme.colorScheme.primary : textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: isChecking ? null : () => _manualCheck(rule, scheduler, lang),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isChecking)
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.primary),
                              )
                            else
                              Icon(Icons.refresh_rounded, size: 12, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppStrings.get('check_now', lang),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String lang, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.space24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_alert_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTokens.space20),
            Text(
              AppStrings.get('empty_alerts_title', lang),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              AppStrings.get('empty_alerts_desc', lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTokens.space24),
            ElevatedButton.icon(
              onPressed: _openCreateFlow,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                AppStrings.get('create_first_alert', lang),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      final parts = price.toStringAsFixed(2).split('.');
      final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '\$$whole.${parts[1]}';
    } else if (price >= 1) {
      return '\$${price.toStringAsFixed(2)}';
    } else if (price >= 0.0001) {
      return '\$${price.toStringAsFixed(4)}';
    } else {
      return '\$${price.toStringAsFixed(8)}';
    }
  }

  String _formatNextCheckTime(AlertRule rule, String lang) {
    final isFa = AppStrings.isRtl(lang);
    if (!rule.isActive) {
      return isFa ? 'غیرفعال' : 'Inactive';
    }

    final now = DateTime.now();
    final lastTime = rule.lastCheckedAt ?? rule.createdAt;
    final nextTime = lastTime.add(Duration(seconds: rule.checkIntervalSeconds));
    final diff = nextTime.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      return isFa ? 'در حال بررسی...' : 'Checking now...';
    }

    if (diff.inHours >= 1) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (m == 0) {
        return isFa ? '$h ساعت تا بررسی' : 'In ${h}h';
      }
      return isFa ? '$h ساعت و $m دقیقه تا بررسی' : 'In ${h}h ${m}m';
    } else if (diff.inMinutes >= 1) {
      final m = diff.inMinutes;
      final s = diff.inSeconds % 60;
      if (s == 0) {
        return isFa ? '$m دقیقه تا بررسی' : 'In ${m}m';
      }
      return isFa ? '$m دقیقه و $s ثانیه تا بررسی' : 'In ${m}m ${s}s';
    } else {
      return 'In ${diff.inSeconds} s';
    }
  }

  String _formatInterval(int seconds, String lang) {
    if (seconds < 60) {
      return '$seconds s';
    } else if (seconds < 3600) {
      final m = seconds ~/ 60;
      return '$m ${AppStrings.get('minutes', lang)}';
    } else {
      final h = seconds ~/ 3600;
      return '$h ${AppStrings.get('hours', lang)}';
    }
  }

  String _formatTimeAgo(DateTime dt, String lang) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return AppStrings.get('just_now', lang);
    if (diff.inSeconds < 60) return '${diff.inSeconds}${AppStrings.get('seconds_ago', lang)}';
    if (diff.inMinutes < 60) return '${diff.inMinutes}${AppStrings.get('minutes_ago', lang)}';
    if (diff.inHours < 24) return '${diff.inHours}${AppStrings.get('hours_ago', lang)}';
    return '${diff.inDays}${AppStrings.get('days_ago', lang)}';
  }

  String _getExchangeDisplayName(String exchangeId, String lang) {
    final isFa = AppStrings.isRtl(lang);
    switch (exchangeId) {
      case 'global_stocks':
        return isFa ? 'بازار جهانی و وال‌استریت' : 'Global Equities & Commodities';
      case 'binance':
        return 'Binance';
      case 'nobitex':
        return isFa ? 'نوبیتکس' : 'Nobitex';
      case 'wallex':
        return isFa ? 'والکس' : 'Wallex';
      case 'tabdeal':
        return isFa ? 'تبدیل' : 'Tabdeal';
      case 'bitbarg':
        return isFa ? 'بیت‌برگ' : 'Bitbarg';
      case 'abantether':
        return isFa ? 'آبان‌تتر' : 'AbanTether';
      case 'ramzinex':
        return isFa ? 'رمزینکس' : 'Ramzinex';
      case 'tetherland':
        return isFa ? 'تترلند' : 'TetherLand';
      case 'sarmayex':
        return isFa ? 'سرمایکس' : 'Sarmayex';
      case 'exir':
        return isFa ? 'اکسیر' : 'Exir';
      case 'kcex':
        return 'KCEX';
      case 'lbank':
        return 'LBank';
      case 'ourbit':
        return 'Ourbit';
      case 'xt':
        return 'XT.COM';
      case 'toobit':
        return 'Toobit';
      case 'coinbase':
        return 'Coinbase';
      case 'kucoin':
        return 'KuCoin';
      case 'okx':
        return 'OKX';
      case 'bybit':
        return 'Bybit';
      case 'mexc':
        return 'MEXC';
      case 'gateio':
        return 'Gate.io';
      case 'bingx':
        return 'BingX';
      case 'bitget':
        return 'Bitget';
      case 'kraken':
        return 'Kraken';
      case 'coinmarketcap':
        return 'CoinMarketCap';
      case 'coingecko':
        return 'CoinGecko';
      default:
        return exchangeId.toUpperCase();
    }
  }

  String _buildConditionSummary(AlertRule rule, String lang) {
    final isFa = AppStrings.isRtl(lang);
    switch (rule.conditionType) {
      case AlertConditionType.priceThreshold:
        final String dirStr;
        if (rule.direction == AlertDirection.above) {
          dirStr = lang == 'ckb' ? 'بەرزبوونەوە بۆ سەرووی' : (isFa ? 'صعود به بالای' : 'Crosses above');
        } else if (rule.direction == AlertDirection.below) {
          dirStr = lang == 'ckb' ? 'دابەزین بۆ خوارەوەی' : (isFa ? 'سقوط به زیر' : 'Drops below');
        } else {
          dirStr = lang == 'ckb' ? 'گەیشتن بە' : (isFa ? 'رسیدن به' : 'Reaches');
        }
        return '$dirStr ${FormatUtils.formatPrice(rule.targetPrice ?? 0, currencySymbol: rule.counterCurrency)}';

      case AlertConditionType.percentChange:
        final p = rule.percent ?? 0;
        final String dirStr;
        if (rule.direction == AlertDirection.above) {
          dirStr = lang == 'ckb' ? 'بەرزبوونەوەی' : (isFa ? 'رشد حداقل' : 'Surges by +');
        } else if (rule.direction == AlertDirection.below) {
          dirStr = lang == 'ckb' ? 'دابەزینی' : (isFa ? 'افت حداقل' : 'Drops by -');
        } else {
          dirStr = lang == 'ckb' ? 'جووڵە' : (isFa ? 'نوسان' : 'Moves ±');
        }
        return '$dirStr ${p.toStringAsFixed(1)}%';

      case AlertConditionType.absolutePriceChange:
        return '${lang == 'ckb' ? "گۆڕانکاری" : (isFa ? "تغییر" : "Changes by")} ${FormatUtils.formatPrice(rule.deltaAbsolute ?? 0, currencySymbol: rule.counterCurrency)}';

      case AlertConditionType.volumeChange:
        return '${lang == 'ckb' ? "هەڵکشانی قەبارە" : (isFa ? "جهش حجم" : "Volume jump")} ${(rule.volumePercent ?? 0).toStringAsFixed(1)}%';
    }
  }

  void _showHomeWidgetSheet(
    BuildContext context,
    JsonAlertRuleRepository repository,
    String lang,
    ThemeData theme,
  ) {
    final isFa = AppStrings.isRtl(lang);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFa ? 'پیش‌نمایش ویجت صفحه اصلی' : 'Home Screen Widget Preview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isFa
                    ? 'این ویجت به صورت زنده آخرین نرخ‌ها، درصد فاصله تا هدف و وضعیت هشدارها را مستقیماً روی صفحه گوشی شما نمایش می‌دهد.'
                    : 'This live widget displays latest prices, target progress, and alert statuses directly on your device home screen.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              AlertHomeWidgetView(
                repository: repository,
                lang: lang,
                onAddNew: () {
                  Navigator.of(ctx).pop();
                  _openCreateFlow();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
