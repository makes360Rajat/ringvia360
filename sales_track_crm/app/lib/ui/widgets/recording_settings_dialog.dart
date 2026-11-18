import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/telemetry_sync_service.dart';

class RecordingSettingsDialog extends StatefulWidget {
  final TelemetrySyncService syncService;

  const RecordingSettingsDialog({
    super.key,
    required this.syncService,
  });

  static Future<void> show(BuildContext context, TelemetrySyncService service) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RecordingSettingsDialog(syncService: service),
    );
  }

  @override
  State<RecordingSettingsDialog> createState() => _RecordingSettingsDialogState();
}

class _RecordingSettingsDialogState extends State<RecordingSettingsDialog> {
  late bool _masterEnabled;
  late bool _recordIncoming;
  late bool _recordOutgoing;
  late bool _inCallIndicator;
  late bool _autoSync;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  void _loadValues() {
    final s = widget.syncService;
    _masterEnabled = s.recordingMasterEnabled;
    _recordIncoming = s.recordIncomingCalls;
    _recordOutgoing = s.recordOutgoingCalls;
    _inCallIndicator = s.showInCallIndicator;
    _autoSync = s.autoUploadRecordings;
  }

  Future<void> _updateValue({
    bool? master,
    bool? incoming,
    bool? outgoing,
    bool? inCall,
    bool? autoSync,
  }) async {
    setState(() {
      if (master != null) _masterEnabled = master;
      if (incoming != null) _recordIncoming = incoming;
      if (outgoing != null) _recordOutgoing = outgoing;
      if (inCall != null) _inCallIndicator = inCall;
      if (autoSync != null) _autoSync = autoSync;
    });

    await widget.syncService.updateRecordingPreferences(
      masterEnabled: master,
      incoming: incoming,
      outgoing: outgoing,
      inCallIndicator: inCall,
      autoSync: autoSync,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SalesTrackTheme.of(context);
    final service = widget.syncService;
    final hasAudioPermission = service.hasRecordingsFolderPermission;
    final localCount = service.localRecordings.length;
    final pendingCount = service.pendingRecordingsCount;

    return Dialog(
      backgroundColor: colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _masterEnabled ? colors.primary.withOpacity(0.12) : colors.textSecondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: _masterEnabled ? colors.primary : colors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call Recording & Privacy',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'In-call visibility, direction & CRM sync',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // Master Switch Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _masterEnabled ? colors.primary.withOpacity(0.08) : colors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _masterEnabled ? colors.primary.withOpacity(0.3) : colors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Call Recording Feature',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _masterEnabled ? colors.success.withOpacity(0.15) : colors.textSecondary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _masterEnabled ? 'ACTIVE' : 'PAUSED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _masterEnabled ? colors.success : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _masterEnabled
                                    ? 'Audio capture & sync enabled for phone calls.'
                                    : 'Call recording disabled. Call tracking & logs remain active.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _masterEnabled,
                          activeColor: colors.primary,
                          onChanged: (val) => _updateValue(master: val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // IN-CALL VISIBILITY MODE SELECTOR
                  Text(
                    'IN-CALL VISIBILITY MODE (DURING CALL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Silent / Background Mode Card
                  _buildModeOption(
                    context: context,
                    colors: colors,
                    isSelected: !_inCallIndicator,
                    icon: Icons.visibility_off_rounded,
                    title: 'Silent / Private Calling Mode',
                    subtitle: 'Hides all in-call indicators, notifications, and caller overlays during active calls. Operates silently in the background.',
                    badgeText: 'RECOMMENDED',
                    badgeColor: colors.primary,
                    onTap: _masterEnabled ? () => _updateValue(inCall: false) : null,
                  ),

                  const SizedBox(height: 10),

                  // Public / Visible Mode Card
                  _buildModeOption(
                    context: context,
                    colors: colors,
                    isSelected: _inCallIndicator,
                    icon: Icons.visibility_rounded,
                    title: 'Public / Transparent Mode',
                    subtitle: 'Shows heads-up caller ID and active notification indicating that recording/telemetry is active.',
                    badgeText: 'VISIBLE',
                    badgeColor: colors.info,
                    onTap: _masterEnabled ? () => _updateValue(inCall: true) : null,
                  ),

                  const SizedBox(height: 20),

                  // CALL DIRECTION FILTERS
                  Text(
                    'CALL DIRECTION RECORDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        // Incoming
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.call_received_rounded, color: colors.success, size: 18),
                          ),
                          title: Text(
                            'Record Incoming Calls',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Capture audio for answered inbound calls',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          value: _recordIncoming && _masterEnabled,
                          activeColor: colors.primary,
                          onChanged: _masterEnabled ? (v) => _updateValue(incoming: v) : null,
                        ),
                        Divider(height: 1, color: colors.border.withOpacity(0.6)),
                        // Outgoing
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.call_made_rounded, color: colors.primary, size: 18),
                          ),
                          title: Text(
                            'Record Outgoing Calls',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Capture audio for placed outbound calls',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          value: _recordOutgoing && _masterEnabled,
                          activeColor: colors.primary,
                          onChanged: _masterEnabled ? (v) => _updateValue(outgoing: v) : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // STORAGE & SYNC PREFERENCES
                  Text(
                    'STORAGE & CRM SYNCHRONIZATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_upload_rounded, color: colors.primary, size: 18),
                          ),
                          title: Text(
                            'Auto-Sync Audio to CRM',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _autoSync
                                ? 'Uploads audio to CRM server as soon as call finishes'
                                : 'Stores audio on device only. Manual upload required.',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          value: _autoSync && _masterEnabled,
                          activeColor: colors.primary,
                          onChanged: _masterEnabled ? (v) => _updateValue(autoSync: v) : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // PERMISSION STATUS CARD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasAudioPermission ? colors.success.withOpacity(0.08) : colors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasAudioPermission ? colors.success.withOpacity(0.25) : colors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasAudioPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: hasAudioPermission ? colors.success : colors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audio & Media Permission',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasAudioPermission
                                    ? 'Granted — app can locate and process recording files (.m4a, .mp3, .wav).'
                                    : 'Permission needed to access and upload phone call audio files.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!hasAudioPermission) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await service.requestPermission('audio');
                              await service.checkPermissions();
                              if (mounted) setState(() {});
                            },
                            child: const Text('Grant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SAMSUNG / SYSTEM DIALER CALLOUT
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066FF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0066FF).withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF0066FF), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Samsung & Native Dialer Note',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0066FF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If your phone screen shows a red [ 🔴 00:10 ] recording pill while calling, this is displayed by your Samsung Phone app. '
                                'To hide Samsung’s dialer pill: open Samsung Phone > 3 dots (⋮) > Settings > Record calls > toggle off "Auto record calls". '
                                'CallVia360 will continue capturing and syncing recordings quietly in Silent Mode.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: colors.textPrimary.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // QUICK ACTIONS & STATS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 16),
                          label: Text(
                            'Scan Audio ($localCount)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await service.scanLocalRecordings();
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Found ${service.localRecordings.length} audio recordings on phone'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: Text(
                            'Sync Audio ($pendingCount)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: service.isSyncing
                              ? null
                              : () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Uploading audio recordings to CRM...'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  await service.syncNow(uploadRecordings: true);
                                  if (mounted) setState(() {});
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required SalesTrackColors colors,
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.08) : colors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.cardBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                activeColor: colors.primary,
                onChanged: isEnabled ? (_) => onTap() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

