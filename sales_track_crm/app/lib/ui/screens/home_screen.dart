import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/app_lock_service.dart';
import '../../services/telemetry_sync_service.dart';
import 'outcome_modal.dart';
import 'setup_wizard_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _hasPromptedOutcome = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _expandedCallUid;
  String? _selectedContactFilter;
  String _waFilter = 'all';

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
    }
  }

  EdgeInsets _getTabContentPadding(
    BuildContext context,
    TelemetrySyncService service, {
    double top = 8,
    double horizontal = 12,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      32.0,
    );
  }

  void _onServiceChanged() {
    if (!mounted) return;
    final afterCall = widget.syncService.activeAfterCallEvent;
    if (afterCall != null && !_hasPromptedOutcome) {
      _hasPromptedOutcome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => OutcomeModal(
            event: afterCall,
            syncService: widget.syncService,
          ),
        ).then((_) {
          widget.syncService.dismissAfterCallPopup();
          _hasPromptedOutcome = false;
        });
      });
    }
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
    final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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

    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

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

  String _formatCallSubtitle(dynamic call) {
    String directionStr = 'Outgoing call';
    if (call.direction == 'incoming') {
      directionStr = 'Incoming call';
    } else if (call.direction == 'missed') {
      directionStr = 'Missed call';
    } else if (call.direction == 'rejected') {
      directionStr = 'Rejected call';
    } else if (call.direction == 'blocked') {
      directionStr = 'Blocked call';
    }

    if (call.duration <= 0) {
      return directionStr;
    }

    final m = call.duration ~/ 60;
    final s = call.duration % 60;
    return '$directionStr, $m mins $s secs';
  }

  String _formatExactDateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    final sec = d.second.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$min:$sec $ampm';
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
      builder: (ctx) => AlertDialog(
        backgroundColor: SalesTrackTheme.cardBackground,
        title: const Text('App Lock - Enter PIN', style: TextStyle(color: SalesTrackTheme.textPrimary)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, color: SalesTrackTheme.primaryLight),
          decoration: const InputDecoration(hintText: '••••'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SalesTrackTheme.textMuted)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.syncService;
    final device = service.device;
    final staff = service.staff;

    final totalCalls = service.calls.length;
    final connectedCalls = service.calls.where((c) => c.duration > 0).length;
    final totalTalkSeconds = service.calls.fold<int>(0, (sum, c) => sum + c.duration);
    final whatsappCallsCount = service.whatsappEvents.where((e) => e.kind == 'whatsapp_call').length;
    final smsCount = service.smsList.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: service.isPaired ? SalesTrackTheme.primary : SalesTrackTheme.warning,
                boxShadow: [
                  BoxShadow(
                    color: (service.isPaired ? SalesTrackTheme.primary : SalesTrackTheme.warning).withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device?.name ?? 'Sales Phone',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  staff?.name != null ? 'Rep: ${staff!.name}' : 'CRM Telemetry Active',
                  style: const TextStyle(fontSize: 12, color: SalesTrackTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: service.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(SalesTrackTheme.primaryLight),
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    color: SalesTrackTheme.textPrimary,
                  ),
            tooltip: service.isSyncing ? 'Syncing with CRM...' : 'Sync Phone & Server',
            onPressed: service.isSyncing ? null : () => service.syncAllLocalAndRemote(),
          ),
          PopupMenuButton<String>(
            color: SalesTrackTheme.cardBackground,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'permissions') {
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
                  const SnackBar(content: Text('Cleared local cache. Rescanning calls & recordings from phone...')),
                );
              } else if (val == 'scan_recordings') {
                service.scanLocalRecordings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scanning phone storage for call audio recordings...')),
                );
              } else if (val == 'scan_history') {
                service.syncAllLocalAndRemote();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scanning phone call history, SMS & syncing...')),
                );
              } else if (val == 'unpair') {
                _promptPinForSensitiveAction(() {
                  service.unpair();
                  widget.onUnpaired();
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear_and_rescan',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, color: SalesTrackTheme.warning, size: 20),
                    SizedBox(width: 10),
                    Text('Clear Local Data & Re-scan', style: TextStyle(color: SalesTrackTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_recordings',
                child: Row(
                  children: [
                    Icon(Icons.mic_rounded, color: SalesTrackTheme.primaryLight, size: 20),
                    SizedBox(width: 10),
                    Text('Scan Phone Audio Recordings', style: TextStyle(color: SalesTrackTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_history',
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, color: SalesTrackTheme.primaryLight, size: 20),
                    SizedBox(width: 10),
                    Text('Scan Phone History & Sync', style: TextStyle(color: SalesTrackTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: SalesTrackTheme.secondaryLight, size: 20),
                    SizedBox(width: 10),
                    Text('Check Permissions (7 Checks)', style: TextStyle(color: SalesTrackTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unpair',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, color: SalesTrackTheme.danger, size: 20),
                    SizedBox(width: 10),
                    Text('Unpair Device', style: TextStyle(color: SalesTrackTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: SalesTrackTheme.primary,
          labelColor: SalesTrackTheme.primaryLight,
          unselectedLabelColor: SalesTrackTheme.textSecondary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (service.pendingQueueCount + service.pendingRecordingsCount > 0)
                          ? const Color(0xFFF59E0B)
                          : SalesTrackTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${service.pendingQueueCount + service.pendingRecordingsCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (service.pendingQueueCount + service.pendingRecordingsCount > 0)
                            ? Colors.black
                            : SalesTrackTheme.textMuted,
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
            // Live Real-Time Sync Progress Banner (when syncing)
            if (service.isSyncing)
              _buildSyncProgressBanner(service),

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
            if (service.isPlayingAudio || service.activeAudioPath != null) _buildAudioPlayerBar(service),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressBanner(TelemetrySyncService service) {
    final percent = (service.syncProgress * 100).toInt().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: const Border(
          bottom: BorderSide(color: SalesTrackTheme.primary, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(SalesTrackTheme.primaryLight),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.syncProgressMessage.isNotEmpty
                      ? service.syncProgressMessage
                      : 'Syncing telemetry & recordings with Perfex CRM...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SalesTrackTheme.primaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SalesTrackTheme.primaryLight,
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
              backgroundColor: SalesTrackTheme.surfaceColor,
              valueColor: const AlwaysStoppedAnimation<Color>(SalesTrackTheme.primaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionAlertBanner(TelemetrySyncService service) {
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SalesTrackTheme.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SalesTrackTheme.warning.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: SalesTrackTheme.warning, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${missing.length} System ${missing.length == 1 ? "Permission" : "Permissions"} Needed',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  Text(
                    'Missing: ${missing.join(", ")}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
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
                backgroundColor: SalesTrackTheme.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: SalesTrackTheme.cardBackground,
        border: Border(bottom: BorderSide(color: SalesTrackTheme.surfaceColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniKpi(
                'Calls',
                '$totalCalls',
                Icons.call_rounded,
                SalesTrackTheme.primaryLight,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'Connected',
                '$connectedCalls',
                Icons.call_made_rounded,
                SalesTrackTheme.success,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'Talk Time',
                _formatDuration(talkSeconds),
                Icons.timer_rounded,
                SalesTrackTheme.secondaryLight,
                onTap: () => _tabController.animateTo(0),
              ),
              _buildMiniKpi(
                'WhatsApp',
                '$waCalls',
                Icons.chat_bubble_rounded,
                SalesTrackTheme.whatsappGreen,
                onTap: () => _tabController.animateTo(1),
              ),
              _buildMiniKpi(
                'Queue',
                '$pendingQueue',
                Icons.cloud_upload_rounded,
                pendingQueue > 0 ? SalesTrackTheme.warning : SalesTrackTheme.textMuted,
                onTap: () => _tabController.animateTo(4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: SalesTrackTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusMsg,
                  style: const TextStyle(fontSize: 12, color: SalesTrackTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: SalesTrackTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: SalesTrackTheme.textMuted), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. CALLS TAB
  Widget _buildCallsTab(TelemetrySyncService service) {
    if (service.calls.isEmpty) {
      if (!service.hasCallLogPermission) {
        return _buildEmptyState(
          icon: Icons.security_rounded,
          title: 'Call Log Permission Required',
          subtitle: 'Please grant Call Log and Storage permissions to read your phone call history and sense live incoming & outgoing calls.',
          actionLabel: 'Grant Call Log Permission',
          onAction: () => service.requestAllPermissions(),
        );
      }
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No Calls Loaded From Phone',
        subtitle: 'Tap below to read call history from your device local storage and sync to CRM server.',
        actionLabel: 'Scan Phone Call History',
        onAction: () => service.syncAllLocalAndRemote(),
      );
    }

    // Determine active contact filter or search query
    final activeFilter = (_selectedContactFilter != null && _selectedContactFilter!.isNotEmpty)
        ? _selectedContactFilter!
        : _searchQuery;

    final filtered = service.calls.where((c) {
      if (activeFilter.isEmpty) return true;
      final q = activeFilter.toLowerCase();
      final numNorm = c.number.replaceAll(RegExp(r'\D'), '');
      final qNorm = q.replaceAll(RegExp(r'\D'), '');
      if (c.name.isNotEmpty && c.name.toLowerCase().contains(q)) return true;
      if (c.number.toLowerCase().contains(q)) return true;
      if (qNorm.isNotEmpty && numNorm.endsWith(qNorm.length >= 10 ? qNorm.substring(qNorm.length - 10) : qNorm)) return true;
      return false;
    }).toList()..sort((a, b) => b.time.compareTo(a.time));

    // Determine if viewing a specific contact
    final bool isSingleContact = activeFilter.isNotEmpty && filtered.isNotEmpty &&
        filtered.every((c) => (c.name.isNotEmpty && c.name.toLowerCase() == filtered.first.name.toLowerCase()) ||
            (c.number.replaceAll(RegExp(r'\D'), '').endsWith(filtered.first.number.replaceAll(RegExp(r'\D'), '').length >= 10
                ? filtered.first.number.replaceAll(RegExp(r'\D'), '').substring(filtered.first.number.replaceAll(RegExp(r'\D'), '').length - 10)
                : filtered.first.number)));

    final contactName = filtered.isNotEmpty ? (filtered.first.name.isNotEmpty ? filtered.first.name : filtered.first.number) : '';
    final contactNumber = filtered.isNotEmpty ? filtered.first.number : '';

    // Group filtered calls by date header (e.g. Wednesday, 7 October)
    final Map<String, List<dynamic>> grouped = {};
    for (final call in filtered) {
      final header = _formatDialerDateHeader(DateTime.fromMillisecondsSinceEpoch(call.time));
      grouped.putIfAbsent(header, () => []).add(call);
    }

    return Column(
      children: [
        // Calls Sync Actions & Status Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncCallsOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync Calls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalesTrackTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'call'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SalesTrackTheme.textSecondary,
                  side: BorderSide(color: SalesTrackTheme.surfaceColor.withOpacity(0.9)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (service.pendingCallsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingCallsCount} Pending',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Clean Search Bar (top recording button removed as requested)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: SalesTrackTheme.surfaceColor,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: SalesTrackTheme.surfaceColor.withOpacity(0.8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: SalesTrackTheme.textMuted),
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
                    style: const TextStyle(fontSize: 14, color: SalesTrackTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search contact or phone number...',
                      hintStyle: TextStyle(fontSize: 13, color: SalesTrackTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
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
                    child: const Icon(Icons.close_rounded, size: 18, color: SalesTrackTheme.textMuted),
                  ),
              ],
            ),
          ),
        ),

        // Contact Header Card if single contact filtered (matching Samsung OneUI dialer)
        if (isSingleContact)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SalesTrackTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SalesTrackTheme.surfaceColor),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: SalesTrackTheme.textPrimary, size: 22),
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
                  radius: 22,
                  backgroundColor: const Color(0xFF26A69A),
                  child: Text(
                    contactName.isNotEmpty ? contactName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SalesTrackTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contactNumber,
                        style: const TextStyle(fontSize: 13, color: SalesTrackTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: SalesTrackTheme.textMuted),
                  onPressed: () {},
                ),
              ],
            ),
          ),

        // Grouped Call List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No calls found for "$activeFilter"',
                    style: const TextStyle(color: SalesTrackTheme.textMuted),
                  ),
                )
              : RefreshIndicator(
                  color: SalesTrackTheme.primary,
                  backgroundColor: SalesTrackTheme.cardBackground,
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
                            child: Text(
                              dateHeader,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: SalesTrackTheme.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: SalesTrackTheme.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: SalesTrackTheme.surfaceColor),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Material(
                                color: Colors.transparent,
                                child: Column(
                                  children: [
                                    for (int callIdx = 0; callIdx < callsInGroup.length; callIdx++) ...[
                                      if (callIdx > 0)
                                        const Divider(
                                          height: 1,
                                          thickness: 0.8,
                                          indent: 56,
                                          endIndent: 16,
                                          color: SalesTrackTheme.surfaceColor,
                                        ),
                                      _buildCallItem(service, callsInGroup[callIdx], isSingleContact),
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

  Widget _buildCallItem(TelemetrySyncService service, dynamic call, bool isSingleContact) {
    final isIncoming = call.direction == 'incoming';
    final isMissed = call.direction == 'missed' || call.direction == 'rejected';

    final icon = isMissed
        ? Icons.call_missed_rounded
        : (isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded);
    final iconColor = isMissed
        ? SalesTrackTheme.danger
        : (isIncoming ? const Color(0xFF3B82F6) : const Color(0xFF10B981));

    final hasRec = call.recording || (call.recordingPath != null && call.recordingPath!.isNotEmpty);
    final isExpanded = _expandedCallUid == call.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Call Row (tappable to expand/collapse)
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Direction Arrow
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 14),

                // Time & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDialerTime(call.time),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: SalesTrackTheme.textPrimary,
                            ),
                          ),
                          if (!isSingleContact && (call.name.isNotEmpty || call.number.isNotEmpty)) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '• ${call.name.isNotEmpty ? call.name : call.number}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: SalesTrackTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatCallSubtitle(call),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: SalesTrackTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Disabled Grey Mic Icon as Visual Identification (per user request)
                if (hasRec)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: SalesTrackTheme.textMuted,
                      size: 20,
                    ),
                  ),

                // Sync Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: call.syncStatus == 'synced'
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: call.syncStatus == 'synced'
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : const Color(0xFFF59E0B).withOpacity(0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        call.syncStatus == 'synced' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        size: 10,
                        color: call.syncStatus == 'synced' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        call.syncStatus == 'synced' ? 'SYNCED' : 'PENDING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: call.syncStatus == 'synced' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Details & Audio Player with Seekbar (when clicked)
        if (isExpanded)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SalesTrackTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SalesTrackTheme.surfaceColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Call Information details
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: SalesTrackTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      call.number,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: SalesTrackTheme.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SalesTrackTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SIM ${call.sim}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SalesTrackTheme.primaryLight),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(
                          call.syncStatus == 'synced' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          size: 13,
                          color: call.syncStatus == 'synced' ? SalesTrackTheme.success : SalesTrackTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          call.syncStatus == 'synced' ? 'Synced to CRM' : 'Pending Sync',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: call.syncStatus == 'synced' ? SalesTrackTheme.success : SalesTrackTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exact Time: ${_formatExactDateTime(call.time)}',
                  style: const TextStyle(fontSize: 11.5, color: SalesTrackTheme.textSecondary),
                ),

                // Tap to see all history for this contact
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
                          const Icon(Icons.history_rounded, size: 14, color: SalesTrackTheme.primaryLight),
                          const SizedBox(width: 4),
                          Text(
                            'View all call history for ${call.name.isNotEmpty ? call.name : call.number}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SalesTrackTheme.primaryLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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

  Widget _buildInlineAudioPlayer(TelemetrySyncService service, dynamic call) {
    final isThisPlaying = service.isPlayingAudio && service.activeAudioPath == call.recordingPath;
    final isThisActive = service.activeAudioPath == call.recordingPath;

    final totalDurationMs = (isThisActive && service.audioDurationMs > 0)
        ? service.audioDurationMs
        : (call.duration > 0 ? call.duration * 1000 : 60000);

    final currentPosMs = isThisActive ? service.audioCurrentPosMs : 0;
    final progress = (totalDurationMs > 0) ? (currentPosMs / totalDurationMs).clamp(0.0, 1.0) : 0.0;

    final currentSec = currentPosMs ~/ 1000;
    final totalSec = totalDurationMs ~/ 1000;

    final currentStr = '${currentSec ~/ 60}:${(currentSec % 60).toString().padLeft(2, '0')}';
    final totalStr = '${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}';

    final fileName = call.recordingPath!.split('/').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SalesTrackTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SalesTrackTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.audiotrack_rounded, size: 15, color: SalesTrackTheme.primaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SalesTrackTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$currentStr / $totalStr',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SalesTrackTheme.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Play / Pause circular button
              Material(
                color: SalesTrackTheme.primary,
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

              // Running Seekbar Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: SalesTrackTheme.primaryLight,
                    inactiveTrackColor: SalesTrackTheme.surfaceColor,
                    thumbColor: Colors.white,
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

  // 2. WHATSAPP TAB (Personal & Business accounts)
  Widget _buildWhatsAppTab(TelemetrySyncService service) {
    if (service.whatsappEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_rounded,
        title: 'No WhatsApp Activity Sensed',
        subtitle: 'Ensure Notification Access is enabled to sense calls and chats from WhatsApp and WhatsApp Business.',
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
    }).toList()..sort((a, b) => b.time.compareTo(a.time));

    return Column(
      children: [
        if (!service.hasWhatsAppAccessPermission)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: SalesTrackTheme.whatsappGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SalesTrackTheme.whatsappGreen.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_chat_unread_rounded, color: SalesTrackTheme.whatsappGreen, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Call Access Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        'Enable Notification Access to sense live WhatsApp & WhatsApp Business calls.',
                        style: TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => service.openNotificationListenerSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SalesTrackTheme.whatsappGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        // WhatsApp Sync Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncWhatsAppOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalesTrackTheme.whatsappGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'whatsapp'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SalesTrackTheme.textSecondary,
                  side: BorderSide(color: SalesTrackTheme.surfaceColor.withOpacity(0.9)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (service.pendingWhatsAppCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingWhatsAppCount} Pending',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
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
                selectedColor: SalesTrackTheme.whatsappGreen.withOpacity(0.25),
                checkmarkColor: SalesTrackTheme.whatsappGreen,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _waFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'all' ? SalesTrackTheme.whatsappGreen : SalesTrackTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('WhatsApp Messages ($messageCount)'),
                selected: _waFilter == 'messages',
                onSelected: (_) => setState(() => _waFilter = 'messages'),
                selectedColor: SalesTrackTheme.whatsappGreen.withOpacity(0.25),
                checkmarkColor: SalesTrackTheme.whatsappGreen,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _waFilter == 'messages' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'messages' ? SalesTrackTheme.whatsappGreen : SalesTrackTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: Text('WhatsApp Calls ($callCount)'),
                selected: _waFilter == 'calls',
                onSelected: (_) => setState(() => _waFilter = 'calls'),
                selectedColor: SalesTrackTheme.whatsappGreen.withOpacity(0.25),
                checkmarkColor: SalesTrackTheme.whatsappGreen,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: _waFilter == 'calls' ? FontWeight.bold : FontWeight.normal,
                  color: _waFilter == 'calls' ? SalesTrackTheme.whatsappGreen : SalesTrackTheme.textSecondary,
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
                        color: SalesTrackTheme.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _waFilter == 'messages'
                            ? 'No WhatsApp Messages recorded'
                            : _waFilter == 'calls'
                                ? 'No WhatsApp Calls recorded'
                                : 'No WhatsApp Activity recorded',
                        style: const TextStyle(fontSize: 14, color: SalesTrackTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
              color: SalesTrackTheme.whatsappGreen,
              backgroundColor: SalesTrackTheme.cardBackground,
              onRefresh: () async {
                await service.syncActiveWhatsAppNotifications();
                await service.syncWhatsAppOnly();
              },
              child: ListView.builder(
                padding: _getTabContentPadding(context, service, horizontal: 12, top: 8),
                itemCount: filteredList.length,
                itemBuilder: (ctx, idx) {
                  final ev = filteredList[idx];
                  final isBusiness = ev.app == 'com.whatsapp.w4b';
                  final isCall = ev.kind == 'whatsapp_call';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isBusiness ? SalesTrackTheme.whatsappBusiness : SalesTrackTheme.whatsappGreen).withOpacity(0.2),
                      child: Icon(
                        isCall ? (ev.media == 'video' ? Icons.videocam_rounded : Icons.phone_rounded) : Icons.chat_rounded,
                        color: isBusiness ? SalesTrackTheme.whatsappBusiness : SalesTrackTheme.whatsappGreen,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ev.name.isNotEmpty ? ev.name : 'WhatsApp Contact',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: SalesTrackTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBusiness ? SalesTrackTheme.whatsappBusiness.withOpacity(0.25) : SalesTrackTheme.whatsappGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBusiness ? 'BUSINESS' : 'PERSONAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isBusiness ? Colors.tealAccent : SalesTrackTheme.whatsappGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isCall ? 'WhatsApp Call (${_formatDuration(ev.duration)})' : (ev.text ?? 'Message'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: SalesTrackTheme.textSecondary),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(ev.time),
                          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: ev.syncStatus == 'synced'
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: ev.syncStatus == 'synced'
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFF59E0B).withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            ev.syncStatus == 'synced' ? 'SYNCED' : 'PENDING',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: ev.syncStatus == 'synced'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: service.isSyncing ? null : () => service.syncSmsOnly(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                label: const Text('Sync SMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalesTrackTheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: service.isSyncing ? null : () => service.forceResyncAll(kind: 'sms'),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Resync All', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SalesTrackTheme.textSecondary,
                  side: BorderSide(color: SalesTrackTheme.surfaceColor.withOpacity(0.9)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (service.pendingSmsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '${service.pendingSmsCount} Pending',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'All Synced',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: SalesTrackTheme.secondary,
            backgroundColor: SalesTrackTheme.cardBackground,
            onRefresh: () async {
              if (service.hasSmsPermission) {
                await service.syncDeviceSms();
              }
              await service.syncSmsOnly();
            },
            child: ListView.builder(
              padding: _getTabContentPadding(context, service, horizontal: 12, top: 8),
              itemCount: sortedSms.length,
              itemBuilder: (ctx, idx) {
                final sms = sortedSms[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: SalesTrackTheme.secondary.withOpacity(0.15),
                      child: const Icon(Icons.sms_rounded, color: SalesTrackTheme.secondaryLight, size: 20),
                    ),
                    title: Text(
                      sms.name.isNotEmpty ? sms.name : sms.number,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: SalesTrackTheme.textPrimary),
                    ),
                    subtitle: Text(
                      sms.text ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: SalesTrackTheme.textSecondary),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(sms.time),
                          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: sms.syncStatus == 'synced'
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sms.syncStatus == 'synced'
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFF59E0B).withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            sms.syncStatus == 'synced' ? 'SYNCED' : 'PENDING',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: sms.syncStatus == 'synced'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
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
    if (service.localRecordings.isEmpty) {
      if (!service.hasRecordingsFolderPermission) {
        return _buildEmptyState(
          icon: Icons.folder_special_rounded,
          title: 'Recordings Folder Access Required',
          subtitle: 'Grant All Files Access so the app can locate and upload call audio recordings saved by your phone.',
          actionLabel: 'Grant Folder Access',
          onAction: () => service.openAllFilesSettings(),
        );
      }
      return _buildEmptyState(
        icon: Icons.music_off_rounded,
        title: 'No Call Audio Recordings Found',
        subtitle: 'Recordings saved by Samsung, Xiaomi, or other dialers will be scanned automatically.',
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
              color: SalesTrackTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SalesTrackTheme.warning.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_special_rounded, color: SalesTrackTheme.warning, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordings Folder Access Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        'Grant All Files Access to locate and upload call audio recordings.',
                        style: TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => service.openAllFilesSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SalesTrackTheme.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        // Recordings Upload Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
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
                    backgroundColor: SalesTrackTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: service.isSyncing ? null : () => service.scanLocalRecordings(),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Rescan Files', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SalesTrackTheme.textSecondary,
                    side: BorderSide(color: SalesTrackTheme.surfaceColor.withOpacity(0.9)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                if (service.pendingRecordingsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          '${service.pendingRecordingsCount} Pending Upload',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'All Uploaded',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
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
            color: SalesTrackTheme.primary,
            backgroundColor: SalesTrackTheme.cardBackground,
            onRefresh: () async {
              await service.scanLocalRecordings();
              await service.syncRecordingsOnly();
            },
            child: ListView.builder(
              padding: _getTabContentPadding(context, service, horizontal: 12, top: 8),
              itemCount: sortedRecs.length,
              itemBuilder: (ctx, idx) {
                final rec = sortedRecs[idx];
                final path = rec['filePath']?.toString() ?? '';
                final name = rec['fileName']?.toString() ?? 'Call Recording';
                final isCurrent = service.activeAudioPath == path;

                // Check if matching call is synced
                final matchingCall = service.calls.where((c) => c.recordingPath == path).firstOrNull;
                final isUploaded = matchingCall?.recordingSyncStatus == 'synced';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? SalesTrackTheme.primary : SalesTrackTheme.surfaceColor,
                      child: Icon(
                        isCurrent && service.isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: SalesTrackTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUploaded
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isUploaded
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFF59E0B).withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isUploaded ? 'UPLOADED' : 'LOCAL ONLY',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      path,
                      style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isCurrent && service.isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        color: SalesTrackTheme.primary,
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
    final pendingCalls = service.calls.where((c) => c.syncStatus != 'synced').toList();
    final pendingWhatsApp = service.whatsappEvents.where((e) => e.syncStatus != 'synced').toList();
    final pendingSms = service.smsList.where((s) => s.syncStatus != 'synced').toList();
    final pendingRecordings = service.calls.where((c) => (c.recording || (c.recordingPath != null && c.recordingPath!.isNotEmpty)) && c.recordingSyncStatus != 'synced').toList();

    final totalPending = pendingCalls.length + pendingWhatsApp.length + pendingSms.length + pendingRecordings.length;

    return Column(
      children: [
        // Pending Summary & Master Sync Action Header
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SalesTrackTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: totalPending > 0 ? const Color(0xFFF59E0B).withOpacity(0.4) : SalesTrackTheme.surfaceColor,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildMiniKpi('Calls', '${pendingCalls.length}', Icons.call_rounded, pendingCalls.isNotEmpty ? const Color(0xFFF59E0B) : SalesTrackTheme.textMuted),
                  _buildMiniKpi('WhatsApp', '${pendingWhatsApp.length}', Icons.chat_rounded, pendingWhatsApp.isNotEmpty ? const Color(0xFFF59E0B) : SalesTrackTheme.textMuted),
                  _buildMiniKpi('SMS', '${pendingSms.length}', Icons.sms_rounded, pendingSms.isNotEmpty ? const Color(0xFFF59E0B) : SalesTrackTheme.textMuted),
                  _buildMiniKpi('Audio', '${pendingRecordings.length}', Icons.mic_rounded, pendingRecordings.isNotEmpty ? const Color(0xFFF59E0B) : SalesTrackTheme.textMuted),
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
                        totalPending > 0 ? 'Sync All Pending ($totalPending)' : 'Sync Now',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SalesTrackTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: service.isSyncing ? null : () => service.forceResyncAll(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Resync All History', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SalesTrackTheme.textSecondary,
                      side: BorderSide(color: SalesTrackTheme.surfaceColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  subtitle: 'All phone calls, WhatsApp events, SMS messages, and voice recordings are backed up on Perfex CRM server.',
                  actionLabel: 'Force Re-scan All Phone Data',
                  onAction: () => service.clearLocalDataAndRescan(),
                )
              : RefreshIndicator(
                  color: const Color(0xFFF59E0B),
                  backgroundColor: SalesTrackTheme.cardBackground,
                  onRefresh: () async {
                    await service.syncNow();
                  },
                  child: ListView(
                    padding: _getTabContentPadding(context, service, horizontal: 12, top: 4),
                    children: [
                      if (pendingRecordings.isNotEmpty) ...[
                        _buildPendingSectionHeader('Call Audio Recordings (${pendingRecordings.length})', Icons.mic_rounded, const Color(0xFFF59E0B)),
                        for (final rec in pendingRecordings)
                          _buildPendingRecordingCard(service, rec),
                      ],
                      if (pendingCalls.isNotEmpty) ...[
                        _buildPendingSectionHeader('Phone Calls (${pendingCalls.length})', Icons.phone_rounded, SalesTrackTheme.primaryLight),
                        for (final call in pendingCalls)
                          _buildPendingCallCard(service, call),
                      ],
                      if (pendingWhatsApp.isNotEmpty) ...[
                        _buildPendingSectionHeader('WhatsApp Events (${pendingWhatsApp.length})', Icons.chat_rounded, SalesTrackTheme.whatsappGreen),
                        for (final wa in pendingWhatsApp)
                          _buildPendingWhatsAppCard(service, wa),
                      ],
                      if (pendingSms.isNotEmpty) ...[
                        _buildPendingSectionHeader('Carrier SMS (${pendingSms.length})', Icons.sms_rounded, SalesTrackTheme.secondaryLight),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          call.direction == 'incoming' ? Icons.call_received_rounded : Icons.call_made_rounded,
          color: call.direction == 'incoming' ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
          size: 20,
        ),
        title: Text(
          call.name.isNotEmpty ? call.name : call.number,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SalesTrackTheme.textPrimary),
        ),
        subtitle: Text(
          '${call.number} • ${_formatDialerTime(call.time)} • ${_formatDuration(call.duration)}',
          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncCallsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: SalesTrackTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingWhatsAppCard(TelemetrySyncService service, dynamic wa) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.chat_rounded, color: SalesTrackTheme.whatsappGreen, size: 20),
        title: Text(
          wa.name.isNotEmpty ? wa.name : 'WhatsApp Contact',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SalesTrackTheme.textPrimary),
        ),
        subtitle: Text(
          '${wa.text ?? "WhatsApp message"} • ${_formatDialerTime(wa.time)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncWhatsAppOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: SalesTrackTheme.whatsappGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingSmsCard(TelemetrySyncService service, dynamic sms) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.sms_rounded, color: SalesTrackTheme.secondaryLight, size: 20),
        title: Text(
          sms.name.isNotEmpty ? sms.name : sms.number,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SalesTrackTheme.textPrimary),
        ),
        subtitle: Text(
          '${sms.text ?? "SMS"} • ${_formatDialerTime(sms.time)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncSmsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: SalesTrackTheme.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPendingRecordingCard(TelemetrySyncService service, dynamic rec) {
    final fileName = rec.recordingPath?.split('/').last ?? 'Audio file';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.mic_rounded, color: Color(0xFFF59E0B), size: 20),
        title: Text(
          rec.name.isNotEmpty ? rec.name : rec.number,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SalesTrackTheme.textPrimary),
        ),
        subtitle: Text(
          '$fileName • ${_formatDialerTime(rec.time)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textSecondary),
        ),
        trailing: ElevatedButton(
          onPressed: service.isSyncing ? null : () => service.syncRecordingsOnly(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // 5. CALL LISTS TAB
  Widget _buildCallListsTab(TelemetrySyncService service) {
    if (service.callLists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.playlist_remove_rounded,
        title: 'No Active Call Lists',
        subtitle: 'Call lists created in Perfex CRM for your staff account will appear here.',
        actionLabel: 'Refresh Lists',
        onAction: () => service.fetchCallLists(),
      );
    }

    return ListView.builder(
      padding: _getTabContentPadding(context, service, horizontal: 12, top: 12),
      itemCount: service.callLists.length,
      itemBuilder: (ctx, idx) {
        final list = service.callLists[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(list.name, style: const TextStyle(fontWeight: FontWeight.bold, color: SalesTrackTheme.textPrimary)),
            subtitle: Text('Due: ${list.due.isNotEmpty ? list.due : "No deadline"} • ${list.items.length} leads', style: const TextStyle(color: SalesTrackTheme.textMuted, fontSize: 12)),
            children: list.items.map((lead) {
              return ListTile(
                title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w500, color: SalesTrackTheme.textPrimary)),
                subtitle: Text('${lead.number} • ${lead.status}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dialing ${lead.name} (${lead.number})...')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: SalesTrackTheme.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: SalesTrackTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: SalesTrackTheme.textSecondary)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayerBar(TelemetrySyncService service) {
    final currentSec = service.audioCurrentPosMs ~/ 1000;
    final totalSec = service.audioDurationMs ~/ 1000;
    final progress = (service.audioDurationMs > 0)
        ? (service.audioCurrentPosMs / service.audioDurationMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: SalesTrackTheme.cardBackground,
        border: const Border(top: BorderSide(color: SalesTrackTheme.primary, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              service.isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: SalesTrackTheme.primary,
              size: 36,
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SalesTrackTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: SalesTrackTheme.primary,
                    inactiveTrackColor: SalesTrackTheme.surfaceColor,
                    thumbColor: SalesTrackTheme.primary,
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
          Text(
            '${_formatDuration(currentSec)} / ${_formatDuration(totalSec)}',
            style: const TextStyle(fontSize: 11, color: SalesTrackTheme.textMuted),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: SalesTrackTheme.textMuted, size: 20),
            onPressed: () => service.stopRecording(),
          ),
        ],
      ),
    );
  }
}
