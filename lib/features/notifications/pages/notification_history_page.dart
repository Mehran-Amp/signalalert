import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/services/settings_service.dart';
import '../models/notification_log.dart';
import '../repositories/notification_repository.dart';
import '../widgets/history_group_header.dart';

enum HistoryFilter { all, triggered, suppressed }

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  HistoryFilter _currentFilter = HistoryFilter.all;
  List<NotificationLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final repo = context.read<NotificationRepository>();
    final logs = await repo.getAllLogs();

    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsService = context.watch<SettingsService>();
    final lang = settingsService.settings.language;

    final filteredLogs = _logs.where((log) {
      if (_currentFilter == HistoryFilter.all) return true;
      if (_currentFilter == HistoryFilter.triggered) {
        return !log.message.contains('Suppressed');
      }
      if (_currentFilter == HistoryFilter.suppressed) {
        return log.message.contains('Suppressed') || log.message.contains('cooldown');
      }
      return true;
    }).toList();

    final groupedLogs = _groupLogsByDay(filteredLogs);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          AppStrings.get('history', lang),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips at Top
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space16,
              vertical: AppTokens.space12,
            ),
            child: Row(
              children: [
                _buildFilterChip(HistoryFilter.all, AppStrings.get('filter_all', lang), theme),
                const SizedBox(width: AppTokens.space8),
                _buildFilterChip(HistoryFilter.triggered, AppStrings.get('filter_triggered', lang), theme),
                const SizedBox(width: AppTokens.space8),
                _buildFilterChip(HistoryFilter.suppressed, AppStrings.get('filter_suppressed', lang), theme),
              ],
            ),
          ),

          // Log Entries List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : filteredLogs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.space32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTokens.space24),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 48,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: AppTokens.space16),
                              Text(
                                AppStrings.get('no_history_title', lang),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppTokens.space8),
                              Text(
                                AppStrings.get('no_history_desc', lang),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: groupedLogs.length,
                          itemBuilder: (context, index) {
                            final group = groupedLogs[index];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HistoryGroupHeader(date: group.date, lang: lang),
                                ...group.logs.map((log) => _buildLogCard(log, theme, lang)),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(HistoryFilter filter, String label, ThemeData theme) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _currentFilter = filter),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildLogCard(NotificationLog log, ThemeData theme, String lang) {
    final isWarning = log.message.contains('cooldown') || log.message.contains('Suppressed');
    final isUpward = log.title.contains('🟢') ||
        log.title.contains('صعود') ||
        log.title.contains('↗️') ||
        log.title.contains('+') ||
        log.title.contains('Surged');
    final isDownward = log.title.contains('🔴') ||
        log.title.contains('افت') ||
        log.title.contains('ریزش') ||
        log.title.contains('↘️') ||
        log.title.contains('-') ||
        log.title.contains('Dropped');

    final Color statusColor = isWarning
        ? AppTokens.warning
        : (isUpward
            ? AppTokens.positive
            : (isDownward ? AppTokens.negative : theme.colorScheme.primary));

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space4,
      ),
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    log.marketSymbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.space6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      log.exchangeId.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                _formatTimestamp(log.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space6),

          if (log.title.isNotEmpty) ...[
            Text(
              log.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 4),
          ],

          Text(
            log.message,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppTokens.space6),

          Row(
            children: [
              Text(
                '${AppStrings.get('trigger_price_label', lang)} ',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
              Text(
                '\$${log.triggeredPrice.toStringAsFixed(log.triggeredPrice < 5 ? 4 : 2)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isUpward ? Icons.trending_up_rounded : (isDownward ? Icons.trending_down_rounded : Icons.info_outline_rounded),
                size: 16,
                color: statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_GroupedLogItem> _groupLogsByDay(List<NotificationLog> logs) {
    final Map<String, List<NotificationLog>> map = {};

    for (final log in logs) {
      final key = '${log.timestamp.year}-${log.timestamp.month}-${log.timestamp.day}';
      map.putIfAbsent(key, () => []).add(log);
    }

    final groups = <_GroupedLogItem>[];
    for (final entry in map.entries) {
      final firstLog = entry.value.first;
      groups.add(_GroupedLogItem(
        date: DateTime(firstLog.timestamp.year, firstLog.timestamp.month, firstLog.timestamp.day),
        logs: entry.value,
      ));
    }

    return groups;
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _GroupedLogItem {
  final DateTime date;
  final List<NotificationLog> logs;

  _GroupedLogItem({required this.date, required this.logs});
}
