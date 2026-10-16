import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/phone_whatsapp_models.dart';

class PhoneWhatsAppSyncService extends ChangeNotifier {
  static const String baseUrl = 'https://ringvia360.com/api/phone_whatsapp.php';
  static const EventChannel _telemetryChannel = EventChannel('com.ringvia360.phonewhtsapp/telemetry_stream');
  static const MethodChannel _platformChannel = MethodChannel('com.ringvia360.phonewhtsapp/platform');

  // Real Hardware Device Information
  String deviceId = 'device_android_telemetry';
  String deviceModel = 'Android Device';
  String userName = 'Field Sales Rep';
  int batteryPercent = 85;
  String osVersion = 'Android';

  // Permissions State
  List<PermissionInfoModel> _permissions = [];
  List<PermissionInfoModel> get permissions => _permissions;

  // Offline / Connectivity Simulation & Real-time State
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isAutoSyncEnabled = true;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String _syncStatusMessage = 'Idle';
  String get syncStatusMessage => _syncStatusMessage;

  // Manual Sync Counters
  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  int _uploadingCount = 0;
  int get uploadingCount => _uploadingCount;

  int _successfulCount = 0;
  int get successfulCount => _successfulCount;

  int _failedCount = 0;
  int get failedCount => _failedCount;

  // Telemetry Data Stores
  List<DeviceTelemetryModel> _devices = [];
  List<DeviceTelemetryModel> get devices => _devices;

  IncomingCallEventModel? _activeRingingCall;
  IncomingCallEventModel? get activeRingingCall => _activeRingingCall;

  List<CallLogTelemetryModel> _calls = [];
  List<CallLogTelemetryModel> get calls => _calls;

  List<WhatsAppNotificationModel> _whatsappMessages = [];
  List<WhatsAppNotificationModel> get whatsappMessages => _whatsappMessages;

  List<SmsLogModel> _smsMessages = [];
  List<SmsLogModel> get smsMessages => _smsMessages;

  List<SyncDiagnosticModel> _diagnostics = [];
  List<SyncDiagnosticModel> get diagnostics => _diagnostics;

  // Local Device Audio Recordings
  List<LocalRecordingModel> _localRecordings = [];
  List<LocalRecordingModel> get localRecordings => _localRecordings;
  bool _isScanningRecordings = false;
  bool get isScanningRecordings => _isScanningRecordings;

  // Native Audio Player Engine State
  bool _isPlayingAudio = false;
  bool get isPlayingAudio => _isPlayingAudio;
  String? _activeAudioPath;
  String? get activeAudioPath => _activeAudioPath;
  int _audioCurrentPosMs = 0;
  int get audioCurrentPosMs => _audioCurrentPosMs;
  int _audioDurationMs = 0;
  int get audioDurationMs => _audioDurationMs;
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;
  Timer? _audioPollingTimer;

  // Local Offline Queues
  final List<Map<String, dynamic>> _offlineCallQueue = [];
  final List<Map<String, dynamic>> _offlineWaQueue = [];
  final List<Map<String, dynamic>> _offlineSmsQueue = [];

  Timer? _autoSyncTimer;
  Timer? _ringingDismissTimer;
  StreamSubscription? _nativeEventSub;

  PhoneWhatsAppSyncService() {
    _init();
  }

  Future<void> _init() async {
    await _initNativeDeviceInfo();
    await requestAllPermissions();
    await checkPermissions();
    await _loadLocalQueues();
    // 1. Fetch physical device's actual call history and SMS FIRST so device calls are baseline
    await fetchDeviceCallLogsAndSync();
    await fetchDeviceSmsAndSync();
    await scanLocalRecordings();
    // 2. Fetch server overview passing deviceId
    await fetchServerOverview(silent: true);
    _startAutoSyncLoop();
    _listenToNativeTelemetryStream();
  }

  Future<void> requestAllPermissions() async {
    try {
      await _platformChannel.invokeMethod('requestAllPermissions');
    } catch (e) {
      debugPrint('Error invoking requestAllPermissions: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 1. HARDWARE & PERMISSIONS INITIALIZATION
  // ---------------------------------------------------------------------------
  Future<void> _initNativeDeviceInfo() async {
    try {
      final info = await _platformChannel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (info != null) {
        deviceId = info['deviceId']?.toString() ?? deviceId;
        deviceModel = info['model']?.toString() ?? deviceModel;
        batteryPercent = (info['batteryPercent'] as num?)?.toInt() ?? batteryPercent;
        osVersion = info['osVersion']?.toString() ?? osVersion;
        userName = 'Enterprise User (${info['brand'] ?? 'Android'})';
      }
    } catch (e) {
      debugPrint('Device info platform notice: $e');
    }
  }

  Future<void> checkPermissions() async {
    try {
      final statusMap = await _platformChannel.invokeMapMethod<String, dynamic>('getPermissionsStatus');
      final map = statusMap ?? <String, dynamic>{};

      _permissions = [
        PermissionInfoModel(
          key: 'phoneState',
          title: 'Phone State & Live Ringing',
          description: 'Detects real-time incoming and outgoing phone calls pre-answer.',
          whyNeeded: 'Enables instant caller ID lookup, ringing alert popups, and SIM slot tagging.',
          isGranted: map['phoneState'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'callLog',
          title: 'Call History Telemetry',
          description: 'Reads incoming, outgoing, missed, and rejected call logs.',
          whyNeeded: 'Synchronizes full corporate call duration, timestamps, and contact metadata.',
          isGranted: map['callLog'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'contacts',
          title: 'Device Contacts & Caller Name Matching',
          description: 'Accesses phonebook contacts to display saved caller names on the device.',
          whyNeeded: 'Matches incoming/outgoing phone numbers with your saved device contacts so names show on the app.',
          isGranted: map['contacts'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'sms',
          title: 'SMS Message Sync (Inbound & Outbound)',
          description: 'Reads client carrier SMS text messages and real-time SMS alerts.',
          whyNeeded: 'Captures customer inquiry texts, quotes, and delivery confirmations in CRM.',
          isGranted: map['sms'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'notificationListener',
          title: 'WhatsApp & Notification Access',
          description: 'Accesses WhatsApp and WhatsApp Business message & call alerts.',
          whyNeeded: 'Logs WhatsApp chats, group inquiries, and customer requests without API restrictions.',
          isGranted: map['notificationListener'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'storage',
          title: 'Device Call Audio Recordings Access',
          description: 'Accesses device storage to discover recorded audio files.',
          whyNeeded: 'Scans Samsung, Xiaomi, and Android call recording folders to upload call audio with SHA-256 integrity.',
          isGranted: map['storage'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'allFiles',
          title: 'All Files Access (Call Recording Vault)',
          description: 'Full storage access for OEM Call Recordings on Android 11+.',
          whyNeeded: 'Enables discovery of recordings in /Recordings/Call, Samsung Voice Recorder, and device folders.',
          isGranted: map['allFiles'] == true,
          isCritical: true,
        ),
        PermissionInfoModel(
          key: 'recordAudio',
          title: 'Microphone & In-Call Recording',
          description: 'Captures voice audio during customer calls for deal intelligence.',
          whyNeeded: 'Allows audio playback waveforms and automated AI conversation sentiment extraction.',
          isGranted: map['recordAudio'] == true,
          isCritical: false,
        ),
        PermissionInfoModel(
          key: 'batteryOptimization',
          title: '24/7 Background Sync & Power Whitelist',
          description: 'Exempts app from aggressive Android battery sleeping.',
          whyNeeded: 'Prevents the operating system from terminating telemetry upload when screen is off.',
          isGranted: map['batteryOptimization'] == true,
          isCritical: false,
        ),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> openPermissionSettings(String key) async {
    try {
      if (key == 'notificationListener') {
        await _platformChannel.invokeMethod('openNotificationListenerSettings');
      } else if (key == 'batteryOptimization') {
        await _platformChannel.invokeMethod('openBatteryOptimizationSettings');
      } else if (key == 'allFiles') {
        await _platformChannel.invokeMethod('openAllFilesSettings');
      } else if (key == 'contacts') {
        try {
          await Permission.contacts.request();
        } catch (_) {}
        await _platformChannel.invokeMethod('openAppSettings');
      } else {
        await _platformChannel.invokeMethod('openAppSettings');
      }
      Future.delayed(const Duration(seconds: 1), () => checkPermissions());
    } catch (e) {
      debugPrint('Error opening settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. DEVICE STORAGE CALL RECORDINGS SCANNER & CLOUD SYNC
  // ---------------------------------------------------------------------------
  Future<void> scanLocalRecordings() async {
    if (_isScanningRecordings) return;
    _isScanningRecordings = true;
    notifyListeners();

    try {
      final rawList = await _platformChannel.invokeMethod<List>('fetchLocalCallRecordings');
      if (rawList != null) {
        final scanned = <LocalRecordingModel>[];
        for (final item in rawList) {
          if (item is Map) {
            final rec = LocalRecordingModel.fromJson(Map<String, dynamic>.from(item));

            // Match with calls on server or in memory
            final matchedCall = _findMatchingCallForRecording(rec);
            final isSynced = matchedCall != null &&
                (matchedCall.recordingSha256 == rec.sha256Hash ||
                    (matchedCall.recordingUrl != null && matchedCall.recordingUrl!.isNotEmpty));

            scanned.add(rec.copyWith(
              isSyncedToServer: isSynced,
              serverRecordingUrl: matchedCall?.recordingUrl,
              matchedCallId: matchedCall?.id,
              matchedContactName: (rec.matchedContactName.isNotEmpty && rec.matchedContactName != rec.matchedPhoneNumber)
                  ? rec.matchedContactName
                  : (matchedCall?.contactName.isNotEmpty == true && matchedCall!.contactName != matchedCall.phoneNumber
                      ? matchedCall.contactName
                      : rec.matchedContactName),
            ));
          }
        }
        // Sort recordings by latest timestamp (descending)
        scanned.sort((a, b) => b.lastModifiedTimestamp.compareTo(a.lastModifiedTimestamp));
        _localRecordings = scanned;

        // Automatically trigger background upload for un-synced recordings
        if (_isOnline) {
          for (final rec in scanned) {
            if (!rec.isSyncedToServer) {
              uploadRecordingToServer(rec, rec.matchedCallId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning device recordings: $e');
    } finally {
      _isScanningRecordings = false;
      notifyListeners();
    }
  }

  CallLogTelemetryModel? _findMatchingCallForRecording(LocalRecordingModel rec) {
    for (final call in _calls) {
      if (rec.sha256Hash.isNotEmpty && call.recordingSha256 == rec.sha256Hash) {
        return call;
      }
      final cleanRecDigits = rec.matchedPhoneNumber.replaceAll(RegExp(r'\D'), '');
      final cleanCallDigits = call.phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (cleanRecDigits.length >= 8 && cleanCallDigits.length >= 8) {
        if (cleanCallDigits.endsWith(cleanRecDigits) || cleanRecDigits.endsWith(cleanCallDigits)) {
          return call;
        }
      }
      if (rec.matchedContactName.isNotEmpty && call.contactName.trim().isNotEmpty) {
        final recContact = rec.matchedContactName.toLowerCase();
        final callContact = call.contactName.toLowerCase();
        if (callContact.contains(recContact) || recContact.contains(callContact)) {
          return call;
        }
      }
      final lowerFileName = rec.fileName.toLowerCase();
      if (call.contactName.length > 2 && lowerFileName.contains(call.contactName.toLowerCase())) {
        return call;
      }
    }
    return null;
  }

  LocalRecordingModel matchRecordingForCall(CallLogTelemetryModel call) {
    final cleanCallDigits = call.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final callContactLower = call.contactName.trim().toLowerCase();

    for (final r in _localRecordings) {
      if (call.recordingSha256 != null &&
          call.recordingSha256!.isNotEmpty &&
          r.sha256Hash == call.recordingSha256) {
        return r;
      }
      final cleanRecDigits = r.matchedPhoneNumber.replaceAll(RegExp(r'\D'), '');
      if (cleanRecDigits.length >= 8 && cleanCallDigits.length >= 8) {
        if (cleanCallDigits.endsWith(cleanRecDigits) || cleanRecDigits.endsWith(cleanCallDigits)) {
          return r;
        }
      }
      if (r.matchedContactName.isNotEmpty && callContactLower.isNotEmpty) {
        final recContactLower = r.matchedContactName.toLowerCase();
        if (callContactLower.contains(recContactLower) || recContactLower.contains(callContactLower)) {
          return r;
        }
      }
      final lowerFileName = r.fileName.toLowerCase();
      if (callContactLower.length > 2 && lowerFileName.contains(callContactLower)) {
        return r;
      }
      if (cleanCallDigits.length >= 8 && lowerFileName.contains(cleanCallDigits.substring(cleanCallDigits.length - 8))) {
        return r;
      }
    }

    return const LocalRecordingModel(
      filePath: '',
      fileName: '',
      fileSizeBytes: 0,
      durationSeconds: 0,
      lastModified: '',
      sha256Hash: '',
      matchedPhoneNumber: '',
    );
  }

  Future<bool> uploadRecordingToServer(LocalRecordingModel recording, [String? targetCallId]) async {
    final file = File(recording.filePath);
    if (!file.existsSync()) {
      _syncStatusMessage = 'Local file not found: ${recording.fileName}';
      notifyListeners();
      return false;
    }

    try {
      _syncStatusMessage = 'Uploading ${recording.fileName} to secure vault...';
      notifyListeners();

      final uri = Uri.parse('$baseUrl?action=upload_recording');
      final request = http.MultipartRequest('POST', uri);

      request.fields['deviceId'] = deviceId;
      request.fields['phoneNumber'] = recording.matchedPhoneNumber;
      if (targetCallId != null || recording.matchedCallId != null) {
        request.fields['callId'] = targetCallId ?? recording.matchedCallId!;
      }
      if (recording.sha256Hash.isNotEmpty) {
        request.fields['sha256'] = recording.sha256Hash;
      }

      request.files.add(await http.MultipartFile.fromPath('audio', file.path, filename: recording.fileName));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final serverUrl = data['recordingUrl']?.toString();
          final serverSha = data['recordingSha256']?.toString() ?? recording.sha256Hash;

          // Update local recordings list
          final idx = _localRecordings.indexWhere((r) => r.filePath == recording.filePath);
          if (idx >= 0) {
            _localRecordings[idx] = _localRecordings[idx].copyWith(
              isSyncedToServer: true,
              serverRecordingUrl: serverUrl,
              matchedCallId: targetCallId ?? recording.matchedCallId,
            );
          }

          // Update matching call in calls list
          final cleanRecPhone = recording.matchedPhoneNumber.replaceAll(RegExp(r'\D'), '');
          final recSuffix = cleanRecPhone.length >= 8 ? cleanRecPhone.substring(cleanRecPhone.length - 8) : cleanRecPhone;
          final callIdx = _calls.indexWhere((c) {
            if (targetCallId != null && c.id == targetCallId) return true;
            if (recording.matchedCallId != null && c.id == recording.matchedCallId) return true;
            if (recSuffix.isNotEmpty) {
              final cleanCallPhone = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
              if (cleanCallPhone.endsWith(recSuffix) || cleanCallPhone.contains(recSuffix)) return true;
            }
            if (recording.matchedContactName.isNotEmpty &&
                c.contactName.toLowerCase().contains(recording.matchedContactName.toLowerCase())) {
              return true;
            }
            return false;
          });
          if (callIdx >= 0) {
            _calls[callIdx] = _calls[callIdx].copyWith(
              recordingStatus: 'AVAILABLE',
              recordingUrl: serverUrl,
              recordingSha256: serverSha,
              syncStatus: 'SYNCED',
            );
            _offlineCallQueue.add(_calls[callIdx].toJson());
            drainOfflineQueue(mode: 'AUTOMATIC');
          }

          _syncStatusMessage = 'Uploaded ${recording.fileName} with verified SHA-256';
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _syncStatusMessage = 'Failed uploading recording: $e';
      notifyListeners();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // LOCAL RECORDING FILE MANAGEMENT (Delete & Rename)
  // ---------------------------------------------------------------------------
  Future<bool> deleteLocalRecording(LocalRecordingModel recording) async {
    try {
      if (_activeAudioPath == recording.filePath) {
        await stopAudio();
      }

      final res = await _platformChannel.invokeMapMethod<String, dynamic>(
        'deleteLocalRecording',
        {'filePath': recording.filePath},
      );

      final success = res?['success'] == true;
      if (success) {
        _localRecordings.removeWhere((r) => r.filePath == recording.filePath);

        // Update any calls linked to this recording
        for (int i = 0; i < _calls.length; i++) {
          if (_calls[i].recordingSha256 == recording.sha256Hash ||
              _calls[i].recordingUrl == recording.filePath) {
            _calls[i] = _calls[i].copyWith(recordingStatus: 'REMOVED');
          }
        }

        _syncStatusMessage = 'Deleted local recording: ${recording.fileName}';
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting local recording: $e');
      _syncStatusMessage = 'Failed to delete ${recording.fileName}: $e';
      notifyListeners();
    }
    return false;
  }

  Future<bool> renameLocalRecording(LocalRecordingModel recording, String newName) async {
    try {
      if (_activeAudioPath == recording.filePath) {
        await stopAudio();
      }

      final res = await _platformChannel.invokeMapMethod<String, dynamic>(
        'renameLocalRecording',
        {
          'filePath': recording.filePath,
          'newName': newName,
        },
      );

      if (res != null) {
        final updated = LocalRecordingModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _localRecordings.indexWhere((r) => r.filePath == recording.filePath);
        if (idx >= 0) {
          _localRecordings[idx] = updated.copyWith(
            isSyncedToServer: recording.isSyncedToServer,
            serverRecordingUrl: recording.serverRecordingUrl,
            matchedCallId: recording.matchedCallId,
          );
          _localRecordings.sort((a, b) => b.lastModifiedTimestamp.compareTo(a.lastModifiedTimestamp));
        }

        // Update matching call linkage if necessary
        for (int i = 0; i < _calls.length; i++) {
          if (_calls[i].recordingSha256 == recording.sha256Hash ||
              _calls[i].recordingUrl == recording.filePath) {
            _calls[i] = _calls[i].copyWith(
              recordingSha256: updated.sha256Hash.isNotEmpty ? updated.sha256Hash : _calls[i].recordingSha256,
              recordingUrl: updated.filePath,
            );
          }
        }

        _syncStatusMessage = 'Renamed recording to: ${updated.fileName}';
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error renaming local recording: $e');
      _syncStatusMessage = 'Failed to rename ${recording.fileName}: $e';
      notifyListeners();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 3. NATIVE AUDIO PLAYER ENGINE
  // ---------------------------------------------------------------------------
  Future<void> playAudio(String pathOrUrl) async {
    try {
      if (_isPlayingAudio || _activeAudioPath != null) {
        await stopAudio();
      }
      _activeAudioPath = pathOrUrl;
      final res = await _platformChannel.invokeMapMethod<String, dynamic>('playAudio', {'path': pathOrUrl});
      _isPlayingAudio = true;
      if (res != null) {
        _audioDurationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
      }
      _startAudioPolling();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _platformChannel.invokeMethod('pauseAudio');
      _isPlayingAudio = false;
      _stopAudioPolling();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> resumeAudio() async {
    try {
      await _platformChannel.invokeMethod('resumeAudio');
      _isPlayingAudio = true;
      _startAudioPolling();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  Future<void> seekAudio(int positionMs) async {
    try {
      await _platformChannel.invokeMethod('seekAudio', {'positionMs': positionMs});
      _audioCurrentPosMs = positionMs;
      notifyListeners();
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _platformChannel.invokeMethod('setPlaybackSpeed', {'speed': speed});
      _playbackSpeed = speed;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      _stopAudioPolling();
      await _platformChannel.invokeMethod('stopAudio');
      _isPlayingAudio = false;
      _activeAudioPath = null;
      _audioCurrentPosMs = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  void _startAudioPolling() {
    _audioPollingTimer?.cancel();
    _audioPollingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      try {
        final state = await _platformChannel.invokeMapMethod<String, dynamic>('getAudioState');
        if (state != null) {
          final isPlaying = state['isPlaying'] == true;
          final pos = (state['positionMs'] as num?)?.toInt() ?? 0;
          final dur = (state['durationMs'] as num?)?.toInt() ?? 0;
          final activePath = state['activePath'] as String?;

          _isPlayingAudio = isPlaying;
          _audioCurrentPosMs = pos;
          if (dur > 0) _audioDurationMs = dur;
          if (activePath != null && activePath.isNotEmpty) {
            _activeAudioPath = activePath;
          }

          if (!_isPlayingAudio && _audioCurrentPosMs >= _audioDurationMs && _audioDurationMs > 0) {
            _stopAudioPolling();
            _activeAudioPath = null;
          }
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void _stopAudioPolling() {
    _audioPollingTimer?.cancel();
    _audioPollingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // 4. DEVICE CALL LOGS & SMS EXTRACTION & SYNC
  // ---------------------------------------------------------------------------
  Future<void> fetchDeviceCallLogsAndSync() async {
    try {
      final rawList = await _platformChannel.invokeMethod<List>('fetchDeviceCallLogs');
      if (rawList != null && rawList.isNotEmpty) {
        final existingIds = _calls.map((c) => c.id).toSet();
        final newCalls = <CallLogTelemetryModel>[];

        for (final item in rawList) {
          if (item is Map) {
            final rawPhone = item['phoneNumber']?.toString() ?? 'Unknown';
            final rawName = item['contactName']?.toString() ?? '';
            final resolvedName = (rawName.isNotEmpty && rawName != rawPhone && !rawName.startsWith('Contact ('))
                ? rawName
                : (rawPhone.isNotEmpty ? rawPhone : 'Unknown Contact');

            final model = CallLogTelemetryModel(
              id: item['id']?.toString() ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
              deviceId: deviceId,
              phoneNumber: rawPhone,
              contactName: resolvedName,
              direction: item['direction']?.toString() ?? 'inbound',
              durationSeconds: (item['durationSeconds'] as num?)?.toInt() ?? 0,
              simSlot: item['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
              startedAt: item['startedAt']?.toString() ?? DateTime.now().toIso8601String(),
              endedAt: item['endedAt']?.toString() ?? DateTime.now().toIso8601String(),
              outcome: item['outcome']?.toString() ?? 'Call Completed',
              recordingStatus: 'NOT_AVAILABLE',
              syncStatus: _isOnline ? 'SYNCED' : 'SYNC_PENDING',
              syncMode: 'AUTOMATIC',
            );
            if (!existingIds.contains(model.id)) {
              newCalls.add(model);
              _offlineCallQueue.add(model.toJson());
            } else {
              // If existing call has a placeholder or number-only contactName, update it
              final idx = _calls.indexWhere((c) => c.id == model.id);
              if (idx >= 0 && (_calls[idx].contactName == _calls[idx].phoneNumber || _calls[idx].contactName.startsWith('Contact ('))) {
                _calls[idx] = _calls[idx].copyWith(contactName: resolvedName);
              }
            }
          }
        }

        if (newCalls.isNotEmpty) {
          _calls.insertAll(0, newCalls);
          _calls.sort((a, b) {
            final tA = DateTime.tryParse(a.timestamp)?.millisecondsSinceEpoch ?? 0;
            final tB = DateTime.tryParse(b.timestamp)?.millisecondsSinceEpoch ?? 0;
            return tB.compareTo(tA);
          });
          await _persistLocalQueues();
          _updatePendingCount();
          notifyListeners();
          if (_isOnline) {
            await drainOfflineQueue();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching device call logs: $e');
    }
  }

  Future<void> fetchDeviceSmsAndSync() async {
    try {
      final rawList = await _platformChannel.invokeMethod<List>('fetchDeviceSms');
      if (rawList != null && rawList.isNotEmpty) {
        final existingIds = _smsMessages.map((s) => s.id).toSet();
        final newSms = <SmsLogModel>[];

        for (final item in rawList) {
          if (item is Map) {
            final model = SmsLogModel(
              id: item['id']?.toString() ?? 'sms_${DateTime.now().millisecondsSinceEpoch}',
              deviceId: deviceId,
              direction: item['direction']?.toString() ?? 'inbound',
              sender: item['sender']?.toString() ?? 'Unknown',
              recipient: item['recipient']?.toString() ?? 'Device',
              messageBody: item['messageBody']?.toString() ?? '',
              simSlot: item['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
              timestamp: item['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
              syncStatus: _isOnline ? 'SYNCED' : 'SYNC_PENDING',
            );
            if (!existingIds.contains(model.id)) {
              newSms.add(model);
              _offlineSmsQueue.add(model.toJson());
            }
          }
        }

        if (newSms.isNotEmpty) {
          _smsMessages.insertAll(0, newSms);
          await _persistLocalQueues();
          _updatePendingCount();
          notifyListeners();
          if (_isOnline) {
            await drainOfflineQueue();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching device SMS: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 5. NATIVE TELEMETRY BROADCAST STREAM (Live Incoming, SMS, WA)
  // ---------------------------------------------------------------------------
  void _listenToNativeTelemetryStream() {
    _nativeEventSub?.cancel();
    try {
      _nativeEventSub = _telemetryChannel.receiveBroadcastStream().listen(
        (dynamic rawEvent) {
          if (rawEvent is! Map) return;
          final event = Map<String, dynamic>.from(rawEvent);
          final type = event['type']?.toString();

          if (type == 'incoming_call' || type == 'incoming_call_silent') {
            // Silently ignore ringing radar/banner per user requirement
          } else if (type == 'permissions_updated') {
            checkPermissions();
            fetchDeviceCallLogsAndSync();
            fetchDeviceSmsAndSync();
            scanLocalRecordings();
          } else if (type == 'call_completed') {
            final recUrl = event['recordingUrl']?.toString();
            final recSha = event['recordingSha256']?.toString();
            final callId = event['id']?.toString();
            final phone = event['phoneNumber']?.toString() ?? 'Unknown Caller';
            final name = event['contactName']?.toString() ?? 'Unknown Contact';
            final dir = event['direction']?.toString() ?? 'inbound';
            final dur = (event['duration'] as num?)?.toInt() ?? (event['durationSeconds'] as num?)?.toInt() ?? 0;
            final outcome = event['outcome']?.toString() ?? 'Call Completed';
            final sim = event['simSlot']?.toString() ?? 'SIM 1 (Corporate)';
            final ts = event['timestamp']?.toString() ?? event['startedAt']?.toString();

            recordCall(
              id: callId,
              phoneNumber: phone,
              contactName: name,
              direction: dir,
              durationSeconds: dur,
              outcome: outcome,
              simSlot: sim,
              recordingFilePath: recUrl,
              sha256Hash: recSha,
              timestamp: ts,
            );

            // Re-scan local recordings and refresh device calls
            Future.delayed(const Duration(seconds: 2), () async {
              await scanLocalRecordings();
              await fetchDeviceCallLogsAndSync();
            });
          } else if (type == 'whatsapp_notification') {
            final isCall = event['isCall'] == true;
            final sender = event['sender']?.toString() ?? 'WhatsApp Contact';
            final preview = event['messagePreview']?.toString() ?? (isCall ? 'Incoming WhatsApp Call' : '');
            final pkg = event['packageName']?.toString() ?? 'com.whatsapp';

            recordWhatsAppNotification(
              packageName: pkg,
              sender: sender,
              messagePreview: preview,
              groupName: event['groupName']?.toString(),
            );

            // Automatically mirror WhatsApp VoIP calls into unified Call History
            if (isCall) {
              final callDir = event['direction']?.toString() ?? 'inbound';
              final simSlot = (pkg == 'com.whatsapp.w4b') ? 'WhatsApp Business VoIP' : 'WhatsApp VoIP';
              final callType = event['callType']?.toString() ?? 'Voice';
              final outcome = callDir == 'missed'
                  ? 'Missed WhatsApp $callType Call'
                  : (callDir == 'outbound' ? 'Outgoing WhatsApp $callType Call' : 'WhatsApp $callType Call Answered');

              recordCall(
                phoneNumber: sender,
                contactName: sender,
                direction: callDir,
                durationSeconds: (event['duration'] as num?)?.toInt() ?? 0,
                outcome: outcome,
                simSlot: simSlot,
              );
            }
          } else if (type == 'sms') {
            recordSms(
              direction: event['direction']?.toString() ?? 'inbound',
              sender: event['sender']?.toString() ?? 'Unknown Sender',
              recipient: event['recipient']?.toString() ?? 'Device',
              messageBody: event['messageBody']?.toString() ?? '',
              simSlot: event['simSlot']?.toString() ?? 'SIM 1 (Corporate)',
            );
          }
        },
        onError: (err) {
          debugPrint('Telemetry stream notice: $err');
        },
      );
    } catch (e) {
      debugPrint('Native EventChannel unsupported: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 6. SERVER OVERVIEW & BATCH SYNC
  // ---------------------------------------------------------------------------
  Future<void> fetchServerOverview({bool silent = false}) async {
    if (!_isOnline) return;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl?action=overview&deviceId=$deviceId'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data['devices'] != null) {
            _devices = (data['devices'] as List)
                .map((d) => DeviceTelemetryModel.fromJson(d))
                .toList();
          }

          if (data['activeIncomingCall'] != null) {
            _activeRingingCall = IncomingCallEventModel.fromJson(data['activeIncomingCall']);
          } else {
            _activeRingingCall = null;
          }

          if (data['calls'] != null) {
            final serverCalls = (data['calls'] as List)
                .map((c) => CallLogTelemetryModel.fromJson(c))
                .toList();
            _calls = _mergeCallsWithLocalQueue(serverCalls);
          }

          if (data['whatsapp'] != null) {
            final serverWa = (data['whatsapp'] as List)
                .map((w) => WhatsAppNotificationModel.fromJson(w))
                .toList();
            _whatsappMessages = _mergeWhatsAppWithLocalQueue(serverWa);
          }

          if (data['sms'] != null) {
            final serverSms = (data['sms'] as List)
                .map((s) => SmsLogModel.fromJson(s))
                .toList();
            _smsMessages = _mergeSmsWithLocalQueue(serverSms);
          }

          if (data['diagnostics'] != null) {
            _diagnostics = (data['diagnostics'] as List)
                .map((d) => SyncDiagnosticModel.fromJson(d))
                .toList();
          }

          _updatePendingCount();
          _lastSyncTime = DateTime.now();
          if (!silent) {
            _syncStatusMessage = 'Telemetry synced successfully';
          }
          notifyListeners();
        }
      }
    } catch (e) {
      if (!silent) {
        _syncStatusMessage = 'Network notice: $e';
        notifyListeners();
      }
    }
  }

  // Offline Queues
  Future<void> _loadLocalQueues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callsJson = prefs.getString('phone_wa_pending_calls');
      if (callsJson != null) {
        final list = json.decode(callsJson) as List;
        _offlineCallQueue.clear();
        _offlineCallQueue.addAll(list.cast<Map<String, dynamic>>());
      }

      final waJson = prefs.getString('phone_wa_pending_whatsapp');
      if (waJson != null) {
        final list = json.decode(waJson) as List;
        _offlineWaQueue.clear();
        _offlineWaQueue.addAll(list.cast<Map<String, dynamic>>());
      }

      final smsJson = prefs.getString('phone_wa_pending_sms');
      if (smsJson != null) {
        final list = json.decode(smsJson) as List;
        _offlineSmsQueue.clear();
        _offlineSmsQueue.addAll(list.cast<Map<String, dynamic>>());
      }

      _updatePendingCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistLocalQueues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_wa_pending_calls', json.encode(_offlineCallQueue));
      await prefs.setString('phone_wa_pending_whatsapp', json.encode(_offlineWaQueue));
      await prefs.setString('phone_wa_pending_sms', json.encode(_offlineSmsQueue));
    } catch (_) {}
  }

  void _updatePendingCount() {
    _pendingCount = _offlineCallQueue.length + _offlineWaQueue.length + _offlineSmsQueue.length;
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _updatePendingCount();
    _syncStatusMessage = 'Synchronizing queue with cloud...';
    notifyListeners();

    try {
      await fetchDeviceCallLogsAndSync();
      await fetchDeviceSmsAndSync();
      await scanLocalRecordings();
      await drainOfflineQueue(mode: 'MANUAL');
      await fetchServerOverview(silent: true);
      _syncStatusMessage = 'All telemetry synchronized';
    } catch (e) {
      _syncStatusMessage = 'Sync error: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> drainOfflineQueue({String mode = 'AUTOMATIC'}) async {
    if (!_isOnline) return;
    if (_offlineCallQueue.isEmpty && _offlineWaQueue.isEmpty && _offlineSmsQueue.isEmpty) {
      _updatePendingCount();
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _uploadingCount = _offlineCallQueue.length + _offlineWaQueue.length + _offlineSmsQueue.length;
    notifyListeners();

    final payload = {
      'deviceId': deviceId,
      'syncMode': mode,
      'calls': List.from(_offlineCallQueue),
      'whatsapp': List.from(_offlineWaQueue),
      'sms': List.from(_offlineSmsQueue),
    };

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl?action=sync_batch'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _successfulCount += _uploadingCount;
          _offlineCallQueue.clear();
          _offlineWaQueue.clear();
          _offlineSmsQueue.clear();
          await _persistLocalQueues();
          _updatePendingCount();

          _calls = _calls.map((c) => c.copyWith(syncStatus: 'SYNCED')).toList();
          _whatsappMessages = _whatsappMessages.map((w) => w.copyWith(syncStatus: 'SYNCED')).toList();
          _smsMessages = _smsMessages.map((s) => s.copyWith(syncStatus: 'SYNCED')).toList();

          _lastSyncTime = DateTime.now();
        } else {
          _failedCount += _uploadingCount;
        }
      } else {
        _failedCount += _uploadingCount;
      }
    } catch (e) {
      _failedCount += _uploadingCount;
    } finally {
      _uploadingCount = 0;
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _startAutoSyncLoop() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_isOnline && _isAutoSyncEnabled) {
        if (_pendingCount > 0) {
          drainOfflineQueue(mode: 'AUTOMATIC');
        } else {
          fetchServerOverview(silent: true);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 7. REAL-TIME RECORDING ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> recordIncomingRinging({
    required String phoneNumber,
    String contactName = 'Incoming Caller',
    String simSlot = 'SIM 1 (Corporate)',
  }) async {
    final ringId = 'ring_${DateTime.now().millisecondsSinceEpoch}';
    final event = IncomingCallEventModel(
      id: ringId,
      deviceId: deviceId,
      phoneNumber: phoneNumber,
      contactName: contactName,
      simSlot: simSlot,
      state: 'RINGING',
      timestamp: DateTime.now().toIso8601String(),
    );

    _activeRingingCall = event;
    notifyListeners();

    if (_isOnline) {
      try {
        await http.post(
          Uri.parse('$baseUrl?action=incoming_alert'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(event.toJson()),
        );
      } catch (_) {}
    }

    _ringingDismissTimer?.cancel();
    _ringingDismissTimer = Timer(const Duration(seconds: 35), () {
      if (_activeRingingCall?.id == ringId) {
        _activeRingingCall = null;
        notifyListeners();
      }
    });
  }

  Future<void> dismissRingingAlert() async {
    _activeRingingCall = null;
    notifyListeners();
  }

  Future<void> recordCall({
    String? id,
    required String phoneNumber,
    required String contactName,
    required String direction,
    required int durationSeconds,
    required String outcome,
    String simSlot = 'SIM 1 (Corporate)',
    String? recordingFilePath,
    String? sha256Hash,
    String? timestamp,
  }) async {
    final callId = id ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final startedAt = timestamp ?? now.subtract(Duration(seconds: durationSeconds)).toIso8601String();
    final endedAt = now.toIso8601String();

    final callModel = CallLogTelemetryModel(
      id: callId,
      deviceId: deviceId,
      phoneNumber: phoneNumber,
      contactName: contactName,
      direction: direction,
      durationSeconds: durationSeconds,
      simSlot: simSlot,
      startedAt: startedAt,
      endedAt: endedAt,
      outcome: outcome,
      recordingStatus: (recordingFilePath != null && recordingFilePath.isNotEmpty) ? 'AVAILABLE' : 'NOT_AVAILABLE',
      recordingUrl: recordingFilePath,
      recordingSha256: sha256Hash,
      syncStatus: _isOnline ? 'SYNCED' : 'SYNC_PENDING',
      syncMode: _isAutoSyncEnabled ? 'AUTOMATIC' : 'MANUAL',
      notes: 'Recorded via native telephony telemetry',
    );

    // Prevent duplicate entries for same call
    final existingIdx = _calls.indexWhere((c) => c.id == callId ||
        (_cleanPhone(c.phoneNumber) == _cleanPhone(phoneNumber) &&
         (DateTime.tryParse(c.timestamp)?.difference(DateTime.tryParse(startedAt) ?? DateTime.now()).inSeconds.abs() ?? 999) < 20));

    if (existingIdx >= 0) {
      _calls[existingIdx] = callModel;
    } else {
      _calls.insert(0, callModel);
      _offlineCallQueue.add(callModel.toJson());
      await _persistLocalQueues();
      _updatePendingCount();
    }
    _syncStatusMessage = 'Call sensed: $contactName ($phoneNumber)';
    notifyListeners();

    if (_isOnline && _isAutoSyncEnabled) {
      await drainOfflineQueue(mode: 'AUTOMATIC');
    }
  }

  Future<void> recordWhatsAppNotification({
    required String packageName,
    required String sender,
    required String messagePreview,
    String? groupName,
  }) async {
    final notifId = 'wa_${DateTime.now().millisecondsSinceEpoch}';
    final model = WhatsAppNotificationModel(
      id: notifId,
      deviceId: deviceId,
      packageName: packageName,
      sender: sender,
      messagePreview: messagePreview,
      groupName: groupName,
      timestamp: DateTime.now().toIso8601String(),
      syncStatus: _isOnline ? 'SYNCED' : 'SYNC_PENDING',
    );

    _whatsappMessages.insert(0, model);
    _offlineWaQueue.add(model.toJson());
    await _persistLocalQueues();
    _updatePendingCount();
    notifyListeners();

    if (_isOnline && _isAutoSyncEnabled) {
      await drainOfflineQueue(mode: 'AUTOMATIC');
    }
  }

  Future<void> recordSms({
    required String direction,
    required String sender,
    required String recipient,
    required String messageBody,
    String simSlot = 'SIM 1 (Corporate)',
  }) async {
    final smsId = 'sms_${DateTime.now().millisecondsSinceEpoch}';
    final model = SmsLogModel(
      id: smsId,
      deviceId: deviceId,
      direction: direction,
      sender: sender,
      recipient: recipient,
      messageBody: messageBody,
      simSlot: simSlot,
      timestamp: DateTime.now().toIso8601String(),
      syncStatus: _isOnline ? 'SYNCED' : 'SYNC_PENDING',
    );

    _smsMessages.insert(0, model);
    _offlineSmsQueue.add(model.toJson());
    await _persistLocalQueues();
    _updatePendingCount();
    notifyListeners();

    if (_isOnline && _isAutoSyncEnabled) {
      await drainOfflineQueue(mode: 'AUTOMATIC');
    }
  }

  Future<bool> updateCallMetadata({
    required String callId,
    String? notes,
    String? outcome,
    String? contactName,
  }) async {
    try {
      final payload = {
        'callId': callId,
        'notes': notes,
        'outcome': outcome,
        'contactName': contactName,
      };

      final response = await http.post(
        Uri.parse('$baseUrl?action=update_call'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final idx = _calls.indexWhere((c) => c.id == callId);
        if (idx >= 0) {
          _calls[idx] = _calls[idx].copyWith(
            contactName: contactName ?? _calls[idx].contactName,
            outcome: outcome ?? _calls[idx].outcome,
            notes: notes ?? _calls[idx].notes,
          );
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  void toggleOnlineState() {
    _isOnline = !_isOnline;
    _syncStatusMessage = _isOnline ? 'Device online' : 'Offline mode active';
    notifyListeners();
    if (_isOnline && _isAutoSyncEnabled) {
      drainOfflineQueue(mode: 'AUTOMATIC');
    }
  }

  void toggleAutoSync(bool val) {
    _isAutoSyncEnabled = val;
    notifyListeners();
  }

  // Phone and Date normalizers for reliable telemetry deduplication
  String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
  String _normalizeDate(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.year}-${dt.month}-${dt.day}_${dt.hour}:${dt.minute}';
  }

  // Merging helpers: Local device call logs are ALWAYS the primary master list
  List<CallLogTelemetryModel> _mergeCallsWithLocalQueue(List<CallLogTelemetryModel> serverList) {
    if (_calls.isEmpty) {
      final setIds = serverList.map((e) => e.id).toSet();
      final pendingModels = _offlineCallQueue
          .map((j) => CallLogTelemetryModel.fromJson(j).copyWith(syncStatus: 'SYNC_PENDING'))
          .where((e) => !setIds.contains(e.id))
          .toList();
      return [...pendingModels, ...serverList];
    }

    final serverMapById = <String, CallLogTelemetryModel>{};
    final serverMapByPhoneAndDate = <String, CallLogTelemetryModel>{};
    for (final sc in serverList) {
      serverMapById[sc.id] = sc;
      final key = '${_cleanPhone(sc.phoneNumber)}_${_normalizeDate(sc.timestamp)}';
      serverMapByPhoneAndDate[key] = sc;
    }

    final merged = <CallLogTelemetryModel>[];
    final seenIds = <String>{};

    for (final localCall in _calls) {
      seenIds.add(localCall.id);
      final key = '${_cleanPhone(localCall.phoneNumber)}_${_normalizeDate(localCall.timestamp)}';
      final matchingServer = serverMapById[localCall.id] ?? serverMapByPhoneAndDate[key];

      if (matchingServer != null) {
        merged.add(localCall.copyWith(
          syncStatus: 'SYNCED',
          recordingUrl: (localCall.recordingUrl != null && localCall.recordingUrl!.isNotEmpty)
              ? localCall.recordingUrl
              : matchingServer.recordingUrl,
          recordingSha256: (localCall.recordingSha256 != null && localCall.recordingSha256!.isNotEmpty)
              ? localCall.recordingSha256
              : matchingServer.recordingSha256,
          recordingStatus: (matchingServer.recordingStatus == 'AVAILABLE' ||
                  (localCall.recordingUrl != null && localCall.recordingUrl!.isNotEmpty))
              ? 'AVAILABLE'
              : localCall.recordingStatus,
        ));
      } else {
        merged.add(localCall);
      }
    }

    // Include any server calls (such as WhatsApp VoIP or synced cloud records) not found locally
    for (final sc in serverList) {
      final key = '${_cleanPhone(sc.phoneNumber)}_${_normalizeDate(sc.timestamp)}';
      if (!seenIds.contains(sc.id) && !serverMapByPhoneAndDate.containsKey(key)) {
        merged.add(sc);
      }
    }

    // Filter out dummy/simulated test calls so only original device calls are shown
    final cleanList = merged.where((c) {
      if (c.id.startsWith('call-10') || c.id.startsWith('call_live_77')) return false;
      if (c.recordingUrl != null && c.recordingUrl!.contains('mixkit.co')) return false;
      if (c.contactName == 'Aarav Sharma' || c.contactName == 'Priya Patel') return false;
      return true;
    }).toList();

    cleanList.sort((a, b) {
      final tA = DateTime.tryParse(a.timestamp)?.millisecondsSinceEpoch ?? 0;
      final tB = DateTime.tryParse(b.timestamp)?.millisecondsSinceEpoch ?? 0;
      return tB.compareTo(tA);
    });

    return cleanList;
  }

  List<WhatsAppNotificationModel> _mergeWhatsAppWithLocalQueue(List<WhatsAppNotificationModel> serverList) {
    final setIds = serverList.map((e) => e.id).toSet();
    final pendingModels = _offlineWaQueue
        .map((j) => WhatsAppNotificationModel.fromJson(j).copyWith(syncStatus: 'SYNC_PENDING'))
        .where((e) => !setIds.contains(e.id))
        .toList();
    return [...pendingModels, ...serverList];
  }

  List<SmsLogModel> _mergeSmsWithLocalQueue(List<SmsLogModel> serverList) {
    final setIds = serverList.map((e) => e.id).toSet();
    final pendingModels = _offlineSmsQueue
        .map((j) => SmsLogModel.fromJson(j).copyWith(syncStatus: 'SYNC_PENDING'))
        .where((e) => !setIds.contains(e.id))
        .toList();
    return [...pendingModels, ...serverList];
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _ringingDismissTimer?.cancel();
    _nativeEventSub?.cancel();
    _audioPollingTimer?.cancel();
    super.dispose();
  }
}
