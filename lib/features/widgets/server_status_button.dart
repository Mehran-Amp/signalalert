import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/server_alert_service.dart';

enum ServerConnectionStatus { checking, online, offline }

class ServerStatusButton extends StatefulWidget {
  final String lang;

  const ServerStatusButton({
    super.key,
    required this.lang,
  });

  @override
  State<ServerStatusButton> createState() => _ServerStatusButtonState();
}

class _ServerStatusButtonState extends State<ServerStatusButton> {
  ServerConnectionStatus _status = ServerConnectionStatus.checking;
  int? _latencyMs;
  int? _activeServerAlerts;
  int? _totalServerAlerts;
  String? _lastError;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _checkServerHealth();
    // Periodically ping server every 20 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkServerHealth();
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    setState(() => _status = ServerConnectionStatus.checking);

    final candidateUrls = [
      ServerAlertService.baseUrl,
      'https://aisocialfeed.com',
      'http://5.9.73.43:8000',
      'http://aisocialfeed.com:8000',
    ].toSet().toList();

    for (final testUrlStr in candidateUrls) {
      final stopwatch = Stopwatch()..start();
      try {
        final url = Uri.parse(testUrlStr);
        final res = await http.get(url).timeout(const Duration(seconds: 3));
        stopwatch.stop();

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data.containsKey('status') && data['status'] == 'online') {
            ServerAlertService.setBaseUrl(testUrlStr);
            if (mounted) {
              setState(() {
                _status = ServerConnectionStatus.online;
                _latencyMs = stopwatch.elapsedMilliseconds;
                _activeServerAlerts = data['active_alerts'] as int?;
                _totalServerAlerts = data['total_alerts'] as int?;
                _lastError = null;
              });
            }
            return; // Success! Exit early
          }
        }
      } catch (e) {
        // Try next candidate URL
      }
    }

    // If all candidate URLs failed:
    if (mounted) {
      setState(() {
        _status = ServerConnectionStatus.offline;
        _latencyMs = null;
        _lastError = 'سرور پایتون خاموش است یا .htaccess ست نشده است.';
      });
    }
  }

  void _showServerDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isFa = widget.lang == 'fa' || widget.lang == 'ar' || widget.lang == 'ckb';
    final urlController = TextEditingController(text: ServerAlertService.baseUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _status == ServerConnectionStatus.online
                              ? Colors.green.withValues(alpha: 0.15)
                              : (_status == ServerConnectionStatus.checking
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _status == ServerConnectionStatus.online
                              ? Icons.cell_tower_rounded
                              : (_status == ServerConnectionStatus.checking
                                  ? Icons.sync_rounded
                                  : Icons.signal_cellular_connected_no_internet_4_bar_rounded),
                          color: _status == ServerConnectionStatus.online
                              ? Colors.green
                              : (_status == ServerConnectionStatus.checking ? Colors.orange : Colors.red),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFa ? 'وضعیت اتصال به سرور پایتون' : 'Python Server Connection Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _status == ServerConnectionStatus.online
                                  ? (isFa ? 'متصل و فعال (پایش آنلاین)' : 'Connected & Online')
                                  : (_status == ServerConnectionStatus.checking
                                      ? (isFa ? 'در حال بررسی اتصال...' : 'Checking connection...')
                                      : (isFa ? 'قطع ارتباط با سرور' : 'Disconnected')),
                              style: TextStyle(
                                fontSize: 12,
                                color: _status == ServerConnectionStatus.online
                                    ? Colors.green
                                    : (_status == ServerConnectionStatus.checking ? Colors.orange : Colors.red),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Info Cards
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          theme: theme,
                          label: isFa ? 'آدرس سرور:' : 'Server Address:',
                          value: ServerAlertService.baseUrl,
                          icon: Icons.dns_rounded,
                        ),
                        const Divider(height: 18),
                        _buildInfoRow(
                          theme: theme,
                          label: isFa ? 'زمان پاسخگویی (Ping):' : 'Response Time:',
                          value: _latencyMs != null ? '$_latencyMs ms' : '---',
                          icon: Icons.speed_rounded,
                        ),
                        const Divider(height: 18),
                        _buildInfoRow(
                          theme: theme,
                          label: isFa ? 'هشدارهای فعال روی سرور:' : 'Active Alerts on Server:',
                          value: _activeServerAlerts != null ? '$_activeServerAlerts عدد' : '---',
                          icon: Icons.notifications_active_rounded,
                        ),
                        if (_lastError != null && _status == ServerConnectionStatus.offline) ...[
                          const Divider(height: 18),
                          _buildInfoRow(
                            theme: theme,
                            label: isFa ? 'علت عدم اتصال:' : 'Reason:',
                            value: _lastError!,
                            icon: Icons.warning_amber_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Edit Server URL Input
                  Text(
                    isFa ? 'تغییر آدرس سرور پایتون (Server IP / Domain):' : 'Update Server Address:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'https://aisocialfeed.com',
                      prefixIcon: Icon(Icons.link_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final newUrl = urlController.text.trim();
                            if (newUrl.isNotEmpty) {
                              ServerAlertService.setBaseUrl(newUrl);
                            }
                            await _checkServerHealth();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            isFa ? 'بررسی مجدد' : 'Recheck',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final newUrl = urlController.text.trim();
                            if (newUrl.isNotEmpty) {
                              ServerAlertService.setBaseUrl(newUrl);
                              _checkServerHealth();
                            }
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            isFa ? 'ذخیره و بستن' : 'Save & Close',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    String tooltipText;

    final isFa = widget.lang == 'fa' || widget.lang == 'ar' || widget.lang == 'ckb';

    switch (_status) {
      case ServerConnectionStatus.online:
        statusColor = Colors.green;
        statusIcon = Icons.sensors_rounded;
        tooltipText = isFa ? 'سرور متصل است ($_latencyMs ms)' : 'Server Online ($_latencyMs ms)';
        break;
      case ServerConnectionStatus.offline:
        statusColor = Colors.red;
        statusIcon = Icons.sensors_off_rounded;
        tooltipText = isFa ? 'قطع ارتباط با سرور' : 'Server Offline';
        break;
      case ServerConnectionStatus.checking:
        statusColor = Colors.amber;
        statusIcon = Icons.cell_tower_rounded;
        tooltipText = isFa ? 'در حال پایش اتصال سرور...' : 'Checking server connection...';
        break;
    }

    return IconButton(
      tooltip: tooltipText,
      onPressed: () => _showServerDetailSheet(context),
      icon: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 20,
              color: statusColor,
            ),
          ),
          if (_status == ServerConnectionStatus.online)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
