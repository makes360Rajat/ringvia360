import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/app_lock_service.dart';
import '../../services/telemetry_sync_service.dart';
import 'setup_wizard_screen.dart';
import '../widgets/caller_id_dialog.dart';
import '../widgets/after_call_dialog.dart';

class HomeScreen extends StatefulWidget {
  final TelemetrySyncService syncService;
  final VoidCallback onUnpaired;

  const HomeScreen({
    super.key,
    required this.syncService,
    required this.onUnpaired,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _hasPromptedOutcome = false;
  bool _hasPromptedCallerId = false;
  BuildContext? _callerIdDialogContext;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _expandedCallUid;
  String? _selectedContactFilter;
  String _waFilter = 'all';
  String _callTypeFilter = 'all'; // 'all', 'incoming', 'outgoing', 'missed', 'recordings'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (widget.syncService.isPlayingAudio) {
          widget.syncService.stopRecording();
        }
        setState(() {
          _expandedCallUid = null;
        });
      }
    });
    widget.syncService.addListener(_onServiceChanged);
    widget.syncService.checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.syncService.isPlayingAudio) {
      widget.syncService.stopRecording();
    }
    _searchController.dispose();
    widget.syncService.removeListener(_onServiceChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.syncService.checkPermissions();
      widget.syncService.fetchPlatformDeviceInfo();
      widget.syncService.setForeground(true);
      if (widget.syncService.hasCallLogPermission) {
        widget.syncService.syncDeviceCallLogs();
      }
      if (widget.syncService.hasSmsPermission) {
        widget.syncService.syncDeviceSms();
      }
      widget.syncService.scanLocalRecordings();
      widget.syncService.syncNow();
      _onServiceChanged();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      widget.syncService.setForeground(false);
    }
  }

  EdgeInsets _getTabContentPadding(
    BuildContext context,
    TelemetrySyncService service, {
    double top = 8,
    double horizontal = 14,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      36.0,
    );
  }

  void _onServiceChanged() {
    if (!mounted) return;
    if (!widget.syncService.isPaired) {
      widget.onUnpaired();
      return;
    }

    // 1. Truecaller-like Active Caller ID Popup
    final activeCaller = widget.syncService.activeCallerId;
    if (activeCaller != null && !_hasPromptedCallerId) {
      _hasPromptedCallerId = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogCtx) {
            _callerIdDialogContext = dialogCtx;
            return CallerIdDialog(
              info: activeCaller,
              syncService: widget.syncService,
              onDismiss: () {
                widget.syncService.dismissCallerId();
              },
            );
          },
        ).then((_) {
          _callerIdDialogContext = null;
          _hasPromptedCallerId = false;
        });
      });
    } else if (activeCaller == null && _callerIdDialogContext != null) {
      try {
        if (Navigator.of(_callerIdDialogContext!).canPop()) {
          Navigator.of(_callerIdDialogContext!).pop();
        }
      } catch (_) {}
      _callerIdDialogContext = null;
      _hasPromptedCallerId = false;
    }

    // 2. Automated After-Call Sales Outcome & Follow-up Truecaller Dialog
    final afterCall = widget.syncService.activeAfterCallEvent;
    if (afterCall != null && !_hasPromptedOutcome) {
      _hasPromptedOutcome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogCtx) => AfterCallDialog(
            event: afterCall,
            syncService: widget.syncService,
            onDismiss: () {
              widget.syncService.dismissAfterCallPopup();
            },
          ),
        ).then((_) {
          widget.syncService.dismissAfterCallPopup();
          _hasPromptedOutcome = false;
        });
      });
    }
    setState(() {});
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (isToday) return timeStr;
    return '${d.day}/${d.month} $timeStr';
  }

  String _formatDialerDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, ${date.day} $month';
  }

  String _formatDialerTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'pm' : 'am';
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  String _formatExactDateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    final sec = d.second.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$min:$sec $ampm';
  }

  bool _isSavedContact(String? rawName, String? rawNumber) {
    final name = (rawName ?? '').trim();
    final number = (rawNumber ?? '').trim();
    if (name.isEmpty) return false;
    final lower = name.toLowerCase();
    if (lower == 'unknown' ||
        lower == 'unknown caller' ||
        lower == 'unsaved' ||
        lower == 'un saved' ||
        lower == 'private number' ||
        lower == 'no caller id') {
      return false;
    }
    final nameDigits = name.replaceAll(RegExp(r'\D'), '');
    final numDigits = number.replaceAll(RegExp(r'\D'), '');
    if (name == number || (nameDigits.isNotEmpty && nameDigits == numDigits)) {
      return false;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(name)) {
      return false;
    }
    return true;
  }

  void _promptPinForSensitiveAction(VoidCallback onAuthorized) {
    final config = widget.syncService.config;
    if (!config.appLockEnabled || config.appLockHash.isEmpty) {
      onAuthorized();
      return;
    }

    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = ctx.stColors;
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'App Lock - Enter PIN',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              letterSpacing: 8,
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '••••',
              fillColor: colors.surfaceColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = pinController.text.trim();
                if (AppLockService.verifyPin(pin: pin, config: config)) {
                  Navigator.pop(ctx);
                  onAuthorized();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final colors = context.stColors;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Appearance & Theme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                title: Text('Follow System', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Adapts to phone OS settings', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                activeColor: colors.primary,
                onChanged: (val) {
                  if (val != null) {
                    themeProvider.setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                title: Text('Light Mode', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Crisp white clean canvas', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                activeColor: colors.primary,
                onChanged: (val) {
                  if (val != null) {
                    themeProvider.setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                title: Text('Dark Mode', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Obsidian slate night theme', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                activeColor: colors.primary,
                onChanged: (val) {
                  if (val != null) {
                    themeProvider.setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final isDark = context.isDarkMode;
    final themeProvider = context.watch<ThemeProvider>();

    final service = widget.syncService;
    final device = service.device;
    final staff = service.staff;

    final totalCalls = service.calls.length;
    final connectedCalls = service.calls.where((c) => c.duration > 0).length;
    final totalTalkSeconds = service.calls.fold<int>(0, (sum, c) => sum + c.duration);
    final whatsappCallsCount =
        service.whatsappEvents.where((e) => e.kind == 'whatsapp_call').length;
    final smsCount = service.smsList.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: service.isPaired ? colors.primary : colors.warning,
                boxShadow: [
                  BoxShadow(
                    color: (service.isPaired ? colors.primary : colors.warning)
                        .withOpacity(0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device?.name ?? 'Sales Phone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    staff?.name != null ? 'Rep: ${staff!.name}' : 'CRM Telemetry Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle Action Button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggleTheme(context),
          ),

          // Real-time Sync Action Button
          IconButton(
            icon: service.isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  )
                : Icon(
                    Icons.sync_rounded,
                    color: colors.textPrimary,
                    size: 22,
                  ),
            tooltip: service.isSyncing ? 'Syncing with CRM...' : 'Sync Phone & Server',
            onPressed: service.isSyncing ? null : () => service.syncAllLocalAndRemote(),
          ),

          // Popup Menu
          PopupMenuButton<String>(
            color: colors.cardBackground,
            icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            onSelected: (val) {
              if (val == 'theme_mode') {
                _showThemeSelectionDialog(context);
              } else if (val == 'permissions') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SetupWizardScreen(
                      syncService: service,
                      onCompleted: () => Navigator.pop(context),
                    ),
                  ),
                );
              } else if (val == 'clear_and_rescan') {
                service.clearLocalDataAndRescan();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cleared local cache. Rescanning calls & recordings from phone...'),
                  ),
                );
              } else if (val == 'scan_recordings') {
                service.scanLocalRecordings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanning phone storage for call audio recordings...'),
                  ),
                );
              } else if (val == 'resync_all_history') {
                service.forceResyncAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Re-syncing all historical calls & SMS to CRM...'),
                  ),
                );
              } else if (val == 'scan_history') {
                service.syncAllLocalAndRemote();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scanning phone call history, SMS & syncing...'),
                  ),
                );
              } else if (val == 'unpair') {
                _promptPinForSensitiveAction(() {
                  service.unpair();
                  widget.onUnpaired();
                });
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'theme_mode',
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text('Theme: ${isDark ? "Dark" : "Light"}', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_and_rescan',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, color: colors.warning, size: 20),
                    const SizedBox(width: 10),
                    Text('Clear Local Data & Re-scan', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scan_recordings',
                child: Row(
                  children: [
                    Icon(Icons.mic_rounded, color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Scan Phone Audio Recordings', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'resync_all_history',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_rounded, color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Upload All History to CRM', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scan_history',
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text('Scan Phone History & Sync', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: colors.secondaryLight, size: 20),
                    const SizedBox(width: 10),
                    Text('Check Permissions (7 Checks)', style: TextStyle(color: colors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unpair',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: colors.danger, size: 20),
                    const SizedBox(width: 10),
                    Text('Unpair Device', style: TextStyle(color: colors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: 'Calls ($totalCalls)'),
            Tab(text: 'WhatsApp (${service.whatsappEvents.length})'),
            Tab(text: 'SMS ($smsCount)'),
            Tab(text: 'Recordings (${service.localRecordings.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending Sync'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (service.pendingQueueCount + service.pendingRecordingsCount > 0)
                          ? colors.warning
                          : colors.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${service.pendingQueueCount + service.pendingRecordingsCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (service.pendingQueueCount + service.pendingRecordingsCount > 0)
                            ? Colors.black
                            : colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Tab(text: 'Call Lists (${service.callLists.length})'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Live Real-Time Sync Progress Banner
            if (service.isSyncing) _buildSyncProgressBanner(service),

            // Proactive Permission Warning Banner
            _buildPermissionAlertBanner(service),

            // KPI Metric Banner
            _buildKpiBanner(
              totalCalls: totalCalls,
              connectedCalls: connectedCalls,
              talkSeconds: totalTalkSeconds,
              waCalls: whatsappCallsCount,
              pendingQueue: service.pendingQueueCount,
              statusMsg: service.statusMessage,
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCallsTab(service),
                  _buildWhatsAppTab(service),
                  _buildSmsTab(service),
                  _buildRecordingsTab(service),
                  _buildPendingTab(service),
                  _buildCallListsTab(service),
                ],
              ),
            ),

            // Floating Audio Player bar
            if (service.isPlayingAudio || service.activeAudioPath != null)
              _buildAudioPlayerBar(service),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressBanner(TelemetrySyncService service) {
    final colors = context.stColors;
    final percent = (service.syncProgress * 100).toInt().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(
          bottom: BorderSide(color: colors.primary, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.syncProgressMessage.isNotEmpty
                      ? service.syncProgressMessage
                      : 'Syncing telemetry & recordings with CRM...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: service.syncProgress > 0 ? service.syncProgress : null,
              minHeight: 4,
              backgroundColor: colors.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionAlertBanner(TelemetrySyncService service) {
    final colors = context.stColors;
    final missing = service.missingPermissionNames;
    if (missing.isEmpty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetupWizardScreen(
              syncService: service,
              onCompleted: () => Navigator.pop(context),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.warning.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${missing.length} Telemetry ${missing.length == 1 ? "Permission" : "Permissions"} Needed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colors.warning,
                    ),
                  ),
                  Text(
                    'Missing: ${missing.join(", ")}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SetupWizardScreen(
                      syncService: service,
                      onCompleted: () => Navigator.pop(context),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBanner({
    required int totalCalls,
    required int connectedCalls,
    required int talkSeconds,
    required int waCalls,
    required int pendingQueue,
    required String statusMsg,
  }) {
    final colors = context.stColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniKpi(
                'Calls',
                '$totalCalls',
                Icons.call_rounded,
                colors.primary,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'Connected',
                '$connectedCalls',
                Icons.call_made_rounded,
                colors.success,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'Talk Time',
                _formatDuration(talkSeconds),
                Icons.timer_rounded,
                colors.secondary,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'WhatsApp',
                '$waCalls',
                Icons.chat_bubble_rounded,
                colors.whatsappGreen,
                onTap: () => _tabController.animateTo(1),
              ),
              _buildMiniKpi(
                'Queue',
                '$pendingQueue',
                Icons.cloud_upload_rounded,
                pendingQueue > 0 ? colors.warning : colors.textMuted,
                onTap: () => _tabController.animateTo(4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusMsg,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final colors = context.stColors;
    final isDark = context.isDarkMode;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: colors.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? colors.surfaceLight.withOpacity(0.3) : colors.border,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. CALLS TAB
  Widget _buildCallsTab(TelemetrySyncService service) {
    final colors = context.stColors;

    if (service.calls.isEmpty) {
      if (!service.hasCallLogPermission) {
        return _buildEmptyState(
          icon: Icons.security_rounded,
          title: 'Call Log Permission Required',
          subtitle:
              'Please grant Call Log and Storage permissions to read your phone call history and sense live incoming & outgoing calls.',
          actionLabel: 'Grant Call Log Permission',
          onAction: () => service.requestAllPermissions(),
        );
      }
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No Calls Loaded From Phone',
        subtitle:
            'Tap below to read call history from your device local storage and sync to CRM server.',
        actionLabel: 'Scan Phone Call History',
        onAction: () => service.syncAllLocalAndRemote(),
      );
    }

    final activeFilter = (_selectedContactFilter != null && _selectedContactFilter!.isNotEmpty)
        ? _selectedContactFilter!
        : _searchQuery;

    final filtered = service.calls.where((c) {
      if (_callTypeFilter == 'incoming' && c.direction != 'incoming') return false;
      if (_callTypeFilter == 'outgoing' && c.direction != 'outgoing') return false;
      if (_callTypeFilter == 'missed' && c.direction != 'missed' && c.direction != 'rejected') {
        return false;
      }
      if (_callTypeFilter == 'recordings' &&
          !c.recording &&
          (c.recordingPath == null || c.recordingPath!.isEmpty)) {
        return false;
      }

      if (activeFilter.isEmpty) return true;
      final q = activeFilter.toLowerCase();
      final numNorm = c.number.replaceAll(RegExp(r'\D'), '');
      final qNorm = q.replaceAll(RegExp(r'\D'), '');
      final bool isSaved = _isSavedContact(c.name, c.number);
      final String displayName = isSaved ? c.name : 'Un Saved';
      if (displayName.toLowerCase().contains(q)) return true;
      if (c.number.toLowerCase().contains(q)) return true;
      if (qNorm.isNotEmpty &&
          numNorm.endsWith(
              qNorm.length >= 10 ? qNorm.substring(qNorm.length - 10) : qNorm)) {
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    final bool isSingleContact = activeFilter.isNotEmpty &&
        filtered.isNotEmpty &&
        filtered.every((c) =>
            (c.name.isNotEmpty && c.name.toLowerCase() == filtered.first.name.toLowerCase()) ||
            (c.number.replaceAll(RegExp(r'\D'), '').endsWith(
                filtered.first.number.replaceAll(RegExp(r'\D'), '').length >= 10
                    ? filtered.first.number
                        .replaceAll(RegExp(r'\D'), '')
                        .substring(filtered.first.number.replaceAll(RegExp(r'\D'), '').length - 10)
                    : filtered.first.number)));

    final contactName = filtered.isNotEmpty
        ? (_isSavedContact(filtered.first.name, filtered.first.number)
            ? filtered.first.name
            : 'Un Saved')
        : '';
    final contactNumber = filtered.isNotEmpty ? filtered.first.number : '';

    final Map<String, List<dynamic>> grouped = {};
    for (final call in filtered) {
      final header = _formatDialerDateHeader(DateTime.fromMillisecondsSinceEpoch(call.time));
      grouped.putIfAbsent(header, () => []).add(call);
    }

    return Column(
      children: [
        // Calls Sync Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncCallsOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync Calls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'call'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              if (service.pendingCallsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.warning.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: colors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingCallsCount} Pending',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.warning),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.success.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: colors.success),
                      const SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Modern Rounded Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceColor,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                        _selectedContactFilter = null;
                      });
                    },
                    style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search contact name or phone number...',
                      hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty || _selectedContactFilter != null)
                  GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _searchController.clear();
                      if (service.isPlayingAudio || service.activeAudioPath != null) {
                        service.stopRecording();
                      }
                      setState(() {
                        _searchQuery = '';
                        _selectedContactFilter = null;
                        _expandedCallUid = null;
                      });
                    },
                    child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                  ),
              ],
            ),
          ),
        ),

        // Quick Filter Chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              _buildCallFilterChip('all', 'All Calls (${service.calls.length})'),
              const SizedBox(width: 6),
              _buildCallFilterChip('incoming', 'Incoming'),
              const SizedBox(width: 6),
              _buildCallFilterChip('outgoing', 'Outgoing'),
              const SizedBox(width: 6),
              _buildCallFilterChip('missed', 'Missed'),
              const SizedBox(width: 6),
              _buildCallFilterChip('recordings', 'Has Audio'),
            ],
          ),
        ),

        // Contact Header Card if single contact filtered
        if (isSingleContact)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _searchController.clear();
                    if (service.isPlayingAudio || service.activeAudioPath != null) {
                      service.stopRecording();
                    }
                    setState(() {
                      _searchQuery = '';
                      _selectedContactFilter = null;
                      _expandedCallUid = null;
                    });
                  },
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primary,
                  child: Text(
                    contactName.isNotEmpty ? contactName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contactNumber,
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Grouped Call List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No calls found matching filter',
                    style: TextStyle(color: colors.textMuted, fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  color: colors.primary,
                  backgroundColor: colors.cardBackground,
                  onRefresh: () async {
                    if (service.hasCallLogPermission) {
                      await service.syncDeviceCallLogs();
                    }
                    await service.syncCallsOnly();
                  },
                  child: ListView.builder(
                    padding: _getTabContentPadding(context, service, horizontal: 14, top: 4),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: grouped.keys.length,
                    itemBuilder: (ctx, groupIdx) {
                      final dateHeader = grouped.keys.elementAt(groupIdx);
                      final callsInGroup = grouped[dateHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 12, color: colors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  dateHeader,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(context.isDarkMode ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Material(
                                color: Colors.transparent,
                                child: Column(
                                  children: [
                                    for (int callIdx = 0;
                                        callIdx < callsInGroup.length;
                                        callIdx++) ...[
                                      if (callIdx > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 0.8,
                                          indent: 72,
                                          endIndent: 14,
                                          color: colors.border,
                                        ),
                                      _buildCallItem(
                                          service, callsInGroup[callIdx], isSingleContact),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCallFilterChip(String key, String label) {
    final colors = context.stColors;
    final isSelected = _callTypeFilter == key;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _callTypeFilter = key),
      selectedColor: colors.primary.withOpacity(0.18),
      checkmarkColor: colors.primary,
      backgroundColor: colors.surfaceColor,
      side: BorderSide(
        color: isSelected ? colors.primary : colors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? colors.primary : colors.textSecondary,
      ),
    );
  }

  Widget _buildCallItem(TelemetrySyncService service, dynamic call, bool isSingleContact) {
    final colors = context.stColors;
    final isIncoming = call.direction == 'incoming';
    final isMissed = call.direction == 'missed' || call.direction == 'rejected';

    final icon = isMissed
        ? Icons.call_missed_rounded
        : (isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded);
    final iconColor = isMissed
        ? colors.danger
        : (isIncoming ? colors.info : colors.primary);

    final hasRec =
        call.recording || (call.recordingPath != null && call.recordingPath!.isNotEmpty);
    final isExpanded = _expandedCallUid == call.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Call Row
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() {
              if (_expandedCallUid == call.uid) {
                _expandedCallUid = null;
                if (service.isPlayingAudio || service.activeAudioPath != null) {
                  service.stopRecording();
                }
              } else {
                if (service.isPlayingAudio || service.activeAudioPath != null) {
                  service.stopRecording();
                }
                _expandedCallUid = call.uid;
              }
            });
          },
          child: _callCardBody(call, icon, iconColor, hasRec),
        ),

        // Expanded Details & Audio Player
        if (isExpanded)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: colors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      call.number,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'SIM ${call.sim}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(
                          call.syncStatus == 'synced'
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          size: 13,
                          color: call.syncStatus == 'synced' ? colors.success : colors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          call.syncStatus == 'synced' ? 'Synced to CRM' : 'Pending Sync',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: call.syncStatus == 'synced' ? colors.success : colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exact Time: ${_formatExactDateTime(call.time as int)}',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),

                if (!isSingleContact && (call.name.isNotEmpty || call.number.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedContactFilter = call.name.isNotEmpty ? call.name : call.number;
                        _searchController.text = _selectedContactFilter!;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'View all call history for ${call.name.isNotEmpty ? call.name : call.number}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // Quick Call Actions Row (Lead outcome, CRM Caller ID, WhatsApp)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        final eventObj = call is SalesTrackEvent
                            ? call
                            : SalesTrackEvent(
                                uid: call.uid?.toString() ?? 'call-${DateTime.now().millisecondsSinceEpoch}',
                                kind: 'call',
                                time: call.time as int,
                                direction: call.direction?.toString() ?? 'incoming',
                                number: call.number?.toString() ?? '',
                                name: call.name?.toString() ?? '',
                                duration: call.duration as int? ?? 0,
                                recording: hasRec,
                                recordingPath: call.recordingPath?.toString(),
                              );
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (dialogCtx) => AfterCallDialog(
                            event: eventObj,
                            syncService: service,
                            onDismiss: () {},
                          ),
                        );
                      },
                      icon: const Icon(Icons.note_alt_outlined, size: 14),
                      label: const Text('Edit Lead / Log Outcome', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final info = CallerIdInfo(
                          phoneNumber: call.number,
                          direction: call.direction?.toString() ?? 'incoming',
                          name: call.name.isNotEmpty ? call.name : call.number,
                          isSearching: true,
                        );
                        showDialog(
                          context: context,
                          builder: (_) => CallerIdDialog(
                            info: info,
                            syncService: service,
                            onDismiss: () => service.dismissCallerId(),
                          ),
                        );
                        service.lookupAndEnrichCaller(call.number, call.name, call.direction);
                      },
                      icon: const Icon(Icons.badge_outlined, size: 14),
                      label: const Text('Caller CRM Info', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => service.openWhatsAppChat(call.number),
                      icon: Icon(Icons.chat_rounded, size: 16, color: colors.whatsappGreen),
                      tooltip: 'Chat on WhatsApp',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.whatsappGreen.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),

                // Inline Audio Player with Seekbar & Play Button
                if (hasRec && call.recordingPath != null && call.recordingPath!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInlineAudioPlayer(service, call),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _callCardBody(dynamic call, IconData icon, Color iconColor, bool hasRec) {
    final colors = context.stColors;
    final String rawName = (call.name?.toString() ?? '').trim();
    final String number = (call.number?.toString() ?? '').trim();
    final bool isSaved = _isSavedContact(rawName, number);
    final String title = isSaved ? rawName : 'Un Saved';
    final bool synced = call.syncStatus == 'synced';
    final int sim = call.sim is int ? call.sim as int : 0;
    final int seconds = call.duration is int ? call.duration as int : 0;
    final String direction = call.direction == 'incoming'
        ? 'Incoming call'
        : call.direction == 'outgoing'
            ? 'Outgoing call'
            : call.direction == 'rejected'
                ? 'Rejected call'
                : call.direction == 'missed'
                    ? 'Missed call'
                    : 'Call';

    Widget badge(String text, IconData glyph, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4), width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(glyph, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: iconColor.withOpacity(0.12),
              border: Border.all(color: iconColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (sim > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: colors.surfaceColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'SIM $sim',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (number.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: colors.textMuted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Call at ${_formatDialerTime(call.time as int)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: direction,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' \u2022 ${seconds > 0 ? _talkTime(seconds) : (call.direction == 'outgoing' ? 'Not connected' : '0 secs')}',
                        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              badge(
                synced ? 'SYNCED' : 'PENDING',
                synced ? Icons.check_circle_rounded : Icons.schedule_rounded,
                synced ? colors.success : colors.warning,
              ),
              if (hasRec) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded, size: 13, color: colors.primary),
                      const SizedBox(width: 3),
                      Text(
                        'REC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _talkTime(int seconds) {
    if (seconds < 60) return '$seconds secs';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h hr $m mins';
    return s > 0 ? '$m mins $s secs' : '$m mins';
  }

  Widget _buildInlineAudioPlayer(TelemetrySyncService service, dynamic call) {
    final colors = context.stColors;
    final isThisPlaying = service.isPlayingAudio && service.activeAudioPath == call.recordingPath;
    final isThisActive = service.activeAudioPath == call.recordingPath;

    final totalDurationMs = (isThisActive && service.audioDurationMs > 0)
        ? service.audioDurationMs
        : (call.duration > 0 ? call.duration * 1000 : 60000);

    final currentPosMs = isThisActive ? service.audioCurrentPosMs : 0;
    final progress =
        (totalDurationMs > 0) ? (currentPosMs / totalDurationMs).clamp(0.0, 1.0) : 0.0;

    final currentSec = currentPosMs ~/ 1000;
    final totalSec = totalDurationMs ~/ 1000;

    final currentStr =
        '${currentSec ~/ 60}:${(currentSec % 60).toString().padLeft(2, '0')}';
    final totalStr = '${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}';

    final fileName = call.recordingPath!.split('/').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$currentStr / $totalStr',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Material(
                color: colors.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(
                    isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (isThisPlaying) {
                      service.pauseRecording();
                    } else if (isThisActive) {
                      service.resumeRecording();
                    } else {
                      service.playRecording(call.recordingPath!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surfaceColor,
                    thumbColor: colors.primary,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (val) {
                      final targetMs = (val * totalDurationMs).toInt();
                      if (isThisActive) {
                        service.seekRecording(targetMs);
                      } else {
                        service.playRecording(call.recordingPath!);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. WHATSAPP TAB
  Widget _buildWhatsAppTab(TelemetrySyncService service) {
    final colors = context.stColors;

    if (service.whatsappEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_rounded,
        title: 'No WhatsApp Activity Sensed',
        subtitle:
            'Ensure Notification Access is enabled to sense calls and chats from WhatsApp and WhatsApp Business.',
        actionLabel: 'Enable Notification Access',
        onAction: () => service.openNotificationListenerSettings(),
      );
    }

    final allEvents = service.whatsappEvents;
    final messageCount = allEvents.where((e) => e.kind == 'whatsapp_message').length;
    final callCount = allEvents.where((e) => e.kind == 'whatsapp_call').length;

    final filteredList = allEvents.where((ev) {
      if (_waFilter == 'messages') return ev.kind == 'whatsapp_message';
      if (_waFilter == 'calls') return ev.kind == 'whatsapp_call';
      return true;
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return Column(
      children: [
        if (!service.hasWhatsAppAccessPermission)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.whatsappGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.whatsappGreen.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.mark_chat_unread_rounded, color: colors.whatsappGreen, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Call Access Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.whatsappGreen,
                        ),
                      ),
                      Text(
                        'Enable Notification Access to sense live WhatsApp & WhatsApp Business calls.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => service.openNotificationListenerSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.whatsappGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

        // WhatsApp Sync Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncWhatsAppOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.whatsappGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'whatsapp'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              if (service.pendingWhatsAppCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.warning.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: colors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingWhatsAppCount} Pending',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.warning),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.success.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: colors.success),
                      const SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Filter chips: All, Messages, Calls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: Text('All (${service.whatsappEvents.length})'),
                selected: _waFilter == 'all',
                onSelected: (_) => setState(() => _waFilter = 'all'),
                selectedColor: colors.whatsappGreen.withOpacity(0.2),
                checkmarkColor: colors.whatsappGreen,
                backgroundColor: colors.surfaceColor,
                side: BorderSide(color: _waFilter == 'all' ? colors.whatsappGreen : colors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: _waFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'all' ? colors.whatsappGreen : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('Messages ($messageCount)'),
                selected: _waFilter == 'messages',
                onSelected: (_) => setState(() => _waFilter = 'messages'),
                selectedColor: colors.whatsappGreen.withOpacity(0.2),
                checkmarkColor: colors.whatsappGreen,
                backgroundColor: colors.surfaceColor,
                side: BorderSide(color: _waFilter == 'messages' ? colors.whatsappGreen : colors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: _waFilter == 'messages' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'messages' ? colors.whatsappGreen : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('Calls ($callCount)'),
                selected: _waFilter == 'calls',
                onSelected: (_) => setState(() => _waFilter = 'calls'),
                selectedColor: colors.whatsappGreen.withOpacity(0.2),
                checkmarkColor: colors.whatsappGreen,
                backgroundColor: colors.surfaceColor,
                side: BorderSide(color: _waFilter == 'calls' ? colors.whatsappGreen : colors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: _waFilter == 'calls' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'calls' ? colors.whatsappGreen : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _waFilter == 'messages'
                            ? Icons.chat_bubble_outline_rounded
                            : _waFilter == 'calls'
                                ? Icons.phone_missed_rounded
                                : Icons.chat_rounded,
                        size: 44,
                        color: colors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _waFilter == 'messages'
                            ? 'No WhatsApp Messages recorded'
                            : _waFilter == 'calls'
                                ? 'No WhatsApp Calls recorded'
                                : 'No WhatsApp Activity recorded',
                        style: TextStyle(fontSize: 14, color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: colors.whatsappGreen,
                  backgroundColor: colors.cardBackground,
                  onRefresh: () async {
                    await service.syncActiveWhatsAppNotifications();
                    await service.syncWhatsAppOnly();
                  },
                  child: ListView.builder(
                    padding: _getTabContentPadding(context, service, horizontal: 14, top: 8),
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, idx) {
                      final ev = filteredList[idx];
                      final isBusiness = ev.app == 'com.whatsapp.w4b';
                      final isCall = ev.kind == 'whatsapp_call';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isBusiness
                                    ? colors.whatsappBusiness
                                    : colors.whatsappGreen)
                                .withOpacity(0.15),
                            child: Icon(
                              isCall
                                  ? (ev.media == 'video'
                                      ? Icons.videocam_rounded
                                      : Icons.phone_rounded)
                                  : Icons.chat_rounded,
                              color: isBusiness
                                  ? colors.whatsappBusiness
                                  : colors.whatsappGreen,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ev.name.isNotEmpty ? ev.name : 'WhatsApp Contact',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isBusiness
                                          ? colors.whatsappBusiness
                                          : colors.whatsappGreen)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBusiness ? 'BUSINESS' : 'PERSONAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isBusiness
                                        ? colors.whatsappBusiness
                                        : colors.whatsappGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            isCall
                                ? 'WhatsApp Call (${_formatDuration(ev.duration)})'
                                : (ev.text ?? 'Message'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(ev.time),
                                style: TextStyle(fontSize: 11, color: colors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ev.syncStatus == 'synced'
                                      ? colors.success.withOpacity(0.12)
                                      : colors.warning.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: ev.syncStatus == 'synced'
                                        ? colors.success.withOpacity(0.3)
                                        : colors.warning.withOpacity(0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  ev.syncStatus == 'synced' ? 'SYNCED' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: ev.syncStatus == 'synced'
                                        ? colors.success
                                        : colors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // 3. SMS TAB
  Widget _buildSmsTab(TelemetrySyncService service) {
    final colors = context.stColors;

    if (service.smsList.isEmpty) {
      if (!service.hasSmsPermission) {
        return _buildEmptyState(
          icon: Icons.sms_failed_rounded,
          title: 'SMS Permission Required',
          subtitle: 'Grant SMS permissions to read and sense carrier SMS messages.',
          actionLabel: 'Grant SMS Permission',
          onAction: () => service.requestAllPermissions(),
        );
      }
      return _buildEmptyState(
        icon: Icons.sms_rounded,
        title: 'No SMS Messages Loaded',
        subtitle: 'Carrier SMS logs can be scanned and displayed here.',
        actionLabel: 'Scan Device SMS',
        onAction: () => service.syncDeviceSms(),
      );
    }

    final sortedSms = List<SalesTrackEvent>.from(service.smsList)
      ..sort((a, b) => b.time.compareTo(a.time));

    return Column(
      children: [
        // SMS Sync Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncSmsOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync SMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'sms'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              if (service.pendingSmsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.warning.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: colors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingSmsCount} Pending',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.warning),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.success.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: colors.success),
                      const SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: colors.secondary,
            backgroundColor: colors.cardBackground,
            onRefresh: () async {
              if (service.hasSmsPermission) {
                await service.syncDeviceSms();
              }
              await service.syncSmsOnly();
            },
            child: ListView.builder(
              padding: _getTabContentPadding(context, service, horizontal: 14, top: 8),
              itemCount: sortedSms.length,
              itemBuilder: (ctx, idx) {
                final sms = sortedSms[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.secondary.withOpacity(0.15),
                      child: Icon(Icons.sms_rounded, color: colors.secondary, size: 20),
                    ),
                    title: Text(
                      sms.name.isNotEmpty ? sms.name : sms.number,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      sms.text ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(sms.time),
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sms.syncStatus == 'synced'
                                ? colors.success.withOpacity(0.12)
                                : colors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sms.syncStatus == 'synced'
                                  ? colors.success.withOpacity(0.3)
                                  : colors.warning.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            sms.syncStatus == 'synced' ? 'SYNCED' : 'PENDING',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: sms.syncStatus == 'synced'
                                  ? colors.success
                                  : colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 4. RECORDINGS TAB
  Widget _buildRecordingsTab(TelemetrySyncService service) {
    final colors = context.stColors;

    if (service.localRecordings.isEmpty) {
      if (!service.hasRecordingsFolderPermission) {
        return _buildEmptyState(
          icon: Icons.audio_file_rounded,
          title: 'Audio Storage Access Required',
          subtitle:
              'Grant audio storage permission so the app can locate and upload call audio recordings.',
          actionLabel: 'Grant Access',
          onAction: () => service.requestAllPermissions(),
        );
      }
      return _buildEmptyState(
        icon: Icons.music_off_rounded,
        title: 'No Call Audio Recordings Found',
        subtitle:
            'Recordings saved by Samsung, Xiaomi, or other dialers will be scanned automatically.',
        actionLabel: 'Scan Device Storage',
        onAction: () => service.scanLocalRecordings(),
      );
    }

    final sortedRecs = List<Map<String, dynamic>>.from(service.localRecordings)
      ..sort((a, b) {
        final tA = (a['lastModified'] as num?)?.toInt() ?? 0;
        final tB = (b['lastModified'] as num?)?.toInt() ?? 0;
        return tB.compareTo(tA);
      });

    return Column(
      children: [
        if (!service.hasRecordingsFolderPermission)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.warning.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.audio_file_rounded, color: colors.warning, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Storage Permission Needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: colors.warning,
                        ),
                      ),
                      Text(
                        'Grant audio storage permission to locate and upload call audio recordings.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => service.requestAllPermissions(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

        // Recordings Upload Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: service.isSyncing ? null : () => service.syncRecordingsOnly(),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                  label: const Text('Upload Recordings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: service.isSyncing ? null : () => service.scanLocalRecordings(),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Rescan Files', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                if (service.pendingRecordingsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.warning.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 12, color: colors.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${service.pendingRecordingsCount} Pending Upload',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.warning),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.success.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: colors.success),
                        const SizedBox(width: 4),
                        Text(
                          'All Uploaded',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.success),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: colors.primary,
            backgroundColor: colors.cardBackground,
            onRefresh: () async {
              await service.scanLocalRecordings();
              await service.syncRecordingsOnly();
            },
            child: ListView.builder(
              padding: _getTabContentPadding(context, service, horizontal: 14, top: 8),
              itemCount: sortedRecs.length,
              itemBuilder: (ctx, idx) {
                final rec = sortedRecs[idx];
                final path = rec['filePath']?.toString() ?? '';
                final name = rec['fileName']?.toString() ?? 'Call Recording';
                final isCurrent = service.activeAudioPath == path;

                final matchingCall = service.calls
                    .where((c) => c.recordingPath == path)
                    .firstOrNull;
                final isUploaded = matchingCall?.recordingSyncStatus == 'synced';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isCurrent ? colors.primary : colors.surfaceColor,
                      child: Icon(
                        isCurrent && service.isPlayingAudio
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isCurrent ? Colors.white : colors.textPrimary,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUploaded
                                ? colors.success.withOpacity(0.12)
                                : colors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isUploaded
                                  ? colors.success.withOpacity(0.3)
                                  : colors.warning.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isUploaded ? 'UPLOADED' : 'LOCAL ONLY',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isUploaded ? colors.success : colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      path,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isCurrent && service.isPlayingAudio
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: colors.primary,
                        size: 32,
                      ),
                      onPressed: () {
                        if (isCurrent && service.isPlayingAudio) {
                          service.pauseRecording();
                        } else if (isCurrent && !service.isPlayingAudio) {
                          service.resumeRecording();
                        } else {
                          service.playRecording(path);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 5. DEDICATED PENDING SYNC TAB
  Widget _buildPendingTab(TelemetrySyncService service) {
    final colors = context.stColors;

    final pendingCalls = service.calls.where((c) => c.syncStatus != 'synced').toList();
    final pendingWhatsApp =
        service.whatsappEvents.where((e) => e.syncStatus != 'synced').toList();
    final pendingSms = service.smsList.where((s) => s.syncStatus != 'synced').toList();
    final pendingRecordings = service.calls
        .where((c) =>
            (c.recording || (c.recordingPath != null && c.recordingPath!.isNotEmpty)) &&
            c.recordingSyncStatus != 'synced')
        .toList();

    final totalPending = pendingCalls.length +
        pendingWhatsApp.length +
        pendingSms.length +
        pendingRecordings.length;

    return Column(
      children: [
        // Pending Summary & Master Sync Action Header
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: totalPending > 0 ? colors.warning.withOpacity(0.35) : colors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildMiniKpi(
                    'Calls',
                    '${pendingCalls.length}',
                    Icons.call_rounded,
                    pendingCalls.isNotEmpty ? colors.warning : colors.textMuted,
                  ),
                  _buildMiniKpi(
                    'WhatsApp',
                    '${pendingWhatsApp.length}',
                    Icons.chat_rounded,
                    pendingWhatsApp.isNotEmpty ? colors.warning : colors.textMuted,
                  ),
                  _buildMiniKpi(
                    'SMS',
                    '${pendingSms.length}',
                    Icons.sms_rounded,
                    pendingSms.isNotEmpty ? colors.warning : colors.textMuted,
                  ),
                  _buildMiniKpi(
                    'Audio',
                    '${pendingRecordings.length}',
                    Icons.mic_rounded,
                    pendingRecordings.isNotEmpty ? colors.warning : colors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: service.isSyncing ? null : () => service.syncNow(),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        totalPending > 0
                            ? 'Sync All Pending ($totalPending)'
                            : 'Sync Now',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: service.isSyncing ? null : () => service.forceResyncAll(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Resync All History', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List of Pending Items
        Expanded(
          child: totalPending == 0
              ? _buildEmptyState(
                  icon: Icons.cloud_done_rounded,
                  title: 'All Local Telemetry Synced',
                  subtitle:
                      'All phone calls, WhatsApp events, SMS messages, and voice recordings are backed up on CRM server.',
                  actionLabel: 'Force Re-scan All Phone Data',
                  onAction: () => service.clearLocalDataAndRescan(),
                )
              : RefreshIndicator(
                  color: colors.warning,
                  backgroundColor: colors.cardBackground,
                  onRefresh: () async {
                    await service.syncNow();
                  },
                  child: ListView(
                    padding: _getTabContentPadding(context, service, horizontal: 14, top: 4),
                    children: [
                      if (pendingRecordings.isNotEmpty) ...[
                        _buildPendingSectionHeader(
                          'Call Audio Recordings (${pendingRecordings.length})',
                          Icons.mic_rounded,
                          colors.warning,
                        ),
                        for (final rec in pendingRecordings)
                          _buildPendingRecordingCard(service, rec),
                      ],
                      if (pendingCalls.isNotEmpty) ...[
                        _buildPendingSectionHeader(
                          'Phone Calls (${pendingCalls.length})',
                          Icons.phone_rounded,
                          colors.primary,
                        ),
                        for (final call in pendingCalls)
                          _buildPendingCallCard(service, call),
                      ],
                      if (pendingWhatsApp.isNotEmpty) ...[
                        _buildPendingSectionHeader(
                          'WhatsApp Events (${pendingWhatsApp.length})',
                          Icons.chat_rounded,
                          colors.whatsappGreen,
                        ),
                        for (final wa in pendingWhatsApp)
                          _buildPendingWhatsAppCard(service, wa),
                      ],
                      if (pendingSms.isNotEmpty) ...[
                        _buildPendingSectionHeader(
                          'Carrier SMS (${pendingSms.length})',
                          Icons.sms_rounded,
                          colors.secondary,
                        ),
                        for (final sms in pendingSms)
                          _buildPendingSmsCard(service, sms),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPendingSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCallCard(TelemetrySyncService service, dynamic call) {
    final colors = context.stColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          call.direction == 'incoming'
              ? Icons.call_received_rounded
              : Icons.call_made_rounded,
          color: call.direction == 'incoming' ? colors.info : colors.primary,
          size: 20,
        ),
        title: Text(
          _isSavedContact(call.name, call.number) ? call.name : 'Un Saved',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${call.number} • ${_formatDialerTime(call.time as int)} • ${_formatDuration(call.duration as int)}',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncCallsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingWhatsAppCard(TelemetrySyncService service, dynamic wa) {
    final colors = context.stColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.chat_rounded, color: colors.whatsappGreen, size: 20),
        title: Text(
          wa.name.isNotEmpty ? wa.name : 'WhatsApp Contact',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${wa.text ?? "WhatsApp message"} • ${_formatDialerTime(wa.time as int)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncWhatsAppOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.whatsappGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingSmsCard(TelemetrySyncService service, dynamic sms) {
    final colors = context.stColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.sms_rounded, color: colors.secondary, size: 20),
        title: Text(
          sms.name.isNotEmpty ? sms.name : sms.number,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${sms.text ?? "SMS"} • ${_formatDialerTime(sms.time as int)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncSmsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingRecordingCard(TelemetrySyncService service, dynamic rec) {
    final colors = context.stColors;
    final fileName = rec.recordingPath?.split('/').last ?? 'Audio file';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.mic_rounded, color: colors.warning, size: 20),
        title: Text(
          rec.name.isNotEmpty ? rec.name : rec.number,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$fileName • ${_formatDialerTime(rec.time as int)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncRecordingsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.warning,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // 6. CALL LISTS TAB
  Widget _buildCallListsTab(TelemetrySyncService service) {
    final colors = context.stColors;

    if (service.callLists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.playlist_remove_rounded,
        title: 'No Active Call Lists',
        subtitle: 'Call lists created in CRM for your staff account will appear here.',
        actionLabel: 'Refresh Lists',
        onAction: () => service.fetchCallLists(),
      );
    }

    return ListView.builder(
      padding: _getTabContentPadding(context, service, horizontal: 14, top: 12),
      itemCount: service.callLists.length,
      itemBuilder: (ctx, idx) {
        final list = service.callLists[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              list.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            subtitle: Text(
              'Due: ${list.due.isNotEmpty ? list.due : "No deadline"} • ${list.items.length} leads',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            children: list.items.map((lead) {
              return ListTile(
                title: Text(
                  lead.name,
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                subtitle: Text(
                  '${lead.number} • ${lead.status}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dialing ${lead.name} (${lead.number})...')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Call'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = context.stColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: colors.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayerBar(TelemetrySyncService service) {
    final colors = context.stColors;
    final isDark = context.isDarkMode;

    final currentSec = service.audioCurrentPosMs ~/ 1000;
    final totalSec = service.audioDurationMs ~/ 1000;
    final progress = (service.audioDurationMs > 0)
        ? (service.audioCurrentPosMs / service.audioDurationMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(top: BorderSide(color: colors.primary, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              service.isPlayingAudio
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: colors.primary,
              size: 38,
            ),
            onPressed: () {
              if (service.isPlayingAudio) {
                service.pauseRecording();
              } else {
                service.resumeRecording();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service.activeAudioPath?.split('/').last ?? 'Audio Player',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surfaceColor,
                    thumbColor: colors.primary,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (val) {
                      service.seekRecording((val * service.audioDurationMs).toInt());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(currentSec)} / ${_formatDuration(totalSec)}',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 20),
            onPressed: () => service.stopRecording(),
          ),
        ],
      ),
    );
  }
}
