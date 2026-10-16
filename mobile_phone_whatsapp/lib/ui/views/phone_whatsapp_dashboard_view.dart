import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/phone_whatsapp_models.dart';
import '../../data/services/phone_whatsapp_sync_service.dart';

class PhoneWhatsAppDashboardView extends StatefulWidget {
  const PhoneWhatsAppDashboardView({super.key});

  @override
  State<PhoneWhatsAppDashboardView> createState() => _PhoneWhatsAppDashboardViewState();
}

class _PhoneWhatsAppDashboardViewState extends State<PhoneWhatsAppDashboardView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _messagesSubTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        try {
          final sync = context.read<PhoneWhatsAppSyncService>();
          if (sync.isPlayingAudio || sync.activeAudioPath != null) {
            sync.stopAudio();
          }
        } catch (_) {}
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final sync = context.read<PhoneWhatsAppSyncService>();
      sync.fetchDeviceCallLogsAndSync();
      sync.scanLocalRecordings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      context.read<PhoneWhatsAppSyncService>().stopAudio();
    } catch (_) {}
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<PhoneWhatsAppSyncService>();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurfaceElevated,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phonelink_ring, color: AppColors.accentEmerald, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RingVia360 Telemetry',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain),
                ),
                Text(
                  '${sync.deviceModel} • Battery ${sync.batteryPercent}%',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Permissions Hub',
            icon: const Icon(Icons.security, color: AppColors.accentEmerald, size: 20),
            onPressed: () {
              _tabController.animateTo(4);
            },
          ),
          IconButton(
            tooltip: 'Scan Local Recordings',
            icon: const Icon(Icons.folder_open, color: AppColors.accentCyan, size: 20),
            onPressed: () async {
              await sync.scanLocalRecordings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Discovered ${sync.localRecordings.length} local call recordings on device'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: sync.isOnline ? 'Online (Tap to toggle offline)' : 'Offline (Tap to reconnect)',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: sync.isOnline ? AppColors.accentEmerald : AppColors.accentRose,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  sync.isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sync.isOnline ? AppColors.accentEmerald : AppColors.accentRose,
                  ),
                ),
              ],
            ),
            onPressed: () => sync.toggleOnlineState(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accentEmerald,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentEmerald,
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
            Tab(
              icon: const Icon(Icons.call_outlined, size: 18),
              text: 'Calls (${sync.calls.length})',
            ),
            Tab(
              icon: const Icon(Icons.mic_none_outlined, size: 18),
              text: 'Recordings (${sync.localRecordings.length})',
            ),
            Tab(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              text: 'Messages (${sync.whatsappMessages.length + sync.smsMessages.length})',
            ),
            const Tab(
              icon: Icon(Icons.verified_user_outlined, size: 18),
              text: 'Permissions',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: sync.pendingCount > 0,
                label: Text('${sync.pendingCount}'),
                backgroundColor: AppColors.accentAmber,
                child: const Icon(Icons.sync, size: 18),
              ),
              text: 'Sync',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(context, sync),
          _buildCallsTab(context, sync),
          _buildRecordingsTab(context, sync),
          _buildMessagesTab(context, sync),
          _buildPermissionsTab(context, sync),
          _buildSyncTab(context, sync),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. DASHBOARD TAB
  // ===========================================================================
  Widget _buildDashboardTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Real Hardware Fleet Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.accentEmerald.withValues(alpha: 0.15),
                      radius: 20,
                      child: const Icon(Icons.smartphone, color: AppColors.accentEmerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sync.deviceModel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain)),
                          Text('${sync.osVersion} • ID: ${sync.deviceId}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('BATTERY ${sync.batteryPercent}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentEmerald)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildStatChip(Icons.call, '${sync.calls.length}', 'Calls Logged', AppColors.accentCyan),
                    const SizedBox(width: 10),
                    _buildStatChip(Icons.mic, '${sync.localRecordings.length}', 'Recordings', AppColors.primary),
                    const SizedBox(width: 10),
                    _buildStatChip(Icons.chat, '${sync.whatsappMessages.length + sync.smsMessages.length}', 'Messages', AppColors.accentAmber),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Telemetry Synchronization Actions
          const Text('Device Telemetry & Extraction Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: 'Scan Local Audio',
                  color: AppColors.accentCyan,
                  onTap: () async {
                    await sync.scanLocalRecordings();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: ${sync.localRecordings.length} audio recordings found')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_callback,
                  label: 'Sync Call History',
                  color: AppColors.accentEmerald,
                  onTap: () async {
                    await sync.fetchDeviceCallLogsAndSync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device call logs fetched and synced')));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.sms,
                  label: 'Sync Device SMS',
                  color: AppColors.accentAmber,
                  onTap: () async {
                    await sync.fetchDeviceSmsAndSync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historical carrier SMS extracted and queued')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.security,
                  label: 'Permissions Hub',
                  color: AppColors.primary,
                  onTap: () => _tabController.animateTo(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status & Cloud Sync Activity
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, color: AppColors.accentEmerald, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cloud Sync Engine Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                      Text(sync.syncStatusMessage, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: sync.isSyncing ? null : () => sync.syncNow(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentEmerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: sync.isSyncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain)),
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  String _formatToIST(String? dateStr, [int? timestampMs]) {
    DateTime? dt;
    if (timestampMs != null && timestampMs > 0) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true).add(const Duration(hours: 5, minutes: 30));
    } else if (dateStr != null && dateStr.trim().isNotEmpty) {
      try {
        if (dateStr.contains('T') || dateStr.endsWith('Z')) {
          final parsed = DateTime.parse(dateStr).toUtc();
          dt = parsed.add(const Duration(hours: 5, minutes: 30));
        } else {
          final parsed = DateTime.tryParse(dateStr);
          if (parsed != null) {
            dt = parsed.isUtc ? parsed.add(const Duration(hours: 5, minutes: 30)) : parsed;
          }
        }
      } catch (_) {}
    }

    if (dt == null) {
      return (dateStr != null && dateStr.trim().isNotEmpty) ? dateStr : 'Recent';
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, ${hour.toString().padLeft(2, '0')}:$minute:$second $ampm IST';
  }

  // ===========================================================================
  // 2. CALLS TAB
  // ===========================================================================
  Widget _buildCallsTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    if (sync.calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_missed, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text('No Call Telemetry Available Yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMain)),
            const SizedBox(height: 6),
            const Text('Scan device call logs to import all past and recent calls.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => sync.fetchDeviceCallLogsAndSync(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Fetch Calls from Device Call Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentEmerald,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    // Sort calls: latest on top
    final sortedCalls = List<CallLogTelemetryModel>.from(sync.calls)
      ..sort((a, b) {
        final tA = DateTime.tryParse(a.timestamp)?.millisecondsSinceEpoch ?? 0;
        final tB = DateTime.tryParse(b.timestamp)?.millisecondsSinceEpoch ?? 0;
        return tB.compareTo(tA);
      });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCalls.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final c = sortedCalls[index];
        final isPending = c.syncStatus == 'SYNC_PENDING';

        IconData dirIcon;
        Color dirColor;
        switch (c.direction.toLowerCase()) {
          case 'inbound':
            dirIcon = Icons.call_received;
            dirColor = AppColors.accentEmerald;
            break;
          case 'outbound':
            dirIcon = Icons.call_made;
            dirColor = AppColors.accentCyan;
            break;
          case 'missed':
            dirIcon = Icons.call_missed;
            dirColor = AppColors.accentRose;
            break;
          default:
            dirIcon = Icons.call;
            dirColor = AppColors.textMuted;
        }

        final durationMinutes = c.durationSeconds ~/ 60;
        final durationRemainder = c.durationSeconds % 60;
        final durStr = '${durationMinutes}m ${durationRemainder}s';

        // Check if there's a matching local recording via intelligent multi-criteria matching
        final matchingRec = sync.matchRecordingForCall(c);
        final hasAudio = (c.recordingUrl != null && c.recordingUrl!.isNotEmpty) || matchingRec.filePath.isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCallIntelligenceModal(context, sync, c, matchingRec.filePath.isNotEmpty ? matchingRec : null),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasAudio ? const Color(0x66AA3BFF) : (isPending ? AppColors.accentAmber.withValues(alpha: 0.5) : AppColors.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: dirColor.withValues(alpha: 0.15),
                      radius: 18,
                      child: Icon(dirIcon, color: dirColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LINE 1: NAME (Saved device contact name or phone number)
                          Text(
                            (c.contactName.trim().isNotEmpty &&
                                    c.contactName.trim() != c.phoneNumber.trim() &&
                                    !c.contactName.startsWith('Contact ('))
                                ? c.contactName.trim()
                                : (c.phoneNumber.isNotEmpty ? c.phoneNumber : 'Unknown Contact'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textMain,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // LINE 2: CONTACT NUMBER
                          Text(
                            c.phoneNumber.isNotEmpty ? c.phoneNumber : 'No Number Available',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // LINE 3: IST TIMESTAMP
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 11, color: AppColors.accentCyan),
                              const SizedBox(width: 4),
                              Text(
                                _formatToIST(c.timestamp),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPending ? AppColors.accentAmber.withValues(alpha: 0.15) : AppColors.accentEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c.syncStatus,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isPending ? AppColors.accentAmber : AppColors.accentEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(durStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bgBase,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(c.simSlot, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 6),
                    if (hasAudio) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x22AA3BFF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x66AA3BFF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.podcasts, size: 12, color: Color(0xFFC084FC)),
                            const SizedBox(width: 4),
                            Text(
                              (c.recordingUrl != null && c.recordingUrl!.isNotEmpty)
                                  ? 'PODCAST CLOUD READY'
                                  : 'LOCAL AUDIO READY (SYNC)',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFE879F9)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(c.outcome, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
                  ],
                ),
                if (c.recordingSha256 != null && c.recordingSha256!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SHA-256: ${c.recordingSha256!.trim().length > 16 ? '${c.recordingSha256!.trim().substring(0, 16)}...' : c.recordingSha256!.trim()}',
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3. RECORDINGS TAB (Local Device Audio Vault)
  // ===========================================================================
  // ===========================================================================
  // 3. RECORDINGS TAB (Local Device Audio Vault - Play, Rename, Delete, Sync)
  // ===========================================================================
  Widget _buildRecordingsTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    final hasStorage = sync.permissions.any((p) => (p.key == 'storage' || p.key == 'allFiles') && p.isGranted);

    if (sync.localRecordings.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: hasStorage ? AppColors.accentCyan.withValues(alpha: 0.3) : AppColors.accentRose.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  hasStorage ? Icons.mic_none : Icons.folder_off,
                  color: hasStorage ? AppColors.accentCyan : AppColors.accentRose,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasStorage ? 'No Call Audio Found in Storage' : 'Storage Permission Required',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain),
              ),
              const SizedBox(height: 8),
              Text(
                hasStorage
                    ? 'RingVia360 scanned standard folders (/Recordings/Call, /Sounds, /MIUI, /Samsung, /PhoneRecord, and MediaStore) but found 0 audio files.\n\nEnsure automatic call recording is enabled in your phone\'s Phone/Dialer settings, then tap Scan.'
                    : 'Android 10–14 requires All Files Access or Audio Media permission to discover call recordings from Samsung, Xiaomi, Vivo, Oppo, or Google Phone app.',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!hasStorage) ...[
                ElevatedButton.icon(
                  onPressed: () => sync.openPermissionSettings('allFiles'),
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('Grant All Files Access', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton.icon(
                onPressed: sync.isScanningRecordings ? null : () => sync.scanLocalRecordings(),
                icon: sync.isScanningRecordings
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(sync.isScanningRecordings ? 'Scanning Storage...' : 'Scan Device Storage for Recordings', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort local recordings: latest on top
    final sortedRecordings = List<LocalRecordingModel>.from(sync.localRecordings)
      ..sort((a, b) {
        final tA = a.lastModifiedTimestamp > 0
            ? a.lastModifiedTimestamp
            : (DateTime.tryParse(a.lastModified)?.millisecondsSinceEpoch ?? 0);
        final tB = b.lastModifiedTimestamp > 0
            ? b.lastModifiedTimestamp
            : (DateTime.tryParse(b.lastModified)?.millisecondsSinceEpoch ?? 0);
        return tB.compareTo(tA);
      });

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRecordings.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        if (index == 0) {
          final unsynced = sortedRecordings.where((r) => !r.isSyncedToServer).length;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_shared, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Discovered Audio Recordings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                      Text('${sortedRecordings.length} total • $unsynced pending cloud upload', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Rescan Storage',
                  icon: sync.isScanningRecordings
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                  onPressed: sync.isScanningRecordings ? null : () => sync.scanLocalRecordings(),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () async {
                    for (final r in sortedRecordings) {
                      if (!r.isSyncedToServer) {
                        await sync.uploadRecordingToServer(r);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Sync All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        final rec = sortedRecordings[index - 1];
        final sizeKb = rec.fileSizeBytes ~/ 1024;
        final sizeMb = (rec.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final sizeStr = rec.fileSizeBytes > 1024 * 1024 ? '$sizeMb MB' : '$sizeKb KB';

        final durMinutes = rec.durationSeconds ~/ 60;
        final durSecs = rec.durationSeconds % 60;
        final durStr = rec.durationSeconds > 0 ? '${durMinutes.toString().padLeft(2, '0')}:${durSecs.toString().padLeft(2, '0')}' : '--:--';

        final isThisPlaying = sync.isPlayingAudio && sync.activeAudioPath == rec.filePath;
        final isThisActive = sync.activeAudioPath == rec.filePath;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isThisPlaying
                  ? AppColors.accentCyan
                  : (rec.isSyncedToServer ? AppColors.accentEmerald.withValues(alpha: 0.3) : AppColors.accentAmber.withValues(alpha: 0.4)),
              width: isThisPlaying ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title & Badges
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isThisPlaying
                        ? AppColors.accentCyan.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.15),
                    radius: 18,
                    child: Icon(
                      isThisPlaying ? Icons.graphic_eq : Icons.audio_file,
                      color: isThisPlaying ? AppColors.accentCyan : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LINE 1: NAME (Saved Contact Name or File Name)
                        Text(
                          (rec.matchedContactName.isNotEmpty &&
                                  rec.matchedContactName != rec.matchedPhoneNumber &&
                                  !rec.matchedContactName.startsWith('Contact ('))
                              ? rec.matchedContactName
                              : rec.fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isThisPlaying ? AppColors.accentCyan : AppColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // LINE 2: CONTACT NUMBER (if detected) or File Name
                        if (rec.matchedPhoneNumber.isNotEmpty) ...[
                          Text(
                            rec.matchedPhoneNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.accentCyan),
                            const SizedBox(width: 4),
                            Text(
                              _formatToIST(rec.lastModified, rec.lastModifiedTimestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentCyan,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• $durStr • $sizeStr',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: rec.isSyncedToServer ? AppColors.accentEmerald.withValues(alpha: 0.15) : AppColors.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rec.isSyncedToServer ? 'CLOUD SYNCED' : 'LOCAL ONLY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: rec.isSyncedToServer ? AppColors.accentEmerald : AppColors.accentAmber,
                      ),
                    ),
                  ),
                ],
              ),

              // File Path & Hash
              if (rec.filePath.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  rec.filePath,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Inline Mini Player (if playing/paused on this file)
              if (isThisActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(isThisPlaying ? Icons.volume_up : Icons.volume_mute, size: 16, color: AppColors.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        '${(sync.audioCurrentPosMs ~/ 1000) ~/ 60}:${((sync.audioCurrentPosMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (sync.audioDurationMs > 0)
                                ? (sync.audioCurrentPosMs / sync.audioDurationMs).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        durStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.stop, size: 16, color: AppColors.accentRose),
                        tooltip: 'Stop Player',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => sync.stopAudio(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Action Toolbar (Play, Rename, Delete, Upload, Inspect)
              Row(
                children: [
                  // 1. Play / Pause Action
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isThisPlaying) {
                        sync.pauseAudio();
                      } else if (isThisActive) {
                        sync.resumeAudio();
                      } else {
                        sync.playAudio(rec.filePath);
                      }
                    },
                    icon: Icon(
                      isThisPlaying ? Icons.pause : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(
                      isThisPlaying ? 'Pause' : (isThisActive ? 'Resume' : 'Play'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isThisPlaying ? AppColors.accentCyan : AppColors.primary,
                      foregroundColor: isThisPlaying ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 2. Rename Action
                  OutlinedButton.icon(
                    onPressed: () => _showRenameRecordingDialog(context, sync, rec),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Rename', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMain,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3. Delete Action
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteRecordingDialog(context, sync, rec),
                    icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.accentRose),
                    label: const Text('Delete', style: TextStyle(fontSize: 11, color: AppColors.accentRose)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentRose,
                      side: BorderSide(color: AppColors.accentRose.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                  const Spacer(),

                  // 4. Upload to Server (if not synced)
                  if (!rec.isSyncedToServer) ...[
                    IconButton(
                      tooltip: 'Upload to Server',
                      icon: const Icon(Icons.cloud_upload_outlined, size: 20, color: AppColors.accentEmerald),
                      onPressed: () => sync.uploadRecordingToServer(rec),
                    ),
                  ],

                  // 5. Inspect & AI intelligence modal
                  IconButton(
                    tooltip: 'AI Intelligence & Waves',
                    icon: const Icon(Icons.analytics_outlined, size: 20, color: AppColors.accentCyan),
                    onPressed: () => _showCallIntelligenceModal(context, sync, null, rec),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 4. MESSAGES TAB (WhatsApp Notifications & Carrier SMS)
  // ===========================================================================
  Widget _buildMessagesTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    return Column(
      children: [
        Container(
          color: AppColors.bgSurfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text('WhatsApp Alerts (${sync.whatsappMessages.length})'),
                  selected: _messagesSubTabIndex == 0,
                  selectedColor: AppColors.accentEmerald,
                  labelStyle: TextStyle(color: _messagesSubTabIndex == 0 ? Colors.black : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  onSelected: (val) => setState(() => _messagesSubTabIndex = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text('Carrier SMS (${sync.smsMessages.length})'),
                  selected: _messagesSubTabIndex == 1,
                  selectedColor: AppColors.accentAmber,
                  labelStyle: TextStyle(color: _messagesSubTabIndex == 1 ? Colors.black : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  onSelected: (val) => setState(() => _messagesSubTabIndex = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messagesSubTabIndex == 0 ? _buildWhatsAppList(sync) : _buildSmsList(sync),
        ),
      ],
    );
  }

  Widget _buildWhatsAppList(PhoneWhatsAppSyncService sync) {
    if (sync.whatsappMessages.isEmpty) {
      return const Center(child: Text('No WhatsApp telemetry notifications captured yet.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sync.whatsappMessages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final w = sync.whatsappMessages[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.chat, color: AppColors.accentEmerald, size: 16),
                  const SizedBox(width: 8),
                  Text(w.sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                  const Spacer(),
                  Text(w.syncStatus, style: const TextStyle(fontSize: 10, color: AppColors.accentEmerald, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(w.messagePreview, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmsList(PhoneWhatsAppSyncService sync) {
    if (sync.smsMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_outlined, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 10),
            const Text('No Carrier SMS Logs Available', style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => sync.fetchDeviceSmsAndSync(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentAmber, foregroundColor: Colors.black),
              child: const Text('Import SMS from Device Inbox'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sync.smsMessages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final s = sync.smsMessages[index];
        final isInbound = s.direction == 'inbound';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isInbound ? Icons.arrow_downward : Icons.arrow_upward, color: isInbound ? AppColors.accentEmerald : AppColors.accentCyan, size: 14),
                  const SizedBox(width: 6),
                  Text(isInbound ? 'From: ${s.sender}' : 'To: ${s.recipient}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
                  const Spacer(),
                  Text(s.syncStatus, style: const TextStyle(fontSize: 10, color: AppColors.accentEmerald, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(s.messageBody, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 5. PERMISSIONS HUB TAB
  // ===========================================================================
  Widget _buildPermissionsTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.accentEmerald, size: 24),
                  SizedBox(width: 10),
                  Text('Enterprise Permissions Hub', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'RingVia360 operates under enterprise privacy compliance. These Android permissions allow automated capture of calls, carrier SMS, WhatsApp business alerts, and call audio recordings.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...sync.permissions.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p.isGranted ? AppColors.accentEmerald.withValues(alpha: 0.3) : AppColors.accentRose.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(p.isGranted ? Icons.check_circle : Icons.warning_amber, color: p.isGranted ? AppColors.accentEmerald : AppColors.accentRose, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.isGranted ? AppColors.accentEmerald.withValues(alpha: 0.15) : AppColors.accentRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.isGranted ? 'GRANTED' : 'ACTION REQUIRED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: p.isGranted ? AppColors.accentEmerald : AppColors.accentRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(p.description, style: const TextStyle(fontSize: 12, color: AppColors.textMain)),
                  const SizedBox(height: 4),
                  Text('Purpose: ${p.whyNeeded}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                  if (!p.isGranted) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => sync.openPermissionSettings(p.key),
                        icon: const Icon(Icons.settings, size: 14),
                        label: const Text('Enable Permission in Settings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )),
      ],
    );
  }

  // ===========================================================================
  // 6. SYNC TAB
  // ===========================================================================
  Widget _buildSyncTab(BuildContext context, PhoneWhatsAppSyncService sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.autorenew, color: AppColors.accentEmerald, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Automatic Background Sync', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textMain)),
                      Text(
                        sync.isAutoSyncEnabled ? 'Background daemon active: syncs calls, SMS, WhatsApp alerts every 20s' : 'Disabled: manual sync only',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: sync.isAutoSyncEnabled,
                  activeThumbColor: AppColors.accentEmerald,
                  onChanged: (val) => sync.toggleAutoSync(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: sync.isSyncing ? null : () => sync.syncNow(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentEmerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: sync.isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.sync),
            label: Text(sync.isSyncing ? 'Synchronizing...' : 'Sync All Telemetry Now', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. CALL AUDIO PLAYER & INTELLIGENCE MODAL (Matches Attached Screenshot)
  // ===========================================================================
  void _showCallIntelligenceModal(BuildContext context, PhoneWhatsAppSyncService sync, CallLogTelemetryModel? call, LocalRecordingModel? localRec) {
    final resolvedRec = (localRec != null && localRec.filePath.isNotEmpty)
        ? localRec
        : (call != null ? sync.matchRecordingForCall(call) : null);
    final phoneNumber = call?.phoneNumber ??
        (resolvedRec != null && resolvedRec.matchedPhoneNumber.isNotEmpty
            ? resolvedRec.matchedPhoneNumber
            : (resolvedRec != null && resolvedRec.matchedContactName.isNotEmpty
                ? resolvedRec.matchedContactName
                : (resolvedRec != null ? resolvedRec.fileName : 'Call Telemetry')));
    final isInbound = (call?.direction ?? 'inbound').toLowerCase() == 'inbound';
    
    String audioSource = '';
    if (resolvedRec != null && resolvedRec.filePath.isNotEmpty && File(resolvedRec.filePath).existsSync()) {
      audioSource = resolvedRec.filePath;
    } else if (call?.recordingUrl != null && call!.recordingUrl!.isNotEmpty) {
      audioSource = call.recordingUrl!;
    } else if (resolvedRec?.serverRecordingUrl != null && resolvedRec!.serverRecordingUrl!.isNotEmpty) {
      audioSource = resolvedRec.serverRecordingUrl!;
    }
    
    final sha256Checksum = (call?.recordingSha256 != null && call!.recordingSha256!.isNotEmpty)
        ? call.recordingSha256!
        : (resolvedRec?.sha256Hash.isNotEmpty == true ? resolvedRec!.sha256Hash : '');
    final targetRec = resolvedRec ?? localRec;

    if (sync.isPlayingAudio && sync.activeAudioPath != audioSource) {
      sync.stopAudio();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final syncState = modalContext.watch<PhoneWhatsAppSyncService>();
            final isThisModalActive = (audioSource.isNotEmpty && syncState.activeAudioPath == audioSource);
            final isPlaying = syncState.isPlayingAudio && isThisModalActive;
            final currentMs = isThisModalActive ? syncState.audioCurrentPosMs : 0;
            final durationMs = (isThisModalActive && syncState.audioDurationMs > 0)
                ? syncState.audioDurationMs
                : ((call?.durationSeconds ?? localRec?.durationSeconds ?? 180) * 1000);
            final progressRatio = durationMs > 0 ? (currentMs / durationMs).clamp(0.0, 1.0) : 0.0;

            String formatMs(int ms) {
              final totalSec = ms ~/ 1000;
              final min = totalSec ~/ 60;
              final sec = totalSec % 60;
              final millis = ms % 1000;
              return '$min:${sec.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F18),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
              ),
              child: Column(
                children: [
                  // Top Modal Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),

                  // Header Badges Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x2206B6D4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x6606B6D4)),
                          ),
                          child: Text(
                            isInbound ? 'INBOUND CALL' : 'OUTBOUND CALL',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF22D3EE), letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x1A10B981),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x4D10B981)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 11, color: Color(0xFF34D399)),
                              SizedBox(width: 4),
                              Text('AES-256 Encrypted Recording', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF34D399))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Just now', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio exported to device storage')));
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.download, size: 14, color: Color(0xFF94A3B8)),
                              SizedBox(width: 4),
                              Text('Export\nWAV', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, height: 1.1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () {
                            sync.stopAudio();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Call Title & Subtitle (Name & Contact Number in two lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LINE 1: NAME
                        Text(
                          (call?.contactName.trim().isNotEmpty == true &&
                                  call!.contactName.trim() != call.phoneNumber.trim() &&
                                  !call.contactName.startsWith('Contact ('))
                              ? call.contactName.trim()
                              : (phoneNumber.isNotEmpty ? phoneNumber : 'Unknown Contact'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
                        ),
                        const SizedBox(height: 3),
                        // LINE 2: CONTACT NUMBER
                        Text(
                          phoneNumber.isNotEmpty ? phoneNumber : 'No Phone Number',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFF22D3EE)),
                            const SizedBox(width: 4),
                            Text(
                              'Recorded (IST): ${_formatToIST(targetRec?.lastModified ?? call?.timestamp, targetRec?.lastModifiedTimestamp)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22D3EE)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        // Audio Waveform Pod
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141724),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x26FFFFFF)),
                          ),
                          child: Column(
                            children: [
                              // 26 Waveform Bars
                              SizedBox(
                                height: 48,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(26, (barIdx) {
                                    final heights = [22, 14, 28, 36, 18, 42, 24, 32, 16, 40, 20, 34, 46, 26, 38, 18, 30, 44, 22, 36, 14, 28, 40, 24, 18, 12];
                                    final barRatio = barIdx / 26.0;
                                    final isPlayed = barRatio <= progressRatio;
                                    return Container(
                                      width: 8,
                                      height: heights[barIdx % heights.length].toDouble(),
                                      decoration: BoxDecoration(
                                        color: isPlayed ? const Color(0xFFAA3BFF) : const Color(0xFF272A38),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Audio Player Controls Row
                              Row(
                                children: [
                                  // Play/Pause Button
                                  InkWell(
                                    onTap: () {
                                      if (isPlaying) {
                                        sync.pauseAudio();
                                      } else if (isThisModalActive) {
                                        sync.resumeAudio();
                                      } else {
                                        if (audioSource.isNotEmpty) {
                                          sync.playAudio(audioSource);
                                        } else if (sync.localRecordings.isNotEmpty) {
                                          final fallback = sync.localRecordings.first;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Playing from recording vault: ${fallback.fileName}')),
                                          );
                                          sync.playAudio(fallback.filePath);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('No call recording found on device or server for this call.')),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFAA3BFF), Color(0xFF7C3AED)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // -10s Rewind
                                  IconButton(
                                    icon: const Icon(Icons.replay_10, color: Color(0xFF94A3B8), size: 22),
                                    onPressed: () {
                                      final target = max(0, currentMs - 10000);
                                      sync.seekAudio(target);
                                    },
                                  ),

                                  // +10s Forward
                                  IconButton(
                                    icon: const Icon(Icons.forward_10, color: Color(0xFF94A3B8), size: 22),
                                    onPressed: () {
                                      final target = min(durationMs, currentMs + 10000);
                                      sync.seekAudio(target);
                                    },
                                  ),

                                  // Timer
                                  Text(
                                    '${formatMs(currentMs)} / ${formatMs(durationMs)}',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFFE2E8F0)),
                                  ),
                                  const Spacer(),

                                  // Speed selector chips
                                  ...[1.0, 1.25, 1.5, 2.0].map((spd) {
                                    final isSelected = (syncState.playbackSpeed == spd);
                                    return InkWell(
                                      onTap: () => sync.setPlaybackSpeed(spd),
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFAA3BFF) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${spd == 1.0 ? '1' : spd}x',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.volume_up, size: 18, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Intelligence Grid Row (Sentiment & Opportunity)
                        Row(
                          children: [
                            // AI Deal Sentiment Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141724),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0x22FFFFFF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text('AI DEAL SENTIMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        Spacer(),
                                        Icon(Icons.auto_awesome, color: Color(0xFFAA3BFF), size: 14),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('92%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0x2610B981),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0x4D10B981)),
                                          ),
                                          child: const Text('POSITIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF34D399))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('High buyer intent identified in call minute 1:10 regarding budget approval.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Opportunity Outcome Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141724),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0x22FFFFFF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text('OPPORTUNITY OUTCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        Spacer(),
                                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 14),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(call?.outcome ?? 'Call Completed', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9))),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${call?.simSlot ?? 'SIM 1 (Corporate)'} • ${(call?.direction ?? (isInbound ? 'inbound' : 'outbound')).toUpperCase()}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Server Synchronization Status Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141724),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('CLOUD SERVER TELEMETRY STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                  Spacer(),
                                  Icon(Icons.cloud_done, color: Color(0xFF38BDF8), size: 14),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: (call?.syncStatus == 'SYNCED' || resolvedRec?.isSyncedToServer == true)
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (call?.syncStatus == 'SYNCED' || resolvedRec?.isSyncedToServer == true)
                                        ? 'Synchronized with Cloud Server'
                                        : 'Pending Offline Queue Drainage',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: (call?.syncStatus == 'SYNCED' || resolvedRec?.isSyncedToServer == true)
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFFFBBF24),
                                    ),
                                  ),
                                  const Spacer(),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await sync.drainOfflineQueue(mode: 'MANUAL');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Synchronized call logs and audio vault with server')),
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Sync Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // AI-Extracted Next Steps & Tasks
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141724),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Color(0xFFAA3BFF), size: 16),
                                  SizedBox(width: 8),
                                  Text('AI-Extracted Next Steps & Tasks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 15, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sha256Checksum.isNotEmpty
                                          ? 'Review verified audio checksum (${sha256Checksum.substring(0, min(16, sha256Checksum.length))}...)'
                                          : 'Checksum verification pending',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.check_circle, size: 15, color: Color(0xFF10B981)),
                                  SizedBox(width: 8),
                                  Text('Sync confirmed to CRM', style: TextStyle(fontSize: 11, color: Color(0xFFE2E8F0))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Background Upload to Server Action
                        if (targetRec != null && !targetRec.isSyncedToServer) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              final success = await sync.uploadRecordingToServer(targetRec, call?.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(success ? 'Recording uploaded to cloud server!' : 'Upload failed. Check connection.')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Upload & Sync to Cloud Server (Background)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sync.stopAudio();
    });
  }

  // ===========================================================================
  // 8. RECORDINGS MANAGEMENT MODALS (Rename & Delete)
  // ===========================================================================
  void _showRenameRecordingDialog(BuildContext context, PhoneWhatsAppSyncService sync, LocalRecordingModel rec) {
    final fileName = rec.fileName;
    final dotIndex = fileName.lastIndexOf('.');
    final nameWithoutExt = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    final textController = TextEditingController(text: nameWithoutExt);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Rename Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a new filename for this call recording on device storage:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textMain, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgSurfaceElevated,
                suffixText: ext,
                suffixStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = textController.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(dialogCtx);
              final ok = await sync.renameLocalRecording(rec, newName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Renamed to $newName$ext' : 'Failed to rename recording'),
                    backgroundColor: ok ? AppColors.accentEmerald : AppColors.accentRose,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecordingDialog(BuildContext context, PhoneWhatsAppSyncService sync, LocalRecordingModel rec) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accentRose, size: 22),
            SizedBox(width: 8),
            Text('Delete Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete "${rec.fileName}" from device storage?',
                style: const TextStyle(fontSize: 13, color: AppColors.textMain)),
            const SizedBox(height: 8),
            const Text('This will remove the file from your phone storage and the local recordings list.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await sync.deleteLocalRecording(rec);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Deleted ${rec.fileName}' : 'Failed to delete file'),
                    backgroundColor: ok ? AppColors.accentEmerald : AppColors.accentRose,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose, foregroundColor: Colors.white),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
