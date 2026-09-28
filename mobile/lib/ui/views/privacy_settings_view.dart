import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/local_recording_service.dart';
import '../../data/services/native_call_sensor_service.dart';
import '../view_models/call_feed_view_model.dart';

class PrivacySettingsView extends StatefulWidget {
  const PrivacySettingsView({super.key});

  @override
  State<PrivacySettingsView> createState() => _PrivacySettingsViewState();
}

class _PrivacySettingsViewState extends State<PrivacySettingsView> {
  bool _enforceWorkHours = true;
  bool _e2eeEnabled = true;
  bool _twoPartyConsentTone = true;
  bool _autoRedactPii = true;

  bool _isLoadingRecordings = false;
  bool _isSyncingAll = false;
  String? _uploadingFilePath;
  List<LocalVaultRecording> _recordings = [];
  bool _hasOverlayPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecordings();
      _checkOverlayPermission();
    });
  }

  Future<void> _checkOverlayPermission() async {
    final sensor = context.read<NativeCallSensorService>();
    final hasPerm = await sensor.hasOverlayPermission();
    if (mounted) {
      setState(() => _hasOverlayPermission = hasPerm);
    }
  }

  Future<void> _requestOverlayPermission() async {
    final sensor = context.read<NativeCallSensorService>();
    await sensor.requestOverlayPermission();
    await Future.delayed(const Duration(seconds: 1));
    _checkOverlayPermission();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoadingRecordings = true);
    try {
      final service = context.read<LocalRecordingService>();
      final items = await service.scanLocalRecordings();
      if (mounted) {
        setState(() {
          _recordings = items;
          _isLoadingRecordings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecordings = false);
    }
  }

  Future<void> _forceUploadSingle(LocalVaultRecording item) async {
    setState(() => _uploadingFilePath = item.filePath);
    try {
      final service = context.read<LocalRecordingService>();
      final url = await service.forceUploadRecording(item);
      if (mounted) {
        if (url != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.bgSurfaceElevated,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.accentEmerald, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Synced ${item.fileName} to server! Attached to live feed.',
                      style: const TextStyle(color: AppColors.textMain, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
          // Refresh feed and local vault
          context.read<CallFeedViewModel>().loadCalls();
          await _loadRecordings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.bgSurfaceElevated,
              content: Text(
                'Upload failed. Check network or server connection.',
                style: TextStyle(color: AppColors.accentRose),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgSurfaceElevated,
            content: Text('Error: $e', style: const TextStyle(color: AppColors.accentRose)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingFilePath = null);
    }
  }

  Future<void> _syncAllUnsynced() async {
    setState(() => _isSyncingAll = true);
    try {
      final service = context.read<LocalRecordingService>();
      final syncedCount = await service.forceUploadAllUnsynced();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgSurfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: AppColors.accentEmerald, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Successfully force-synced $syncedCount recordings to live feed!',
                  style: const TextStyle(color: AppColors.textMain),
                ),
              ],
            ),
          ),
        );
        context.read<CallFeedViewModel>().loadCalls();
        await _loadRecordings();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSyncingAll = false);
    }
  }

  Future<void> _pickAudioAndSync() async {
    try {
      final service = context.read<LocalRecordingService>();
      final item = await service.pickAndImportAudio();
      if (item != null) {
        await _forceUploadSingle(item);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.bgSurfaceElevated,
            content: Text('Failed to import audio: $e', style: const TextStyle(color: AppColors.accentRose)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unsyncedCount = _recordings.where((r) => !r.isSynced).length;
    final totalBytes = _recordings.fold<int>(0, (sum, r) => sum + r.sizeBytes);
    final formattedTotalSize = totalBytes < 1024 * 1024
        ? '${(totalBytes / 1024).toStringAsFixed(1)} KB'
        : '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Fleet Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Knox Overlay Permission Card (ensures pop-up always appears over other apps)
            if (!_hasOverlayPermission) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Enable Pop-up Over Other Apps',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Allow RingVia360 to display the wrap-up screen immediately when a call finishes.',
                            style: TextStyle(fontSize: 11, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _requestOverlayPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            // ── LOCAL STORAGE RECORDINGS & OFFLINE FORCE SYNC CARD ──────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.folder_special, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Local Call Audio Vault',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                              ),
                              Text(
                                'Offline recordings on device & force-sync',
                                style: TextStyle(fontSize: 11, color: AppColors.textDim),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: _isLoadingRecordings
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                        onPressed: _isLoadingRecordings ? null : _loadRecordings,
                        tooltip: 'Scan Local Storage',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Vault Metrics Pill Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StorageMetric(
                          label: 'TOTAL FILES',
                          value: '${_recordings.length}',
                          color: AppColors.textMain,
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderSubtle),
                        _StorageMetric(
                          label: 'USED SPACE',
                          value: formattedTotalSize,
                          color: AppColors.accentCyan,
                        ),
                        Container(width: 1, height: 28, color: AppColors.borderSubtle),
                        _StorageMetric(
                          label: 'UNSYNCED',
                          value: '$unsyncedCount',
                          color: unsyncedCount > 0 ? AppColors.accentAmber : AppColors.accentEmerald,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Button to Pick Audio Directly from Phone Storage
                  GestureDetector(
                    onTap: _pickAudioAndSync,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, color: AppColors.primary, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Pick Audio File from Phone Storage & Sync',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Action Button to Sync All Unsynced Audio
                  if (unsyncedCount > 0) ...[
                    GestureDetector(
                      onTap: _isSyncingAll ? null : _syncAllUnsynced,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accentAmber, Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSyncingAll)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            else
                              const Icon(Icons.cloud_upload, color: Colors.black, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _isSyncingAll
                                  ? 'Force-Syncing Recordings...'
                                  : 'Force Sync $unsyncedCount Unsynced Audio to Live Feed',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Recordings List
                  if (_recordings.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: Text(
                        _isLoadingRecordings
                            ? 'Scanning device storage for recordings...'
                            : 'No local call recordings found on device yet.\nThey appear here automatically after calls.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recordings.length,
                      separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.borderSubtle),
                      itemBuilder: (context, index) {
                        final item = _recordings[index];
                        final isUploadingThis = _uploadingFilePath == item.filePath;

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.isSynced
                                    ? AppColors.accentEmerald.withValues(alpha: 0.15)
                                    : AppColors.accentAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item.isSynced ? Icons.audiotrack : Icons.mic_external_on,
                                size: 18,
                                color: item.isSynced ? AppColors.accentEmerald : AppColors.accentAmber,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fileName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '${item.formattedSize} • ${item.lastModified.hour.toString().padLeft(2, '0')}:${item.lastModified.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textDim),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.isSynced
                                              ? AppColors.accentEmerald.withValues(alpha: 0.12)
                                              : AppColors.accentAmber.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.isSynced ? 'LIVE FEED SYNCED' : 'UNSYNCED',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: item.isSynced ? AppColors.accentEmerald : AppColors.accentAmber,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Force Sync Button
                            if (isUploadingThis)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            else if (!item.isSynced)
                              ElevatedButton.icon(
                                onPressed: () => _forceUploadSingle(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.cloud_upload_outlined, size: 14),
                                label: const Text('Force Send', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: AppColors.accentEmerald, size: 20),
                                onPressed: () => _forceUploadSingle(item),
                                tooltip: 'Re-sync to Live Feed',
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Work Hours Auto-Pause Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, color: AppColors.accentCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Work-Hours Tracking Schedule',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enforceWorkHours,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _enforceWorkHours = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Automatically stops call recording and activity tracking outside of corporate hours to protect employee personal privacy.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Days:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text('Monday – Friday', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Hours:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text('08:30 AM – 06:30 PM (EST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentEmerald)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dual-SIM Hardware Isolation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sim_card_outlined, color: AppColors.accentEmerald, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Hardware Dual-SIM Routing',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimStatusTile(
                    slot: 'SIM Slot 1',
                    carrier: 'AT&T Business (+1 415-700-1122)',
                    status: 'TRACKED & ENCRYPTED',
                    color: AppColors.accentEmerald,
                  ),
                  const SizedBox(height: 8),
                  _SimStatusTile(
                    slot: 'SIM Slot 2',
                    carrier: 'Verizon Personal (+1 415-300-9988)',
                    status: 'EXCLUDED / PRIVACY LOCKED',
                    color: AppColors.accentRose,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Security Controls Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ENTERPRISE COMPLIANCE & KMS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End-to-End Encryption (AES-256-GCM)', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Local encryption before cloud upload', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _e2eeEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _e2eeEnabled = val),
                  ),
                  const Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Two-Party Consent Periodic Beep', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Plays audible tone every 15s for legal compliance', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _twoPartyConsentTone,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _twoPartyConsentTone = val),
                  ),
                  const Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Redact PII in Whisper Transcripts', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Masks credit cards and SSNs automatically', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _autoRedactPii,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _autoRedactPii = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StorageMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _SimStatusTile extends StatelessWidget {
  final String slot;
  final String carrier;
  final String status;
  final Color color;

  const _SimStatusTile({
    required this.slot,
    required this.carrier,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMain)),
              const SizedBox(height: 2),
              Text(carrier, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
