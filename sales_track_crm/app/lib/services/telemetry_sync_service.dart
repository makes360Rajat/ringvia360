import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_track_models.dart';
import 'sales_track_api_service.dart';
import 'local_database_service.dart';
import '../main.dart';

class TelemetrySyncService extends ChangeNotifier {
  static const MethodChannel _platform = MethodChannel('com.CallVia360.app/platform');
  static const EventChannel _telemetryChannel = EventChannel('com.CallVia360.app/telemetry_stream');

  final SalesTrackApiService api = SalesTrackApiService();

  // Pairing & CRM Meta
  CrmDevice? _device;
  CrmStaff? _staff;
  SalesTrackConfig _config = SalesTrackConfig.defaultConfig();
  bool _isPaired = false;
  bool _isInitialized = false;
  bool _isSyncing = false;
  String _statusMessage = 'Initializing local storage...';
  DateTime? _lastSyncTime;

  // Progressive Initialization State
  double _initProgress = 0.05;
  String _initStatusMessage = 'Starting CallVia360...';

  double get initProgress => _initProgress;
  String get initStatusMessage => _initStatusMessage;

  // Real-time Sync Progress & Granular Counts
  double _syncProgress = 0.0;
  String _syncProgressMessage = '';
  int _pendingCallsCount = 0;
  int _pendingSmsCount = 0;
  int _pendingWhatsAppCount = 0;
  int _pendingRecordingsCount = 0;

  double get syncProgress => _syncProgress;
  String get syncProgressMessage => _syncProgressMessage;
  int get pendingCallsCount => _pendingCallsCount;
  int get pendingSmsCount => _pendingSmsCount;
  int get pendingWhatsAppCount => _pendingWhatsAppCount;
  int get pendingRecordingsCount => _pendingRecordingsCount;
  int get pendingEventsCount => _pendingCallsCount + _pendingSmsCount + _pendingWhatsAppCount;

  CrmDevice? get device => _device;
  CrmStaff? get staff => _staff;
  SalesTrackConfig get config => _config;
  bool get isPaired => _isPaired;
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  String get statusMessage => _statusMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Device Info & Health
  Map<String, dynamic> _deviceInfo = {};
  Map<String, bool> _permissions = {
    'call_log': false,
    'phone_state': false,
    'contacts': false,
    'sms': false,
    'storage': false,
    'notifications': false,
    'recordings': false,
    'battery_unrestricted': false,
  };
  int _batteryPercent = 85;

  Map<String, dynamic> get deviceInfo => _deviceInfo;
  Map<String, bool> get permissions => _permissions;
  int get batteryPercent => _batteryPercent;

  bool get hasCallLogPermission => Platform.isIOS ? true : (_permissions['call_log'] == true);
  bool get hasPhoneStatePermission => Platform.isIOS ? true : (_permissions['phone_state'] == true);
  bool get hasSmsPermission => Platform.isIOS ? true : (_permissions['sms'] == true);
  bool get hasContactsPermission => _permissions['contacts'] == true;
  bool get hasWhatsAppAccessPermission => Platform.isIOS ? true : (_permissions['whatsapp_access'] == true || _permissions['notifications'] == true);
  bool get hasNotificationPermission => Platform.isIOS ? (_permissions['notifications'] == true) : hasWhatsAppAccessPermission;
  bool get hasRecordingsFolderPermission => Platform.isIOS ? true : (_permissions['recordings_folder'] == true || _permissions['manage_storage'] == true);
  bool get hasStoragePermission => Platform.isIOS ? true : (_permissions['storage'] == true || hasRecordingsFolderPermission || _permissions['recordings'] == true);
  bool get hasBatteryOptimizationExemption => Platform.isIOS ? true : (_permissions['battery_unrestricted'] == true);
  bool get hasOverlayPermission => Platform.isIOS ? true : (_permissions['overlay'] == true);
  bool get hasEssentialPermissions {
    if (Platform.isIOS) {
      return true;
    }
    return hasCallLogPermission && hasPhoneStatePermission;
  }

  bool get hasAllSevenPermissions {
    if (Platform.isIOS) {
      return hasContactsPermission;
    }
    return hasCallLogPermission &&
        hasPhoneStatePermission &&
        hasContactsPermission &&
        hasSmsPermission &&
        hasWhatsAppAccessPermission &&
        hasRecordingsFolderPermission &&
        hasBatteryOptimizationExemption;
  }

  List<String> get missingPermissionNames {
    final list = <String>[];
    if (Platform.isIOS) {
      if (!hasContactsPermission) list.add('Contacts');
      if (!hasNotificationPermission) list.add('Notifications');
      return list;
    }
    if (!hasCallLogPermission) list.add('Call Log');
    if (!hasPhoneStatePermission) list.add('Phone State');
    if (!hasContactsPermission) list.add('Contacts');
    if (!hasSmsPermission) list.add('SMS');
    if (!hasWhatsAppAccessPermission) list.add('WhatsApp Call Access');
    if (!hasRecordingsFolderPermission) list.add('Recordings Folder');
    if (!hasBatteryOptimizationExemption) list.add('Battery Unrestricted');
    if (!hasOverlayPermission) list.add('Display Over Apps');
    return list;
  }

  // Data Stores (Local-First in Memory & SharedPreferences)
  final List<SalesTrackEvent> _calls = [];
  final List<SalesTrackEvent> _whatsappEvents = [];
  final List<SalesTrackEvent> _smsList = [];
  final List<Map<String, dynamic>> _localRecordings = [];
  final List<CallListModel> _callLists = [];
  final List<OutcomeSubmission> _pendingOutcomes = [];
  String? _pendingAfterCallNumber;

  List<SalesTrackEvent> get calls => List.unmodifiable(_calls);
  List<SalesTrackEvent> get whatsappEvents => List.unmodifiable(_whatsappEvents);
  List<SalesTrackEvent> get smsList => List.unmodifiable(_smsList);
  List<Map<String, dynamic>> get localRecordings => List.unmodifiable(_localRecordings);
  List<CallListModel> get callLists => List.unmodifiable(_callLists);
  List<OutcomeSubmission> get pendingOutcomes => List.unmodifiable(_pendingOutcomes);

  // Sync Queue (Offline persistent queue)
  final List<SalesTrackEvent> _pendingQueue = [];
  final Set<String> _pendingUids = {};
  bool _syncPendingAgain = false;
  List<SalesTrackEvent> get pendingQueue => List.unmodifiable(_pendingQueue);
  int get pendingQueueCount => _pendingQueue.length;

  // Truecaller-like Active Caller ID State
  CallerIdInfo? _activeCallerId;
  CallerIdInfo? get activeCallerId => _activeCallerId;

  void dismissCallerId() {
    _activeCallerId = null;
    notifyListeners();
  }

  // App Version Update State
  AppUpdateInfo? _availableUpdate;
  bool _isUpdateMandatory = false;

  AppUpdateInfo? get availableUpdate => _availableUpdate;
  bool get isUpdateMandatory => _isUpdateMandatory;

  void dismissOptionalUpdate() {
    if (!_isUpdateMandatory) {
      _availableUpdate = null;
      notifyListeners();
    }
  }

  Future<AppUpdateInfo?> checkForAppUpdate({bool manual = false}) async {
    try {
      final res = await api.fetchAppUpdate();
      if (res.success && res.data != null && res.data!.isNotEmpty) {
        final info = res.data!;
        final current = SalesTrackApiService.currentAppVersion;
        final isBelowMin = info.minVersion.isNotEmpty &&
            compareAppVersions(current, info.minVersion) < 0;
        final isBelowLatest = info.latestVersion.isNotEmpty &&
            compareAppVersions(current, info.latestVersion) < 0;

        if (isBelowMin) {
          _availableUpdate = info;
          _isUpdateMandatory = true;
          notifyListeners();
          return info;
        } else if (isBelowLatest) {
          _availableUpdate = info;
          _isUpdateMandatory = false;
          notifyListeners();
          return info;
        }
      }
      if (manual) {
        _statusMessage = 'App is up to date (v${SalesTrackApiService.currentAppVersion})';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
    return null;
  }

  Future<void> launchAppUpdateUrl([String? url]) async {
    final target = (url != null && url.isNotEmpty)
        ? url
        : (_availableUpdate?.urlAndroid.isNotEmpty == true
            ? _availableUpdate!.urlAndroid
            : 'https://play.google.com/store/apps/details?id=com.CallVia360.app');
    try {
      await _platform.invokeMethod('launchUrl', {'url': target});
    } catch (e) {
      debugPrint('Error launching update URL: $e');
    }
  }

  Future<CallerIdInfo?> lookupCallerInfo(String phone) async {
    try {
      final localInfo = await LocalDatabaseService.instance.lookupCallerInfo(phone);
      if (localInfo != null) {
        return CallerIdInfo(
          phoneNumber: phone,
          name: localInfo['resolvedName']?.toString() ?? phone,
          totalPreviousCalls: (localInfo['totalCalls'] as int?) ?? 0,
          lastCallTime: localInfo['lastCallTime'],
          lastDuration: localInfo['lastDuration'],
          lastOutcome: localInfo['lastOutcome']?.toString(),
          lastNote: localInfo['lastNote']?.toString(),
          followUpAt: localInfo['followUpAt'],
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> openWhatsAppChat(String number, [String? name]) async {
    try {
      await _platform.invokeMethod('launchWhatsAppChat', {'number': number, 'name': name ?? ''});
    } catch (_) {}
  }

  Future<void> dialPhoneNumber(String number, [String? name]) async {
    try {
      await _platform.invokeMethod('dialPhoneNumber', {'number': number, 'name': name ?? ''});
    } catch (_) {}
  }

  Future<bool> sendSms({required String number, String text = '', String? name}) async {
    try {
      final res = await _platform.invokeMethod('sendSms', {
        'number': number,
        'text': text,
        'name': name ?? '',
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> getContactPhotoBytes({String? photoUri, String? phoneNumber}) async {
    try {
      final res = await _platform.invokeMethod('getContactPhoto', {
        'photoUri': photoUri,
        'phoneNumber': phoneNumber,
      });
      if (res is Uint8List) return res;
      if (res is List) return Uint8List.fromList(res.cast<int>());
      return null;
    } catch (_) {
      return null;
    }
  }

  // After-call popup trigger
  SalesTrackEvent? _activeAfterCallEvent;
  SalesTrackEvent? get activeAfterCallEvent => _activeAfterCallEvent;

  // Native Audio Player State
  bool _isPlayingAudio = false;
  String? _activeAudioPath;
  int _audioCurrentPosMs = 0;
  int _audioDurationMs = 0;
  Timer? _audioPollTimer;

  bool get isPlayingAudio => _isPlayingAudio;
  String? get activeAudioPath => _activeAudioPath;
  int get audioCurrentPosMs => _audioCurrentPosMs;
  int get audioDurationMs => _audioDurationMs;

  StreamSubscription? _eventSubscription;
  Timer? _heartbeatTimer;
  Timer? _iosLivePollingTimer;

  TelemetrySyncService() {
    // The CRM revoked or deleted this phone: stop and ask for a new pairing.
    api.onPairingLost = (reason) {
      _handlePairingLost(reason);
    };
    _init();
  }

  void _updateInitProgress(double progress, String message) {
    _initProgress = progress;
    _initStatusMessage = message;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      _updateInitProgress(0.10, 'Connecting to local storage & credentials...');

      await api.init();
      _isPaired = api.isPaired;

      api.onUpdateRequired = (info, isMandatory) {
        _availableUpdate = info;
        _isUpdateMandatory = isMandatory;
        notifyListeners();
      };

      checkForAppUpdate();

      _updateInitProgress(0.25, 'Loading saved settings & telemetry state...');
      await _loadSavedMeta();
      _listenToNativeEvents();

      _updateInitProgress(0.38, 'Verifying telephony & system permissions...');
      await checkPermissions();

      _updateInitProgress(0.48, 'Loading local conversation history...');
      // Load local database history with real-time granular progress
      await _loadPersistedHistory();

      _updateInitProgress(0.90, 'Checking pending synchronization queue...');
      await refreshPendingCounts();

      _updateInitProgress(0.97, 'Preparing CRM workspace...');

      if (Platform.isIOS) {
        _iosLivePollingTimer?.cancel();
        _iosLivePollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
          if (!_foreground) return;
          try {
            await syncActiveWhatsAppNotifications();
            await syncDeviceSms();
          } catch (_) {}
        });
      }

      await Future.delayed(const Duration(milliseconds: 180));
      _updateInitProgress(1.0, 'Ready');
    } catch (e, st) {
      debugPrint('Error during TelemetrySyncService init: $e\n$st');
    } finally {
      _isInitialized = true;
      notifyListeners();

      // Run heavy background synchronization asynchronously so UI opens instantaneously!
      Future.microtask(() async {
        try {
          if (hasCallLogPermission) await syncDeviceCallLogs();
          if (hasSmsPermission) await syncDeviceSms();
          await scanLocalRecordings();
          await syncActiveWhatsAppNotifications();
          await refreshPendingCounts();

          if (_isPaired) {
            await fetchPlatformDeviceInfo();
            await sendHeartbeat();
            _startHeartbeatLoop();
            await syncServerEvents();
            await fetchCallLists();
            // Automatically push complete call history and all pending items to the server
            await syncAllCallHistoryToServer();
            await syncNow();
          } else {
            _statusMessage = 'Enter 6-digit pairing code to connect';
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Background init sync error: $e');
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 1. HARDWARE & PERMISSIONS
  // ---------------------------------------------------------------------------
  Future<void> fetchPlatformDeviceInfo() async {
    try {
      final dynamic raw = await _platform.invokeMethod('getDeviceInfo');
      if (raw is Map) {
        final Map<String, dynamic> info = {};
        raw.forEach((key, val) {
          if (key != null) {
            info[key.toString()] = val;
          }
        });
        _deviceInfo = info;
        _batteryPercent = (info['batteryPercent'] as num?)?.toInt() ?? 85;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
  }

  Future<void> checkPermissions() async {
    try {
      final dynamic raw = await _platform.invokeMethod('getPermissionsStatus');
      if (raw is Map) {
        final Map<String, bool> updated = {};
        raw.forEach((key, val) {
          if (key != null) {
            updated[key.toString()] = val == true;
          }
        });
        _permissions = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> requestAllPermissions() async {
    try {
      await _platform.invokeMethod('requestAllPermissions');
      await Future.delayed(const Duration(milliseconds: 400));
      await checkPermissions();
      if (hasCallLogPermission) {
        await syncDeviceCallLogs();
      }
      if (hasSmsPermission) {
        await syncDeviceSms();
      }
      await syncActiveWhatsAppNotifications();
      await scanLocalRecordings();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  Future<void> requestPermission(String permissionGroup) async {
    try {
      await _platform.invokeMethod('requestPermission', {'permission': permissionGroup});
      await Future.delayed(const Duration(milliseconds: 400));
      await checkPermissions();
      if (hasCallLogPermission) {
        await syncDeviceCallLogs();
      }
      if (hasSmsPermission) {
        await syncDeviceSms();
      }
      await syncActiveWhatsAppNotifications();
      await scanLocalRecordings();
    } catch (e) {
      debugPrint('Error requesting permission $permissionGroup: $e');
      await requestAllPermissions();
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _platform.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  Future<void> openBatterySettings() async {
    try {
      await _platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  Future<void> openAllFilesSettings() async {
    try {
      await _platform.invokeMethod('openAllFilesSettings');
    } catch (_) {}
  }

  Future<void> openOverlaySettings() async {
    try {
      await _platform.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  Future<void> openAppSettings() async {
    try {
      await _platform.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 2. PAIRING & CONFIG
  // ---------------------------------------------------------------------------
  Future<SalesTrackApiResponse<Map<String, dynamic>>> pairWithCode({
    required String serverUrl,
    required String code,
  }) async {
    _statusMessage = 'Connecting to CRM...';
    notifyListeners();

    await fetchPlatformDeviceInfo();
    if (_deviceInfo.isEmpty || _deviceInfo['uid'] == null || (_deviceInfo['uid'] as String).isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      var uid = prefs.getString('mks_device_uid');
      if (uid == null || uid.isEmpty) {
        uid = 'dev-${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('mks_device_uid', uid);
      }
      _deviceInfo = {
        'uid': uid,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'manufacturer': 'Android',
        'model': 'Device',
        'os_version': '14',
        'app_version': '1.9.7',
      };
    }

    final res = await api.pair(
      serverUrl: serverUrl,
      code: code,
      deviceInfo: _deviceInfo,
    );

    if (res.success && res.data != null) {
      _isPaired = true;
      _pairingLostMessage = null;
      final d = res.data!['device'];
      final s = res.data!['staff'];
      final c = res.data!['config'];

      // The phone is paired once the token is saved: nothing read below may
      // turn that into a failure on screen.
      try {
        if (d is Map<String, dynamic>) _device = CrmDevice.fromJson(d);
        if (s is Map<String, dynamic>) _staff = CrmStaff.fromJson(s);
        if (c is Map<String, dynamic>) _config = SalesTrackConfig.fromJson(c);
      } catch (e) {
        debugPrint('Paired, but the CRM settings could not be read yet: $e');
      }

      await _persistMeta();
      await sendHeartbeat();
      _startHeartbeatLoop();
      _statusMessage = 'Paired with ${_device?.name ?? "CRM"}';
      notifyListeners();

      // Reading the call log, SMS and recordings and sending them can take
      // minutes on a busy phone: it runs in the background, so the pairing
      // screen finishes at once and the code is never left half used.
      unawaited(_firstImport());
      return res;
    } else {
      _statusMessage = res.message ?? 'Pairing failed';
    }

    notifyListeners();
    return res;
  }

  Future<void> _firstImport() async {
    try {
      await LocalDatabaseService.instance.resetAllToPending();
      for (final c in _calls) {
        c.syncStatus = 'pending';
      }
      for (final s in _smsList) {
        s.syncStatus = 'pending';
      }
      for (final w in _whatsappEvents) {
        w.syncStatus = 'pending';
      }
    } catch (_) {}

    final steps = <Future<void> Function()>[
      syncDeviceCallLogs,
      syncDeviceSms,
      syncActiveWhatsAppNotifications,
      scanLocalRecordings,
      fetchCallLists,
      syncNow
    ];
    for (final step in steps) {
      try {
        await step();
      } catch (e) {
        debugPrint('First import step failed: $e');
      }
    }
    notifyListeners();
  }

  // Why the phone was unpaired by the CRM, for the pairing screen.
  String? _pairingLostMessage;
  String? get pairingLostMessage => _pairingLostMessage;

  /// The CRM revoked or deleted this phone (or it was paired again on
  /// another phone): stop all syncing, forget the pairing and everything
  /// waiting to be sent, and go back to the pairing screen for a new code.
  /// Only the CRM's own answer that this phone is no longer paired unpairs it
  /// (revoked, deleted, paired again elsewhere). The app's local "not paired
  /// yet", a feature switched off in the CRM (403), an inactive staff account
  /// or a network error never does.
  static bool _isPairingLost(SalesTrackApiResponse res) =>
      res.statusCode == 401 && const {'device_revoked', 'invalid_token', 'device_mismatch'}.contains(res.error);

  static bool _isUpdateRequired(SalesTrackApiResponse res) =>
      res.statusCode == 426 || res.error == 'update_required';

  Future<void> _handlePairingLost(String reason) async {
    if (!_isPaired) return;
    _pairingLostMessage = (reason == 'device_revoked' || reason == 'staff_inactive')
        ? 'This phone was revoked in the CRM. Ask your administrator for a new pairing code.'
        : 'This phone is no longer registered in the CRM (deleted, or paired again elsewhere). Ask your administrator for a new pairing code.';
    _pendingQueue.clear();
    _pendingUids.clear();
    _calls.clear();
    _smsList.clear();
    _whatsappEvents.clear();
    try {
      await LocalDatabaseService.instance.clearAll();
      await _persistCalls();
      await _persistSms();
      await _persistWhatsApp();
      await _persistQueue();
    } catch (_) {}
    await unpair();
    try {
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    } catch (_) {}
    _statusMessage = _pairingLostMessage!;
    notifyListeners();
  }

  Future<void> unpair() async {
    _isPaired = false;
    _device = null;
    _staff = null;
    _heartbeatTimer?.cancel();
    _quickCheckTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _slowSensingTimer?.cancel();
    await api.clearCredentials();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mks_crm_device');
    await prefs.remove('mks_crm_staff');
    _statusMessage = 'Unpaired';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 3. REAL-TIME EVENT SENSING (Calls, SMS, WhatsApp)
  // ---------------------------------------------------------------------------
  void _listenToNativeEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _telemetryChannel.receiveBroadcastStream().listen(
      (dynamic rawEvent) {
        if (rawEvent is Map) {
          final eventMap = Map<String, dynamic>.from(rawEvent);
          _handleIncomingNativeEvent(eventMap);
        }
      },
      onError: (err) {
        debugPrint('Telemetry stream error: $err');
      },
    );
  }

  void _handleIncomingNativeEvent(Map<String, dynamic> raw) {
    final type = raw['type']?.toString();

    if (type == 'telemetry_refreshed') {
      if (Platform.isIOS) {
        syncActiveWhatsAppNotifications();
        syncDeviceSms();
        syncDeviceCallLogs();
      }
      return;
    }

    // Unpaired: calls, SMS and WhatsApp events are not kept or queued.
    if (!_isPaired && type != 'permissions_updated') return;

    // Permission state changed callback from native Android
    if (type == 'permissions_updated') {
      if (raw['permissions'] is Map) {
        final p = raw['permissions'] as Map;
        final Map<String, bool> updated = {};
        p.forEach((k, v) {
          if (k != null) updated[k.toString()] = v == true;
        });
        _permissions = updated;
      } else {
        checkPermissions();
      }
      if (hasCallLogPermission) {
        syncDeviceCallLogs();
      }
      if (hasSmsPermission) {
        syncDeviceSms();
      }
      scanLocalRecordings();
      notifyListeners();
      return;
    }

    // Truecaller-like real-time call detection (Incoming Ringing or Outgoing Dialing)
    if (type == 'incoming_call_ringing' || type == 'outgoing_call_dialing') {
      final phoneNumber = raw['phoneNumber']?.toString() ?? raw['number']?.toString() ?? '';
      final contactName = raw['contactName']?.toString() ?? raw['name']?.toString() ?? '';
      final photoUri = raw['photoUri']?.toString() ?? '';
      final direction = (raw['direction']?.toString() ?? (type == 'outgoing_call_dialing' ? 'outgoing' : 'incoming'));

      if (phoneNumber.isNotEmpty &&
          phoneNumber != 'Incoming Caller' &&
          phoneNumber.toLowerCase() != 'unknown') {
        _startCallerIdLookup(phoneNumber, contactName, direction, photoUri.isNotEmpty ? photoUri : null);
      }
      return;
    }

    if (type == 'open_after_call') {
      final number = raw['number']?.toString() ?? '';
      _pendingAfterCallNumber = number.isNotEmpty ? number : null;
      SalesTrackEvent? target;
      if (number.isNotEmpty) {
        final cleanKey = extractNumberKey(number);
        for (final c in _calls) {
          if (extractNumberKey(c.number) == cleanKey) {
            target = c;
            break;
          }
        }
      }
      target ??= _calls.isNotEmpty ? _calls.first : null;
      if (target != null) {
        _activeAfterCallEvent = target;
        notifyListeners();
      }
      return;
    }

    if (type == 'call_completed') {
      // Dismiss active ringing caller ID
      _activeCallerId = null;

      final uid = raw['uid']?.toString() ?? 'call-${DateTime.now().millisecondsSinceEpoch}';
      final event = SalesTrackEvent(
        uid: uid,
        kind: 'call',
        time: (raw['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        direction: raw['direction']?.toString() ?? 'incoming',
        number: raw['number']?.toString() ?? raw['phoneNumber']?.toString() ?? '',
        name: raw['name']?.toString() ?? raw['contactName']?.toString() ?? '',
        sim: (raw['sim'] as num?)?.toInt() ?? 1,
        duration: (raw['duration'] as num?)?.toInt() ?? 0,
        recording: raw['recording'] == true,
        recordingPath: raw['recordingPath']?.toString(),
        source: 'auto',
      );

      // Deduplicate: check if this call was already recorded
      final existingIndex = _calls.indexWhere((c) => isSameCall(c, event));
      bool shouldEnqueue = true;
      if (existingIndex >= 0) {
        final existing = _calls[existingIndex];
        if (existing.syncStatus == 'synced') event.syncStatus = 'synced';
        if (existing.recording && !event.recording) {
          event.recording = true;
          event.recordingPath = existing.recordingPath;
        }
        if (existing.duration > event.duration) {
          event.duration = existing.duration;
        }
        // If already synced and no richer duration or recording, avoid re-enqueueing
        if (existing.syncStatus == 'synced' && event.duration <= existing.duration && (!event.recording || existing.recording)) {
          shouldEnqueue = false;
        }
        _calls[existingIndex] = event;
      } else {
        _calls.insert(0, event);
      }
      final cleanCalls = dedupCallsList(_calls);
      _calls.clear();
      _calls.addAll(cleanCalls);

      // 1. SAVE TO LOCAL STORAGE FIRST (SQLite & SharedPreferences)
      LocalDatabaseService.instance.saveEvents([event]);
      _persistCalls();

      // 2. ENQUEUE FOR SYNC
      if (shouldEnqueue) {
        _enqueueEvent(event);
      }

      // Check if after-call outcome popup should be displayed
      if (_shouldShowAfterCallPopup(event)) {
        _activeAfterCallEvent = event;
      }
      notifyListeners();

      // 3. ATTEMPT SYNC
      syncNow();
    } else if (type == 'sms') {
      final uid = raw['uid']?.toString() ?? 'sms-${DateTime.now().millisecondsSinceEpoch}';
      final event = SalesTrackEvent(
        uid: uid,
        kind: 'sms',
        time: (raw['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        direction: raw['direction']?.toString() ?? 'incoming',
        number: raw['number']?.toString() ?? '',
        name: raw['name']?.toString() ?? '',
        sim: (raw['sim'] as num?)?.toInt() ?? 1,
        text: raw['text']?.toString() ?? '',
        source: 'auto',
      );

      final existingIndex = _smsList.indexWhere((s) => isSameSms(s, event));
      bool shouldEnqueue = true;
      if (existingIndex >= 0) {
        final existing = _smsList[existingIndex];
        event.uid = existing.uid; // Preserve original UID so CRM never creates a duplicate
        if (existing.syncStatus == 'synced') {
          event.syncStatus = 'synced';
          shouldEnqueue = false;
        }
        if (existing.name.isNotEmpty && event.name.isEmpty) event.name = existing.name;
        _smsList[existingIndex] = event;
      } else {
        _smsList.insert(0, event);
      }
      final cleanSms = dedupSmsList(_smsList);
      _smsList.clear();
      _smsList.addAll(cleanSms);

      LocalDatabaseService.instance.saveEvents([event]);
      _persistSms();
      if (shouldEnqueue) {
        _enqueueEvent(event);
      }
      notifyListeners();
      if (shouldEnqueue) {
        syncNow();
      }
    } else if (type == 'whatsapp_call' || type == 'whatsapp_call_completed') {
      final uid = raw['uid']?.toString() ?? 'wacall-${DateTime.now().millisecondsSinceEpoch}';
      final rawNumber = raw['number']?.toString() ?? '';
      final event = SalesTrackEvent(
        uid: uid,
        kind: 'whatsapp_call',
        time: (raw['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        direction: raw['direction']?.toString() ?? 'incoming',
        number: normalizeNumber(rawNumber),
        name: raw['name']?.toString() ?? 'WhatsApp Contact',
        duration: (raw['duration'] as num?)?.toInt() ?? 0,
        media: raw['media']?.toString() ?? 'voice',
        app: raw['packageName']?.toString() ?? 'com.whatsapp',
        source: 'auto',
      );

      final isFinalized = type == 'whatsapp_call_completed' || event.direction == 'missed' || event.duration > 0;
      event.syncStatus = isFinalized ? 'pending' : 'in_progress';

      final existingIndex = _whatsappEvents.indexWhere((w) => isSameWhatsApp(w, event));
      if (existingIndex >= 0) {
        final existing = _whatsappEvents[existingIndex];
        // Reuse existing UID to prevent creating a second phantom call in SQLite and CRM
        event.uid = existing.uid;
        if (existing.duration > event.duration) event.duration = existing.duration;
        if (existing.direction != 'unknown' && event.direction == 'incoming' && (existing.direction == 'outgoing' || existing.direction == 'missed')) {
          event.direction = existing.direction;
        }
        if (existing.time < event.time) event.time = existing.time;
        if (existing.syncStatus == 'synced' && event.duration == existing.duration) {
          event.syncStatus = 'synced';
        }
        _whatsappEvents[existingIndex] = event;
      } else {
        _whatsappEvents.insert(0, event);
      }
      final cleanWa = dedupWhatsAppList(_whatsappEvents);
      _whatsappEvents.clear();
      _whatsappEvents.addAll(cleanWa);

      LocalDatabaseService.instance.saveEvents([event]);
      LocalDatabaseService.instance.cleanupDuplicates();
      _persistWhatsApp();

      // Only enqueue and upload to CRM once finalized (completed with talk time, or missed call)
      // Never upload a ringing 0-duration call while ongoing, as that locks CRM records with duration '-'
      if (isFinalized) {
        _enqueueEvent(event);
        // Instant direct push to CRM server (< 300ms)! Completely bypasses recording upload queues
        _directSyncWhatsAppCall(event);
      }
      notifyListeners();
    } else if (type == 'whatsapp_message') {
      final text = raw['text']?.toString() ?? '';
      String name = raw['sender']?.toString() ?? raw['name']?.toString() ?? 'WhatsApp Contact';
      if (isMessageCountSummary(text) || isMessageCountSummary(name)) {
        return; // Drop message count summary notifications immediately
      }
      final uid = raw['uid']?.toString() ?? 'wamsg-${DateTime.now().millisecondsSinceEpoch}';
      String number = raw['number']?.toString() ?? '';
      if (number.isEmpty && RegExp(r'^\+?[0-9\s\-()]{7,}$').hasMatch(name)) {
        number = name;
      }
      number = normalizeNumber(number);
      final event = SalesTrackEvent(
        uid: uid,
        kind: 'whatsapp_message',
        time: (raw['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        direction: raw['direction']?.toString() ?? 'incoming',
        number: number,
        name: name,
        app: raw['packageName']?.toString() ?? 'com.whatsapp',
        text: text,
        source: 'auto',
      );

      final existingIndex = _whatsappEvents.indexWhere((w) => isSameWhatsApp(w, event));
      if (existingIndex >= 0) {
        final existing = _whatsappEvents[existingIndex];
        if (existing.syncStatus == 'synced') event.syncStatus = 'synced';
        _whatsappEvents[existingIndex] = event;
      } else {
        _whatsappEvents.insert(0, event);
      }
      final cleanWa = dedupWhatsAppList(_whatsappEvents);
      _whatsappEvents.clear();
      _whatsappEvents.addAll(cleanWa);

      LocalDatabaseService.instance.saveEvents([event]);
      _persistWhatsApp();
      _enqueueEvent(event);
      notifyListeners();
      // Instant direct push to CRM server (< 300ms)
      _directSyncWhatsAppCall(event);
    } else if (type == 'notification') {
      final text = raw['text']?.toString() ?? '';
      final name = raw['name']?.toString() ?? raw['title']?.toString() ?? 'Notification';
      if (isMessageCountSummary(text) || isMessageCountSummary(name)) {
        return; // Drop message count summary notifications immediately
      }
      final uid = raw['uid']?.toString() ?? 'notif-${DateTime.now().millisecondsSinceEpoch}';
      final event = SalesTrackEvent(
        uid: uid,
        kind: 'notification',
        time: (raw['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        direction: raw['direction']?.toString() ?? 'incoming',
        number: raw['number']?.toString() ?? '',
        name: name,
        app: raw['packageName']?.toString() ?? '',
        text: text,
        source: 'auto',
      );

      LocalDatabaseService.instance.saveEvents([event]);
      _enqueueEvent(event);
      notifyListeners();
      syncNow();
    }
  }

  Future<void> _startCallerIdLookup(String phone, String name, String direction, [String? initialPhoto]) async {
    final hasContactName = name.isNotEmpty &&
        name != phone &&
        !name.toLowerCase().contains('unknown') &&
        !name.toLowerCase().contains('caller');

    final info = CallerIdInfo(
      phoneNumber: phone,
      direction: direction,
      name: hasContactName ? name : phone,
      photoUrl: initialPhoto,
      isSearching: true,
      isUnsaved: !hasContactName,
      category: hasContactName ? 'contact' : 'unsaved',
    );

    _activeCallerId = info;
    notifyListeners();

    // 1. Instant local SQLite lookup (< 5ms)
    try {
      final localInfo = await LocalDatabaseService.instance.lookupCallerInfo(phone);
      if (localInfo != null && _activeCallerId?.phoneNumber == phone) {
        if (!hasContactName && localInfo['resolvedName'] != null) {
          info.name = localInfo['resolvedName'];
          info.isUnsaved = false;
        }
        info.totalPreviousCalls = (localInfo['totalCalls'] as int?) ?? 0;
        info.lastCallTime = localInfo['lastCallTime'];
        info.lastDuration = localInfo['lastDuration'];
        info.lastOutcome = localInfo['lastOutcome'];
        info.lastNote = localInfo['lastNote'];
        info.followUpAt = localInfo['followUpAt'];
        notifyListeners();
      }
    } catch (_) {}

    // 2. Central CRM Database Directory Lookup (if paired and online)
    if (_isPaired) {
      try {
        final res = await api.lookupNumber(phone);
        if (res.success && res.data != null && _activeCallerId?.phoneNumber == phone) {
          final data = res.data!;
          if (data['found'] == true && data['entry'] is Map) {
            final entry = Map<String, dynamic>.from(data['entry'] as Map);
            final crmName = entry['n']?.toString();
            final company = entry['c']?.toString();
            final status = entry['s']?.toString();
            final type = entry['t']?.toString() ?? 'lead';
            final lastOutcome = entry['lo']?.toString();
            final lastNote = entry['ln']?.toString();

            if (crmName != null && crmName.isNotEmpty) {
              info.name = crmName;
              info.isUnsaved = false;
            }
            if (company != null && company.isNotEmpty) info.company = company;
            if (status != null && status.isNotEmpty) info.leadStatus = status;
            info.category = type;
            if (lastOutcome != null && lastOutcome.isNotEmpty) info.lastOutcome = lastOutcome;
            if (lastNote != null && lastNote.isNotEmpty) info.lastNote = lastNote;
            final photo = entry['photo']?.toString() ?? entry['avatar']?.toString() ?? entry['image']?.toString();
            if (photo != null && photo.isNotEmpty) info.photoUrl = photo;
          }
        }
      } catch (_) {}
    }

    if (_activeCallerId?.phoneNumber == phone) {
      info.isSearching = false;
      notifyListeners();
    }
  }

  Future<void> lookupAndEnrichCaller(String phone, [String? name, String? direction]) async {
    await _startCallerIdLookup(phone, name ?? '', direction ?? 'incoming');
  }

  bool _shouldShowAfterCallPopup(SalesTrackEvent event) {
    if (_config.outcomesAsk == 'off') return false;
    if (_config.outcomesAsk == 'connected_only') {
      return event.duration > 0;
    }
    // For sales tracking: prompt after completed calls (connected, outgoing, missed) so outcomes & notes can be logged
    return true;
  }

  String? _lastEnsuredCallUid;
  DateTime? _lastEnsuredCallTime;

  /// Ensures that a call event is guaranteed to be sent to the CRM server in all cases.
  /// Used whenever an after-call / log-lead dialog is dismissed or submitted, ensuring
  /// that cancelling or crossing out the dialog view never drops the call from the server.
  Future<void> ensureCallSyncedToServer(SalesTrackEvent event) async {
    final now = DateTime.now();
    if (_lastEnsuredCallUid == event.uid &&
        _lastEnsuredCallTime != null &&
        now.difference(_lastEnsuredCallTime!).inSeconds < 5 &&
        event.syncStatus == 'synced') {
      return;
    }
    _lastEnsuredCallUid = event.uid;
    _lastEnsuredCallTime = now;

    try {
      // 1. Mark as pending and persist to local SQLite
      event.syncStatus = 'pending';
      await LocalDatabaseService.instance.saveEvents([event]);

      // Update in-memory lists
      int callIdx = _calls.indexWhere((c) => c.uid == event.uid);
      if (callIdx < 0) {
        callIdx = _calls.indexWhere((c) => isSameCall(c, event));
      }
      if (callIdx >= 0) {
        _calls[callIdx].syncStatus = 'pending';
      }

      int waIdx = _whatsappEvents.indexWhere((w) => w.uid == event.uid);
      if (waIdx < 0) {
        waIdx = _whatsappEvents.indexWhere((w) => isSameWhatsApp(w, event));
      }
      if (waIdx >= 0) {
        _whatsappEvents[waIdx].syncStatus = 'pending';
      }

      _pendingUids.remove(event.uid);
      _enqueueEvent(event);

      // 2. Direct upload to CRM server immediately if paired
      if (_isPaired) {
        final res = await api.syncEvents([event], health: _buildHealthPayload());
        if (res.success && res.data != null) {
          final stored = List<String>.from(res.data!['stored'] ?? []);
          final duplicate = List<String>.from(res.data!['duplicate'] ?? []);
          final skipped = (res.data!['skipped'] as List? ?? []).map((s) => s['uid']?.toString()).whereType<String>().toList();
          final rejected = (res.data!['rejected'] as List? ?? []).map((r) => r['uid']?.toString()).whereType<String>().toList();

          final finishedUids = {...stored, ...duplicate, ...skipped, ...rejected}.toList();
          if (finishedUids.isEmpty) {
            finishedUids.add(event.uid);
          }

          event.syncStatus = 'synced';
          await LocalDatabaseService.instance.markEventsSynced(finishedUids);
          _pendingQueue.removeWhere((e) => finishedUids.contains(e.uid));
          _pendingUids.removeWhere((u) => finishedUids.contains(u));

          if (callIdx >= 0) _calls[callIdx].syncStatus = 'synced';
          if (waIdx >= 0) _whatsappEvents[waIdx].syncStatus = 'synced';

          final recordingsWanted = List<String>.from(res.data!['recordings_wanted'] ?? []);
          if (recordingsWanted.contains(event.uid) && event.recordingPath != null && event.recordingPath!.isNotEmpty) {
            await _uploadWantedRecordings([event.uid]);
          }
        }
      }

      // Also trigger a general sync to flush any remaining items
      syncNow();
      notifyListeners();
    } catch (e) {
      debugPrint('Error ensuring call synced to server: $e');
      syncNow();
    }
  }

  Future<void> dismissAfterCallPopup([SalesTrackEvent? event]) async {
    final target = event ?? _activeAfterCallEvent;
    _activeAfterCallEvent = null;
    notifyListeners();

    if (target != null) {
      await ensureCallSyncedToServer(target);
    } else {
      syncNow();
    }
  }

  /// Instant direct push for WhatsApp events to the CRM server (< 300ms)
  /// completely independent of heavy audio recording upload queues.
  Future<void> _directSyncWhatsAppCall(SalesTrackEvent event) async {
    if (!_isPaired || _device == null) return;
    try {
      final res = await api.syncEvents([event], health: _buildHealthPayload());
      if (res.success && res.data != null) {
        final stored = List<String>.from(res.data!['stored'] ?? []);
        final duplicate = List<String>.from(res.data!['duplicate'] ?? []);
        final skipped = (res.data!['skipped'] as List? ?? []).map((s) => s['uid']?.toString()).whereType<String>().toList();
        final rejected = (res.data!['rejected'] as List? ?? []).map((r) => r['uid']?.toString()).whereType<String>().toList();

        final finishedUids = {...stored, ...duplicate, ...skipped, ...rejected}.toList();
        if (finishedUids.isEmpty) finishedUids.add(event.uid);

        event.syncStatus = 'synced';
        await LocalDatabaseService.instance.markEventsSynced(finishedUids);
        final idx = _whatsappEvents.indexWhere((w) => w.uid == event.uid);
        if (idx >= 0) {
          _whatsappEvents[idx].syncStatus = 'synced';
        }
        _pendingQueue.removeWhere((e) => finishedUids.contains(e.uid));
        _pendingUids.removeWhere((u) => finishedUids.contains(u));
        await refreshPendingCounts();
        notifyListeners();
      } else {
        // Fallback to queue if temporary failure
        syncNow(targetKind: 'whatsapp', uploadRecordings: false);
      }
    } catch (e) {
      debugPrint('Direct WhatsApp sync error: $e');
      syncNow(targetKind: 'whatsapp', uploadRecordings: false);
    }
  }

  // ---------------------------------------------------------------------------
  // 4. HISTORICAL SENSING (Device Call Logs, SMS, Audio Recordings & WhatsApp)
  // ---------------------------------------------------------------------------
  static String extractNumberKey(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  static String normalizeNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return trimmed;
    return hasPlus ? '+$digits' : digits;
  }

  static bool numbersMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final keyA = extractNumberKey(a);
    final keyB = extractNumberKey(b);
    if (keyA.isNotEmpty && keyB.isNotEmpty && keyA == keyB) return true;
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  static bool smsNumbersMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (numbersMatch(a, b)) return true;
    final digitsA = a.replaceAll(RegExp(r'\D'), '');
    final digitsB = b.replaceAll(RegExp(r'\D'), '');
    if (digitsA.isNotEmpty && digitsB.isNotEmpty) {
      if (digitsA == digitsB) return true;
      if (digitsA.length >= 5 && digitsB.contains(digitsA)) return true;
      if (digitsB.length >= 5 && digitsA.contains(digitsB)) return true;
    }
    final cleanA = a.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final cleanB = b.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (cleanA.isNotEmpty && cleanB.isNotEmpty) {
      if (cleanA == cleanB) return true;
      if (cleanA.length >= 5 && cleanB.contains(cleanA)) return true;
      if (cleanB.length >= 5 && cleanA.contains(cleanB)) return true;
    }
    return false;
  }

  static bool isSameCall(SalesTrackEvent a, SalesTrackEvent b) {
    if (a.uid.isNotEmpty && b.uid.isNotEmpty && a.uid == b.uid) return true;

    // Match callLogId if both have it (e.g. call-1371-...)
    final aMatch = RegExp(r'^call-(\d+)').firstMatch(a.uid);
    final bMatch = RegExp(r'^call-(\d+)').firstMatch(b.uid);
    if (aMatch != null && bMatch != null) {
      return aMatch.group(1) == bMatch.group(1);
    }

    if (numbersMatch(a.number, b.number) && a.direction == b.direction) {
      if ((a.time - b.time).abs() <= 3000) return true;
    }
    return false;
  }

  static List<SalesTrackEvent> dedupCallsList(List<SalesTrackEvent> list) {
    if (list.isEmpty) return [];

    final Map<String, int> uidIndex = {};
    final Map<String, int> logIdIndex = {};
    final Map<String, List<int>> numberBucket = {};
    final List<SalesTrackEvent> result = [];

    for (final call in list) {
      int existingIdx = -1;

      if (call.uid.isNotEmpty && uidIndex.containsKey(call.uid)) {
        existingIdx = uidIndex[call.uid]!;
      }

      if (existingIdx < 0) {
        final match = RegExp(r'^call-(\d+)-').firstMatch(call.uid);
        if (match != null && logIdIndex.containsKey(match.group(1)!)) {
          existingIdx = logIdIndex[match.group(1)!]!;
        }
      }

      final key = extractNumberKey(call.number);
      if (existingIdx < 0 && key.isNotEmpty && numberBucket.containsKey(key)) {
        for (final idx in numberBucket[key]!) {
          if (isSameCall(result[idx], call)) {
            existingIdx = idx;
            break;
          }
        }
      } else if (existingIdx < 0 && key.isEmpty) {
        for (int i = 0; i < result.length; i++) {
          if (isSameCall(result[i], call)) {
            existingIdx = i;
            break;
          }
        }
      }

      if (existingIdx < 0) {
        final newIdx = result.length;
        result.add(call);
        if (call.uid.isNotEmpty) uidIndex[call.uid] = newIdx;
        final match = RegExp(r'^call-(\d+)-').firstMatch(call.uid);
        if (match != null) logIdIndex[match.group(1)!] = newIdx;
        if (key.isNotEmpty) {
          numberBucket.putIfAbsent(key, () => []).add(newIdx);
        }
      } else {
        final existing = result[existingIdx];
        if ((call.recording || (call.recordingPath != null && call.recordingPath!.isNotEmpty)) &&
            (!existing.recording || existing.recordingPath == null || existing.recordingPath!.isEmpty)) {
          existing.recording = true;
          existing.recordingPath = call.recordingPath;
        }
        if (call.duration > existing.duration) {
          existing.duration = call.duration;
        }
        if (call.syncStatus == 'synced') {
          existing.syncStatus = 'synced';
        }
        if (existing.name.isEmpty && call.name.isNotEmpty) {
          existing.name = call.name;
        }
        if (call.uid.contains(RegExp(r'^call-\d+-')) && !existing.uid.contains(RegExp(r'^call-\d+-'))) {
          existing.uid = call.uid;
        }
      }
    }

    result.sort((a, b) => b.time.compareTo(a.time));

    final Set<String> claimedRecPaths = {};
    for (final call in result) {
      if (call.recordingPath != null && call.recordingPath!.isNotEmpty) {
        if (claimedRecPaths.contains(call.recordingPath!)) {
          call.recording = false;
          call.recordingPath = null;
        } else {
          claimedRecPaths.add(call.recordingPath!);
        }
      }
    }

    return result;
  }

  static bool isSameSms(SalesTrackEvent a, SalesTrackEvent b) {
    if (a.uid.isNotEmpty && b.uid.isNotEmpty && a.uid == b.uid) return true;
    final aMatch = RegExp(r'^((?:sms|mms)-\d+)').firstMatch(a.uid);
    final bMatch = RegExp(r'^((?:sms|mms)-\d+)').firstMatch(b.uid);
    if (aMatch != null && bMatch != null && aMatch.group(1) == bMatch.group(1)) {
      return true;
    }
    final textA = a.text?.trim() ?? '';
    final textB = b.text?.trim() ?? '';
    if (textA.isNotEmpty && textB.isNotEmpty && textA != textB) {
      return false;
    }
    if (a.direction == b.direction && smsNumbersMatch(a.number, b.number)) {
      final window = (textA.isNotEmpty && textA == textB) ? 300000 : 60000;
      if ((a.time - b.time).abs() <= window) {
        return true;
      }
    }
    return false;
  }

  static List<SalesTrackEvent> dedupSmsList(List<SalesTrackEvent> list) {
    if (list.isEmpty) return [];

    final Map<String, int> uidIndex = {};
    final Map<String, int> logIdIndex = {};
    final Map<String, int> timeNumIndex = {};
    final List<SalesTrackEvent> result = [];

    for (final sms in list) {
      int existingIdx = -1;

      if (sms.uid.isNotEmpty && uidIndex.containsKey(sms.uid)) {
        existingIdx = uidIndex[sms.uid]!;
      }

      if (existingIdx < 0) {
        final match = RegExp(r'^((?:sms|mms)-\d+)-').firstMatch(sms.uid);
        if (match != null && logIdIndex.containsKey(match.group(1)!)) {
          existingIdx = logIdIndex[match.group(1)!]!;
        }
      }

      String numKey = extractNumberKey(sms.number);
      if (numKey.isEmpty) {
        numKey = sms.number.replaceAll(RegExp(r'[\s\-+]'), '').toLowerCase();
      }
      if (existingIdx < 0 && numKey.isNotEmpty) {
        final bucket = sms.time ~/ 60000;
        for (final b in [bucket, bucket - 1, bucket + 1]) {
          final k = '${sms.direction}_${numKey}_$b';
          if (timeNumIndex.containsKey(k)) {
            final candIdx = timeNumIndex[k]!;
            if ((result[candIdx].time - sms.time).abs() <= 60000) {
              if (result[candIdx].text == null || sms.text == null || result[candIdx].text!.isEmpty || sms.text!.isEmpty || result[candIdx].text == sms.text) {
                existingIdx = candIdx;
                break;
              }
            }
          }
        }
      }

      // Check alphanumeric sender variants and 5-min window if text body is identical
      if (existingIdx < 0 && (sms.text?.trim().isNotEmpty ?? false)) {
        for (int i = result.length - 1; i >= 0 && i >= result.length - 40; i--) {
          if (isSameSms(result[i], sms)) {
            existingIdx = i;
            break;
          }
        }
      }

      if (existingIdx < 0) {
        final newIdx = result.length;
        result.add(sms);
        if (sms.uid.isNotEmpty) uidIndex[sms.uid] = newIdx;
        final match = RegExp(r'^((?:sms|mms)-\d+)-').firstMatch(sms.uid);
        if (match != null) logIdIndex[match.group(1)!] = newIdx;
        if (numKey.isNotEmpty) {
          timeNumIndex['${sms.direction}_${numKey}_${sms.time ~/ 60000}'] = newIdx;
        }
      } else {
        final existing = result[existingIdx];
        if (sms.syncStatus == 'synced') existing.syncStatus = 'synced';
        if (existing.name.isEmpty && sms.name.isNotEmpty) existing.name = sms.name;
        if ((existing.text == null || existing.text!.isEmpty) && (sms.text != null && sms.text!.isNotEmpty)) {
          existing.text = sms.text;
        }
        if (sms.uid.contains(RegExp(r'^(?:sms|mms)-\d+-')) && !existing.uid.contains(RegExp(r'^(?:sms|mms)-\d+-'))) {
          existing.uid = sms.uid;
        }
      }
    }

    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  static bool isSameWhatsApp(SalesTrackEvent a, SalesTrackEvent b) {
    if (a.uid.isNotEmpty && b.uid.isNotEmpty && a.uid == b.uid) return true;
    if (a.kind != b.kind) return false;
    if (a.kind == 'whatsapp_message') {
      if (a.text != null && b.text != null && a.text!.isNotEmpty && b.text!.isNotEmpty && a.text != b.text) {
        return false;
      }
      if ((a.time - b.time).abs() <= 60000 &&
          (a.name == b.name || numbersMatch(a.number, b.number))) {
        return true;
      }
      return false;
    }
    if (a.kind == 'whatsapp_call') {
      final isRingingA = a.duration == 0 && a.direction != 'missed';
      final isRingingB = b.duration == 0 && b.direction != 'missed';
      if ((a.time - b.time).abs() <= (isRingingA || isRingingB ? 120000 : 5000) &&
          (numbersMatch(a.number, b.number) ||
           numbersMatch(a.name, b.number) ||
           numbersMatch(b.name, a.number))) {
        return true;
      }
      return false;
    }
    return false;
  }

  /// Returns true if the string represents an Android group summary or message count (e.g. "5 new messages")
  static bool isMessageCountSummary(String? str) {
    if (str == null) return false;
    final trimmed = str.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (RegExp(r'^\(?\d+\s+(new\s+|unread\s+)?messages?[\s\.\,\!\?]*\)?$').hasMatch(lower)) return true;
    if (RegExp(r'^\d+\s+(new\s+|unread\s+)?messages?\s+from\s+.*$').hasMatch(lower)) return true;
    if (lower.contains('new message') && RegExp(r'.*\b\d+\s+new\s+messages?\b.*').hasMatch(lower) && lower.length < 35) return true;
    if (lower.contains('checking for new messages') || lower.contains('looking for new messages')) return true;
    if (lower.contains('whatsapp web is currently active') || lower.contains('whatsapp web')) return true;
    if (lower.contains('messages from') && lower.contains('chat')) return true;
    if (RegExp(r'.*\(\d+\s+messages?\)$').hasMatch(lower)) return true;
    return false;
  }

  static List<SalesTrackEvent> dedupWhatsAppList(List<SalesTrackEvent> list) {
    if (list.isEmpty) return [];
    final List<SalesTrackEvent> result = [];
    final Map<String, List<int>> numberBucket = {};

    for (final wa in list) {
      if (isMessageCountSummary(wa.text) || isMessageCountSummary(wa.name)) continue;
      int existingIdx = -1;

      final key = extractNumberKey(wa.number).isNotEmpty
          ? extractNumberKey(wa.number)
          : wa.name.toLowerCase().trim();

      if (key.isNotEmpty && numberBucket.containsKey(key)) {
        for (final idx in numberBucket[key]!) {
          if (isSameWhatsApp(result[idx], wa)) {
            existingIdx = idx;
            break;
          }
        }
      } else if (key.isEmpty) {
        for (int i = 0; i < result.length; i++) {
          if (isSameWhatsApp(result[i], wa)) {
            existingIdx = i;
            break;
          }
        }
      }

      if (existingIdx < 0) {
        final newIdx = result.length;
        result.add(wa);
        if (key.isNotEmpty) {
          numberBucket.putIfAbsent(key, () => []).add(newIdx);
        }
      } else {
        final existing = result[existingIdx];
        if (wa.syncStatus == 'synced') existing.syncStatus = 'synced';
        if (wa.duration > existing.duration) existing.duration = wa.duration;
        if (existing.name.isEmpty && wa.name.isNotEmpty) existing.name = wa.name;
        if (existing.number.isEmpty && wa.number.isNotEmpty) existing.number = wa.number;
        if (existing.direction == 'incoming' && wa.direction == 'outgoing') existing.direction = 'outgoing';
        if (existing.time > wa.time) existing.time = wa.time;
      }
    }
    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  bool _isFetchingCallLogs = false;
  bool _isFetchingSms = false;

  Future<void> syncDeviceCallLogs() async {
    if (!hasCallLogPermission || _isFetchingCallLogs) return;
    _isFetchingCallLogs = true;
    try {
      final dynamic raw = await _platform.invokeMethod('fetchDeviceCallLogs');
      final rawLogs = (raw as List?)?.whereType<Map>().toList();
      if (rawLogs != null && rawLogs.isNotEmpty) {
        int newCount = 0;

        final Map<String, int> uidMap = {};
        final Map<String, int> logIdMap = {};
        final Map<String, List<int>> callNumMap = {};
        final Map<String, List<int>> waNumMap = {};

        for (int i = 0; i < _calls.length; i++) {
          final c = _calls[i];
          if (c.uid.isNotEmpty) uidMap[c.uid] = i;
          final match = RegExp(r'^call-(\d+)-').firstMatch(c.uid);
          if (match != null) logIdMap[match.group(1)!] = i;
          final k = extractNumberKey(c.number);
          if (k.isNotEmpty) callNumMap.putIfAbsent(k, () => []).add(i);
        }

        for (int i = 0; i < _whatsappEvents.length; i++) {
          final w = _whatsappEvents[i];
          final k = extractNumberKey(w.number).isNotEmpty ? extractNumberKey(w.number) : w.name.toLowerCase().trim();
          if (k.isNotEmpty) waNumMap.putIfAbsent(k, () => []).add(i);
        }

        for (final item in rawLogs) {
          final event = SalesTrackEvent.fromJson(Map<String, dynamic>.from(item));
          
          if (event.kind == 'whatsapp_call') {
            int existing = -1;
            final waKey = extractNumberKey(event.number).isNotEmpty ? extractNumberKey(event.number) : event.name.toLowerCase().trim();
            if (waKey.isNotEmpty && waNumMap.containsKey(waKey)) {
              for (final idx in waNumMap[waKey]!) {
                if (isSameWhatsApp(_whatsappEvents[idx], event)) {
                  existing = idx;
                  break;
                }
              }
            } else if (waKey.isEmpty) {
              for (int i = 0; i < _whatsappEvents.length; i++) {
                if (isSameWhatsApp(_whatsappEvents[i], event)) {
                  existing = i;
                  break;
                }
              }
            }

            if (existing >= 0) {
              final old = _whatsappEvents[existing];
              event.uid = old.uid; // Preserve UID so CRM never creates a duplicate call!
              if (old.syncStatus == 'synced') event.syncStatus = 'synced';
              if (old.duration > event.duration) event.duration = old.duration;
              if (old.direction == 'outgoing' && event.direction == 'incoming') event.direction = 'outgoing';
              if (old.time < event.time) event.time = old.time;
              _whatsappEvents[existing] = event;
              if (event.syncStatus != 'synced') {
                _enqueueEvent(event);
              }
            } else {
              _whatsappEvents.add(event);
              _enqueueEvent(event);
              newCount++;
              if (waKey.isNotEmpty) waNumMap.putIfAbsent(waKey, () => []).add(_whatsappEvents.length - 1);
            }
          } else {
            int existing = -1;
            if (event.uid.isNotEmpty && uidMap.containsKey(event.uid)) {
              existing = uidMap[event.uid]!;
            } else {
              final match = RegExp(r'^call-(\d+)-').firstMatch(event.uid);
              if (match != null && logIdMap.containsKey(match.group(1)!)) {
                existing = logIdMap[match.group(1)!]!;
              } else {
                final k = extractNumberKey(event.number);
                if (k.isNotEmpty && callNumMap.containsKey(k)) {
                  for (final idx in callNumMap[k]!) {
                    if (isSameCall(_calls[idx], event)) {
                      existing = idx;
                      break;
                    }
                  }
                } else if (k.isEmpty) {
                  for (int i = 0; i < _calls.length; i++) {
                    if (isSameCall(_calls[i], event)) {
                      existing = i;
                      break;
                    }
                  }
                }
              }
            }

            if (existing >= 0) {
              if (_calls[existing].syncStatus == 'synced') {
                event.syncStatus = 'synced';
              }
              if (_calls[existing].recording && !event.recording) {
                event.recording = true;
                event.recordingPath = _calls[existing].recordingPath;
              }
              if (_calls[existing].duration > event.duration) {
                event.duration = _calls[existing].duration;
              }
              _calls[existing] = event;
              if (event.syncStatus != 'synced') {
                _enqueueEvent(event);
              }
            } else {
              _calls.add(event);
              _enqueueEvent(event);
              newCount++;
              if (event.uid.isNotEmpty) uidMap[event.uid] = _calls.length - 1;
            }
          }
        }
        // Deduplicate calls strictly
        final cleanCalls = dedupCallsList(_calls);
        _calls.clear();
        _calls.addAll(cleanCalls);

        _whatsappEvents.sort((a, b) => b.time.compareTo(a.time));

        // Persist local store to SQLite & SharedPreferences
        await LocalDatabaseService.instance.saveEvents(_calls);
        await LocalDatabaseService.instance.saveEvents(_whatsappEvents);
        await LocalDatabaseService.instance.cleanupDuplicates();
        await _persistCalls();
        await _persistWhatsApp();
        await _persistQueue();
        await refreshPendingCounts();

        // Auto-detect if a call finished recently (within last 5 minutes) or requested via launch intent
        if (cleanCalls.isNotEmpty && _activeAfterCallEvent == null) {
          SalesTrackEvent? candidate;
          if (_pendingAfterCallNumber != null && _pendingAfterCallNumber!.isNotEmpty) {
            final targetKey = extractNumberKey(_pendingAfterCallNumber!);
            for (final c in cleanCalls) {
              if (extractNumberKey(c.number) == targetKey) {
                candidate = c;
                break;
              }
            }
            _pendingAfterCallNumber = null;
          }
          if (candidate == null) {
            final newest = cleanCalls.first;
            final callAgeMs = DateTime.now().millisecondsSinceEpoch - newest.time;
            if (callAgeMs >= 0 && callAgeMs < 300000 && _shouldShowAfterCallPopup(newest)) {
              candidate = newest;
            }
          }
          if (candidate != null) {
            final hasOutcome = await LocalDatabaseService.instance.hasOutcomeForUid(candidate.uid);
            if (!hasOutcome) {
              _activeAfterCallEvent = candidate;
            }
          }
        }

        _statusMessage = 'Fetched ${_calls.length} calls from dialer ($newCount new)';
        notifyListeners();
        if (_isPaired && (_pendingQueue.isNotEmpty || _pendingCallsCount > 0)) {
          syncNow();
        }
      }
    } catch (e) {
      debugPrint('Error fetching historical call logs: $e');
    } finally {
      _isFetchingCallLogs = false;
    }
  }

  Future<void> syncDeviceSms() async {
    if (!hasSmsPermission || _isFetchingSms) return;
    _isFetchingSms = true;
    try {
      final dynamic raw = await _platform.invokeMethod('fetchDeviceSms');
      final rawSms = (raw as List?)?.whereType<Map>().toList();
      if (rawSms != null && rawSms.isNotEmpty) {
        for (final item in rawSms) {
          final event = SalesTrackEvent.fromJson(Map<String, dynamic>.from(item));
          final existing = _smsList.indexWhere((s) => isSameSms(s, event));
          if (existing >= 0) {
            final old = _smsList[existing];
            event.uid = old.uid; // Preserve original UID so CRM never creates a duplicate!
            if (old.syncStatus == 'synced') {
              event.syncStatus = 'synced';
            }
            if (old.name.isNotEmpty && event.name.isEmpty) {
              event.name = old.name;
            }
            _smsList[existing] = event;
            if (event.syncStatus != 'synced') {
              _enqueueEvent(event);
            }
          } else {
            _smsList.add(event);
            _enqueueEvent(event);
          }
        }
        final cleanSms = dedupSmsList(_smsList);
        _smsList.clear();
        _smsList.addAll(cleanSms);
        await LocalDatabaseService.instance.saveEvents(_smsList);
        await LocalDatabaseService.instance.cleanupDuplicates();
        await _persistSms();
        await _persistQueue();
        await refreshPendingCounts();
        notifyListeners();
        if (_isPaired && (_pendingQueue.isNotEmpty || _pendingSmsCount > 0)) {
          syncNow();
        }
      }
    } catch (e) {
      debugPrint('Error fetching historical SMS: $e');
    } finally {
      _isFetchingSms = false;
    }
  }

  Future<void> syncActiveWhatsAppNotifications() async {
    try {
      final dynamic raw = await _platform.invokeMethod('fetchActiveWhatsAppNotifications');
      final rawList = (raw as List?)?.whereType<Map>().toList();
      if (rawList != null && rawList.isNotEmpty) {
        int newCount = 0;
        for (final item in rawList) {
          final event = SalesTrackEvent.fromJson(Map<String, dynamic>.from(item));
          if (isMessageCountSummary(event.text) || isMessageCountSummary(event.name)) continue;
          event.number = normalizeNumber(event.number);
          final isFinalized = event.kind != 'whatsapp_call' || event.direction == 'missed' || event.duration > 0;
          if (!isFinalized) {
            event.syncStatus = 'in_progress';
          }
          final existing = _whatsappEvents.indexWhere((w) => isSameWhatsApp(w, event));
          if (existing >= 0) {
            final old = _whatsappEvents[existing];
            event.uid = old.uid; // Preserve original UID so CRM never creates a duplicate call!
            if (old.syncStatus == 'synced') {
              event.syncStatus = 'synced';
            }
            if (old.duration > event.duration) {
              event.duration = old.duration;
            }
            if (old.direction == 'outgoing' && event.direction == 'incoming') {
              event.direction = 'outgoing';
            }
            if (old.time < event.time) {
              event.time = old.time;
            }
            _whatsappEvents[existing] = event;
            final isFinalized = event.kind != 'whatsapp_call' || event.direction == 'missed' || event.duration > 0;
            if (event.syncStatus != 'synced' && isFinalized) {
              _enqueueEvent(event);
            }
          } else {
            _whatsappEvents.add(event);
            final isFinalized = event.kind != 'whatsapp_call' || event.direction == 'missed' || event.duration > 0;
            if (isFinalized) {
              _enqueueEvent(event);
              newCount++;
            }
          }
        }
        if (newCount > 0 || _whatsappEvents.isNotEmpty) {
          final cleanWa = dedupWhatsAppList(_whatsappEvents);
          _whatsappEvents.clear();
          _whatsappEvents.addAll(cleanWa);
          await LocalDatabaseService.instance.saveEvents(_whatsappEvents);
          await LocalDatabaseService.instance.cleanupDuplicates();
          await _persistWhatsApp();
          await _persistQueue();
          await refreshPendingCounts();
          notifyListeners();
          if (_isPaired && (_pendingQueue.isNotEmpty || _pendingWhatsAppCount > 0)) {
            syncNow();
          }
        }
      }
    } catch (e) {
      debugPrint('Error polling active WhatsApp notifications: $e');
    }
  }

  Future<void> scanLocalRecordings() async {
    try {
      final list = await _platform.invokeListMethod<Map<dynamic, dynamic>>('fetchLocalCallRecordings');
      if (list != null) {
        _localRecordings.clear();
        for (final item in list) {
          _localRecordings.add(Map<String, dynamic>.from(item));
        }
        await _persistRecordings();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error scanning recordings: $e');
    }
  }

  Future<void> syncServerEvents() async {
    if (!_isPaired) return;
    try {
      final res = await api.fetchEvents(limit: 100);
      if (res.success && res.data != null) {
        final rawEvents = res.data!['events'] as List? ?? [];
        if (rawEvents.isNotEmpty) {
          for (final raw in rawEvents) {
            if (raw is Map) {
              final ev = SalesTrackEvent.fromJson(Map<String, dynamic>.from(raw));
              ev.syncStatus = 'synced';
              if (ev.kind == 'call') {
                final idx = _calls.indexWhere((c) => isSameCall(c, ev) || c.uid == ev.uid);
                if (idx >= 0) {
                  _calls[idx] = ev;
                } else {
                  _calls.add(ev);
                }
              } else if (ev.kind == 'sms') {
                final idx = _smsList.indexWhere((s) => isSameSms(s, ev) || s.uid == ev.uid);
                if (idx >= 0) {
                  _smsList[idx] = ev;
                } else {
                  _smsList.add(ev);
                }
              } else if (ev.kind == 'whatsapp_call' || ev.kind == 'whatsapp_message') {
                final idx = _whatsappEvents.indexWhere((w) => isSameWhatsApp(w, ev) || w.uid == ev.uid);
                if (idx >= 0) {
                  _whatsappEvents[idx] = ev;
                } else {
                  _whatsappEvents.add(ev);
                }
              }
            }
          }
          final cleanCalls = dedupCallsList(_calls);
          _calls.clear();
          _calls.addAll(cleanCalls);

          final cleanSms = dedupSmsList(_smsList);
          _smsList.clear();
          _smsList.addAll(cleanSms);

          final cleanWa = dedupWhatsAppList(_whatsappEvents);
          _whatsappEvents.clear();
          _whatsappEvents.addAll(cleanWa);

          await LocalDatabaseService.instance.saveEvents(_calls);
          await LocalDatabaseService.instance.saveEvents(_smsList);
          await LocalDatabaseService.instance.saveEvents(_whatsappEvents);
          await _persistCalls();
          await _persistSms();
          await _persistWhatsApp();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error syncing server events: $e');
    }
  }

  // Combined one-tap sync for UI refresh button
  Future<void> syncAllLocalAndRemote() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncProgress = 0.05;
    _syncProgressMessage = 'Reading call history from phone dialer...';
    _statusMessage = 'Scanning phone data...';
    notifyListeners();

    try {
      await checkPermissions();
      if (!hasEssentialPermissions) {
        await requestAllPermissions();
      }
      if (hasCallLogPermission) {
        _syncProgress = 0.15;
        _syncProgressMessage = 'Scanning calls from phone dialer...';
        notifyListeners();
        await syncDeviceCallLogs();
      }
      if (hasSmsPermission) {
        _syncProgress = 0.35;
        _syncProgressMessage = 'Scanning SMS messages...';
        notifyListeners();
        await syncDeviceSms();
      }
      _syncProgress = 0.45;
      _syncProgressMessage = 'Checking WhatsApp notifications...';
      notifyListeners();
      await syncActiveWhatsAppNotifications();
      await syncServerEvents();

      _syncProgress = 0.55;
      _syncProgressMessage = 'Scanning call audio recordings...';
      notifyListeners();
      await scanLocalRecordings();

      if (_isPaired) {
        _syncProgress = 0.65;
        _syncProgressMessage = 'Uploading telemetry data to CRM server...';
        notifyListeners();
        await syncNow(uploadRecordings: true, alreadyMarkedSyncing: true);
        await sendHeartbeat();
      } else {
        _statusMessage = 'Refreshed ${_calls.length} calls locally (not paired)';
        _syncProgress = 1.0;
        _syncProgressMessage = 'Scan Complete';
      }
    } catch (e) {
      debugPrint('Error during syncAllLocalAndRemote: $e');
      _statusMessage = 'Sync error: $e';
    } finally {
      _isSyncing = false;
      await refreshPendingCounts();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 5. QUEUE & SYNC (Robust Offline & Online Synchronization)
  // ---------------------------------------------------------------------------
  void _enqueueEvent(SalesTrackEvent event) {
    if (_config.paused) return;
    if (_config.isNumberExcluded(event.number)) return;
    if (_config.trackSim > 0 && event.sim > 0 && event.sim != _config.trackSim) return;

    // Filter out group summary notifications (e.g. "5 new messages")
    if (isMessageCountSummary(event.text) || isMessageCountSummary(event.name)) return;

    if (event.kind == 'call' && !_config.trackingCalls) return;
    if (event.kind == 'whatsapp_call' && !_config.trackingWhatsappCalls) return;
    if (event.kind == 'whatsapp_message') {
      if (!_config.trackingWhatsappCalls && !_config.trackingSms) return;
    } else if ((event.kind == 'sms' || event.kind == 'notification') && !_config.trackingSms) {
      return;
    }

    // Strict deduplication: Do not re-enqueue if already synced
    if (event.syncStatus == 'synced') return;

    if (event.uid.isNotEmpty && _pendingUids.contains(event.uid)) return;

    _pendingQueue.add(event);
    if (event.uid.isNotEmpty) _pendingUids.add(event.uid);
  }

  Future<void> syncNow({String? targetKind, bool uploadRecordings = true, bool alreadyMarkedSyncing = false}) async {
    if (!_isPaired) return;
    final isWhatsAppOnly = targetKind != null && targetKind.startsWith('whatsapp');
    if (isWhatsAppOnly) {
      uploadRecordings = false;
    }

    if (_isSyncing && !alreadyMarkedSyncing && !isWhatsAppOnly) {
      _syncPendingAgain = true;
      return;
    }

    if (!alreadyMarkedSyncing && !isWhatsAppOnly) {
      _isSyncing = true;
      _syncProgress = 0.05;
    }
    _syncProgressMessage = 'Starting synchronization with CRM...';
    _statusMessage = 'Syncing data to CRM server...';
    notifyListeners();

    try {
      final batchSize = (_config.batchSize > 0 && _config.batchSize <= 100) ? _config.batchSize : 50;
      int completedEvents = 0;

      // Query database pending count to compute progress
      final pendingCounts = await LocalDatabaseService.instance.getPendingCounts();
      final totalEventsToSync = targetKind == 'call'
          ? pendingCounts['pendingCalls']!
          : (targetKind == 'whatsapp'
              ? pendingCounts['pendingWhatsApp']!
              : (targetKind == 'sms'
                  ? pendingCounts['pendingSms']!
                  : pendingCounts['pendingTotal']!));

      // Loop and upload all pending events in batches directly from SQLite
      bool keepSyncing = true;
      String? serverSyncError;
      while (keepSyncing) {
        final batch = await LocalDatabaseService.instance.getPendingEvents(
          kind: targetKind,
          limit: batchSize,
        );

        if (batch.isEmpty) {
          keepSyncing = false;
          break;
        }

        // Filter out summary/count messages before upload and purge them from DB
        final summaryEvents = batch.where((ev) => isMessageCountSummary(ev.text) || isMessageCountSummary(ev.name)).toList();
        if (summaryEvents.isNotEmpty) {
          final summaryUids = summaryEvents.map((e) => e.uid).toList();
          await LocalDatabaseService.instance.markEventsSynced(summaryUids);
          _pendingQueue.removeWhere((e) => summaryUids.contains(e.uid));
          _pendingUids.removeWhere((u) => summaryUids.contains(u));
          batch.removeWhere((ev) => summaryUids.contains(ev.uid));
        }

        if (batch.isEmpty) continue;

        _syncProgressMessage = 'Uploading ${batch.length} ${targetKind ?? "telemetry"} events to CRM...';
        notifyListeners();

        final res = await api.syncEvents(batch, health: _buildHealthPayload());

        if (res.success && res.data != null) {
          final stored = List<String>.from(res.data!['stored'] ?? []);
          final duplicate = List<String>.from(res.data!['duplicate'] ?? []);
          final skipped = (res.data!['skipped'] as List? ?? []).map((s) => s['uid']?.toString()).whereType<String>().toList();
          final rejected = (res.data!['rejected'] as List? ?? []).map((r) => r['uid']?.toString()).whereType<String>().toList();

          final finishedUids = {...stored, ...duplicate, ...skipped, ...rejected}.toList();
          if (finishedUids.isEmpty) {
            finishedUids.addAll(batch.map((e) => e.uid));
          }

          _pendingQueue.removeWhere((e) => finishedUids.contains(e.uid));
          _pendingUids.removeWhere((u) => finishedUids.contains(u));

          // Mark synced status in local data stores & SQLite
          for (final call in _calls) {
            if (finishedUids.contains(call.uid)) call.syncStatus = 'synced';
          }
          for (final wa in _whatsappEvents) {
            if (finishedUids.contains(wa.uid)) wa.syncStatus = 'synced';
          }
          for (final sms in _smsList) {
            if (finishedUids.contains(sms.uid)) sms.syncStatus = 'synced';
          }
          await LocalDatabaseService.instance.markEventsSynced(finishedUids);

          // Check if server specifically requested recordings
          final recordingsWanted = List<String>.from(res.data!['recordings_wanted'] ?? []);
          if (recordingsWanted.isNotEmpty) {
            await _uploadWantedRecordings(recordingsWanted);
          }

          completedEvents += finishedUids.length;
          _syncProgress = (completedEvents / (totalEventsToSync > 0 ? totalEventsToSync : 1) * 0.7).clamp(0.05, 0.7);
          _statusMessage = 'Synced $completedEvents items to CRM...';
          notifyListeners();
        } else {
          if (_isPairingLost(res)) {
            await _handlePairingLost(res.error ?? 'device_revoked');
            return;
          }
          if (_isUpdateRequired(res)) {
            _isUpdateMandatory = true;
            _statusMessage = 'App update required by CRM server';
            notifyListeners();
            keepSyncing = false;
            break;
          }
          serverSyncError = res.message ?? res.error ?? 'Server rejected sync';
          _statusMessage = 'Server: $serverSyncError (saved locally in SQLite)';
          keepSyncing = false;
          break;
        }
      }

      // Upload audio recordings if enabled
      if (uploadRecordings && _config.trackingRecordings) {
        while (true) {
          final recsToUpload = await LocalDatabaseService.instance.getPendingRecordings(limit: 10, includeFailed: true);
          if (recsToUpload.isEmpty) break;
          int batchProcessed = 0;
          for (int i = 0; i < recsToUpload.length; i++) {
            final rec = recsToUpload[i];
            if (rec.recordingPath != null && rec.recordingPath!.isNotEmpty) {
              final file = File(rec.recordingPath!);
              if (!await file.exists()) {
                // Audio file was cleaned up from storage: clear pending status
                await LocalDatabaseService.instance.markRecordingSynced(rec.uid);
                for (final call in _calls) {
                  if (call.uid == rec.uid) {
                    call.recordingSyncStatus = 'none';
                    call.recording = false;
                  }
                }
                batchProcessed++;
                continue;
              }

              _syncProgressMessage = 'Uploading audio recording (${rec.name.isNotEmpty ? rec.name : rec.number})...';
              _syncProgress = 0.85;
              notifyListeners();

              var upRes = await api.uploadRecording(uid: rec.uid, audioFilePath: rec.recordingPath!);
              if (!upRes.success && upRes.statusCode == 404) {
                await api.syncEvents([rec]);
                upRes = await api.uploadRecording(uid: rec.uid, audioFilePath: rec.recordingPath!);
              }

              if (upRes.success || upRes.data?['already'] == true) {
                await LocalDatabaseService.instance.markRecordingSynced(rec.uid);
                for (final call in _calls) {
                  if (call.uid == rec.uid) call.recordingSyncStatus = 'synced';
                }
                batchProcessed++;
              } else {
                await LocalDatabaseService.instance.markRecordingFailed(rec.uid);
                for (final call in _calls) {
                  if (call.uid == rec.uid) call.recordingSyncStatus = 'failed';
                }
              }
            }
          }
          if (batchProcessed == 0) {
            // All remaining in this batch failed, break out so sync does not hang
            break;
          }
        }
      }

      // Sync pending after-call outcomes
      final pendingOutcomes = await LocalDatabaseService.instance.getPendingOutcomes();
      if (pendingOutcomes.isNotEmpty) {
        final outRes = await api.submitOutcomes(pendingOutcomes);
        if (outRes.success) {
          final storedOutcomes = List<String>.from(outRes.data?['stored'] ?? []);
          await LocalDatabaseService.instance.markOutcomesSynced(storedOutcomes);
        }
      }

      await LocalDatabaseService.instance.cleanupDuplicates();
      final pendingFromDb = await LocalDatabaseService.instance.getPendingEvents(limit: 10000);
      _pendingQueue.clear();
      _pendingQueue.addAll(pendingFromDb);
      _pendingUids.clear();
      _pendingUids.addAll(pendingFromDb.map((e) => e.uid).where((u) => u.isNotEmpty));
      await _persistCalls();
      await _persistSms();
      await _persistWhatsApp();
      await _persistQueue();
      await refreshPendingCounts();

      _lastSyncTime = DateTime.now();
      _syncProgress = 1.0;
      _syncProgressMessage = 'Sync Complete';
      if (pendingEventsCount == 0 && _pendingRecordingsCount == 0) {
        _statusMessage = 'Up to date (All data synced with CRM)';
      } else if (serverSyncError != null) {
        if (serverSyncError.toLowerCase().contains('token') || serverSyncError.toLowerCase().contains('pair')) {
          _statusMessage = 'Device token expired. Pair again. ($pendingEventsCount queued in offline DB)';
        } else {
          _statusMessage = 'Server: $serverSyncError ($pendingEventsCount events, $_pendingRecordingsCount recs pending)';
        }
      } else {
        _statusMessage = 'Sync finished ($pendingEventsCount events, $_pendingRecordingsCount recs pending)';
      }
    } catch (e) {
      _statusMessage = 'Offline: Saved in local SQLite database ($pendingEventsCount pending)';
      _syncProgressMessage = 'Offline - saved locally';
    } finally {
      if (!alreadyMarkedSyncing) {
        _isSyncing = false;
      }
      notifyListeners();
      if (_syncPendingAgain) {
        _syncPendingAgain = false;
        Future.microtask(() => syncNow(targetKind: targetKind, uploadRecordings: uploadRecordings));
      }
    }
  }

  Future<void> _uploadWantedRecordings(List<String> wantedUids) async {
    for (int i = 0; i < wantedUids.length; i++) {
      final uid = wantedUids[i];
      final call = _calls.firstWhere(
        (c) => c.uid == uid,
        orElse: () => SalesTrackEvent(uid: '', kind: '', time: 0, direction: '', number: '', name: ''),
      );
      if (call.recordingPath != null && call.recordingPath!.isNotEmpty) {
        _syncProgressMessage = 'Uploading requested audio (${i + 1}/${wantedUids.length})...';
        notifyListeners();
        final res = await api.uploadRecording(uid: uid, audioFilePath: call.recordingPath!);
        if (res.success) {
          await LocalDatabaseService.instance.markRecordingSynced(uid);
        }
      }
    }
  }

  // Dedicated Tab Sync Actions
  Future<void> syncCallsOnly() async {
    await syncDeviceCallLogs();
    await syncNow(targetKind: 'call', uploadRecordings: true);
  }

  Future<void> syncWhatsAppOnly() async {
    await syncActiveWhatsAppNotifications();
    await syncNow(targetKind: 'whatsapp', uploadRecordings: false);
  }

  Future<void> syncSmsOnly() async {
    await syncDeviceSms();
    await syncNow(targetKind: 'sms', uploadRecordings: false);
  }

  Future<void> syncRecordingsOnly() async {
    if (!_isPaired || _isSyncing) return;
    _isSyncing = true;
    _syncProgress = 0.1;
    _syncProgressMessage = 'Scanning call recordings to upload...';
    notifyListeners();

    try {
      final recs = await LocalDatabaseService.instance.getPendingRecordings(limit: 50, includeFailed: true);
      if (recs.isEmpty) {
        _syncProgress = 1.0;
        _syncProgressMessage = 'All call recordings are synced';
        _statusMessage = 'All call recordings are synced';
        notifyListeners();
        return;
      }
      for (int i = 0; i < recs.length; i++) {
        final rec = recs[i];
        if (rec.recordingPath != null && rec.recordingPath!.isNotEmpty) {
          _syncProgressMessage = 'Uploading recording (${i + 1}/${recs.length}): ${rec.number}...';
          _syncProgress = ((i + 1) / recs.length).clamp(0.1, 0.95);
          notifyListeners();

          var upRes = await api.uploadRecording(uid: rec.uid, audioFilePath: rec.recordingPath!);
          if (!upRes.success && upRes.statusCode == 404) {
            await api.syncEvents([rec]);
            upRes = await api.uploadRecording(uid: rec.uid, audioFilePath: rec.recordingPath!);
          }
          if (upRes.success || upRes.data?['already'] == true) {
            await LocalDatabaseService.instance.markRecordingSynced(rec.uid);
            for (final call in _calls) {
              if (call.uid == rec.uid) call.recordingSyncStatus = 'synced';
            }
          } else {
            await LocalDatabaseService.instance.markRecordingFailed(rec.uid);
          }
        }
      }
      await refreshPendingCounts();
      _syncProgress = 1.0;
      _syncProgressMessage = 'Recordings upload complete';
    } catch (_) {
      _syncProgressMessage = 'Recording upload failed (saved locally)';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> forceResyncAll({String? kind}) async {
    if (_isSyncing) return;
    _statusMessage = 'Scanning phone dialer and preparing full history...';
    notifyListeners();

    if (hasCallLogPermission && (kind == null || kind == 'call')) {
      await syncDeviceCallLogs();
    }
    if (hasSmsPermission && (kind == null || kind == 'sms')) {
      await syncDeviceSms();
    }
    if (kind == null || kind.startsWith('whatsapp')) {
      await syncActiveWhatsAppNotifications();
    }
    if (kind == null || kind == 'call') {
      await scanLocalRecordings();
    }

    await LocalDatabaseService.instance.resetAllToPending(kind: kind);

    if (kind == null || kind == 'call') {
      for (final c in _calls) {
        c.syncStatus = 'pending';
      }
    }
    if (kind == null || kind == 'whatsapp' || kind == 'whatsapp_call' || kind == 'whatsapp_message') {
      for (final w in _whatsappEvents) {
        w.syncStatus = 'pending';
      }
    }
    if (kind == null || kind == 'sms') {
      for (final s in _smsList) {
        s.syncStatus = 'pending';
      }
    }

    _pendingQueue.clear();
    final allPending = await LocalDatabaseService.instance.getPendingEvents(kind: kind, limit: 50000);
    _pendingQueue.addAll(allPending);

    await _persistCalls();
    await _persistSms();
    await _persistWhatsApp();
    await _persistQueue();
    await refreshPendingCounts();

    if (kind == null || kind == 'call') {
      await syncAllCallHistoryToServer(force: true);
    }

    await syncNow(targetKind: kind, uploadRecordings: true);
  }

  /// Automatically pushes complete call history to the CRM server.
  /// Deduplicates on server so previously stored calls return 'duplicate' safely,
  /// guaranteeing that missing historical calls are fully populated on the CRM server.
  Future<void> syncAllCallHistoryToServer({bool force = false}) async {
    if (!_isPaired || _device == null) return;
    final prefs = await SharedPreferences.getInstance();
    final syncKey = 'mks_full_history_synced_${_device!.id}';
    final alreadyDone = prefs.getBool(syncKey) ?? false;
    if (alreadyDone && !force) {
      return;
    }

    try {
      _statusMessage = 'Syncing complete call history with CRM server...';
      notifyListeners();

      final allCalls = await LocalDatabaseService.instance.getEvents(kind: 'call', limit: 10000);
      final callsToUpload = allCalls.isNotEmpty ? allCalls : _calls;

      if (callsToUpload.isEmpty) {
        await prefs.setBool(syncKey, true);
        return;
      }

      const batchSize = 50;
      for (int i = 0; i < callsToUpload.length; i += batchSize) {
        final end = (i + batchSize < callsToUpload.length) ? i + batchSize : callsToUpload.length;
        final batch = callsToUpload.sublist(i, end);

        final res = await api.syncEvents(batch, health: _buildHealthPayload());
        if (res.success && res.data != null) {
          final stored = List<String>.from(res.data!['stored'] ?? []);
          final duplicate = List<String>.from(res.data!['duplicate'] ?? []);
          final skipped = (res.data!['skipped'] as List? ?? []).map((s) => s['uid']?.toString()).whereType<String>().toList();
          final finished = {...stored, ...duplicate, ...skipped}.toList();
          if (finished.isNotEmpty) {
            await LocalDatabaseService.instance.markEventsSynced(finished);
            for (final c in _calls) {
              if (finished.contains(c.uid)) c.syncStatus = 'synced';
            }
          }
        }
      }

      await prefs.setBool(syncKey, true);
      await refreshPendingCounts();
      _statusMessage = 'All call history synchronized with CRM';
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing all call history: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 6. HEARTBEAT LOOP & CRM COMMANDS
  // ---------------------------------------------------------------------------
  Timer? _periodicSyncTimer;
  Timer? _slowSensingTimer;

  // A quick check with the CRM every minute while the app is on screen, so a
  // phone revoked or deleted in the CRM unpairs within a minute.
  Timer? _quickCheckTimer;
  bool _foreground = true;

  /// The home screen says when the app comes to the screen or leaves it.
  void setForeground(bool value) {
    _foreground = value;
    if (value) {
      if (Platform.isIOS) {
        syncActiveWhatsAppNotifications();
        syncDeviceSms();
        syncDeviceCallLogs();
        scanLocalRecordings();
      }
      if (_isPaired) {
        sendHeartbeat();
      }
    }
  }

  void _startHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _quickCheckTimer?.cancel();

    // The first heartbeat goes now, not after the first interval: the CRM
    // shows this phone's health within seconds of pairing or opening the app.
    Future.microtask(() async {
      try {
        await sendHeartbeat();
      } catch (e) {
        debugPrint('First heartbeat failed: $e');
      }
    });

    _quickCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!_isPaired || !_foreground) return;
      try {
        // Light: the last known health, no new reads on the phone. A 401
        // (revoked, deleted) unpairs through the API client's watch.
        await api.sendHeartbeat(health: _buildHealthPayload());
      } catch (_) {}
    });
    _periodicSyncTimer?.cancel();
    final intervalMinutes = _config.syncMinutes > 0 ? _config.syncMinutes : 15;
    _heartbeatTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) async {
      await sendHeartbeat();
      await refreshPendingCounts();
      if (_pendingQueue.isNotEmpty || pendingEventsCount > 0 || _pendingRecordingsCount > 0) {
        await syncNow();
      }
    });

    // Lightweight sync queue flusher: uploads pending queue without hammering SQLite/ContentProviders
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isPaired && !_isSyncing) {
        await refreshPendingCounts();
        if (_pendingQueue.isNotEmpty || pendingEventsCount > 0 || _pendingRecordingsCount > 0) {
          await syncNow();
        }
      }
    });

    // Infrequent sensing check (every 10 minutes) as a fallback safety net only while in foreground
    _slowSensingTimer?.cancel();
    _slowSensingTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (!_foreground || !_isPaired || _isSyncing) return;
      try {
        if (hasCallLogPermission) await syncDeviceCallLogs();
        if (hasSmsPermission) await syncDeviceSms();
        await syncActiveWhatsAppNotifications();
        await refreshPendingCounts();
      } catch (_) {}
    });

    sendHeartbeat();
  }

  Map<String, dynamic> _buildHealthPayload() {
    final rawNet = _deviceInfo['network']?.toString().toLowerCase();
    final validNetwork = (rawNet == 'wifi' || rawNet == 'mobile' || rawNet == 'none')
        ? rawNet!
        : 'wifi';

    final isCharging = _deviceInfo['charging'] == true;
    final battery = (_deviceInfo['batteryPercent'] as num?)?.toInt() ?? _batteryPercent;
    final queue = pendingEventsCount > 0 ? pendingEventsCount : _pendingQueue.length;
    final recordingsQueue = _pendingRecordingsCount > 0 ? _pendingRecordingsCount : _localRecordings.length;

    return {
      'permissions': Map<String, bool>.from(_permissions),
      'battery': battery,
      'charging': isCharging,
      'queue': queue,
      'recordings_queue': recordingsQueue,
      'network': validNetwork,
    };
  }

  Future<void> sendHeartbeat() async {
    if (!_isPaired) return;
    await checkPermissions();
    await fetchPlatformDeviceInfo();
    await refreshPendingCounts();

    final health = _buildHealthPayload();

    final res = await api.sendHeartbeat(
      health: health,
      appVersion: _deviceInfo['app_version']?.toString() ?? SalesTrackApiService.currentAppVersion,
      osVersion: _deviceInfo['os_version']?.toString() ?? '14',
      manufacturer: _deviceInfo['manufacturer']?.toString(),
      model: _deviceInfo['model']?.toString(),
      sims: (_deviceInfo['sims'] as List?)?.whereType<Map<String, dynamic>>().toList(),
    );
    if (res.success && res.data != null) {
      final c = res.data!['config'];
      if (c is Map<String, dynamic>) {
        _config = SalesTrackConfig.fromJson(c);
      }

      // Check for app update requirements from heartbeat config
      if (res.data!['update_required'] == true) {
        _isUpdateMandatory = true;
        _availableUpdate = _config.appInfo.isNotEmpty
            ? _config.appInfo
            : AppUpdateInfo(
                latestVersion: _config.appMinVersion,
                minVersion: _config.appMinVersion,
                notes: 'Essential update required by CRM server.',
              );
      } else if (_config.appInfo.isNotEmpty) {
        final current = SalesTrackApiService.currentAppVersion;
        final isBelowMin = _config.appInfo.minVersion.isNotEmpty &&
            compareAppVersions(current, _config.appInfo.minVersion) < 0;
        final isBelowLatest = _config.appInfo.latestVersion.isNotEmpty &&
            compareAppVersions(current, _config.appInfo.latestVersion) < 0;

        if (isBelowMin) {
          _availableUpdate = _config.appInfo;
          _isUpdateMandatory = true;
        } else if (isBelowLatest && _availableUpdate == null) {
          _availableUpdate = _config.appInfo;
          _isUpdateMandatory = false;
        }
      }

      // Process CRM commands
      final commands = res.data!['commands'] as List? ?? [];
      for (final cmd in commands) {
        if (cmd is Map<String, dynamic>) {
          await _handleCrmCommand(cmd);
        }
      }
      notifyListeners();
    } else if (_isPairingLost(res)) {
      await _handlePairingLost(res.error ?? 'device_revoked');
    } else if (_isUpdateRequired(res)) {
      _isUpdateMandatory = true;
      _availableUpdate ??= AppUpdateInfo(
        latestVersion: _config.appMinVersion,
        minVersion: _config.appMinVersion,
        notes: 'Required app update needed to communicate with CRM server.',
      );
      notifyListeners();
    }
  }

  Future<void> _handleCrmCommand(Map<String, dynamic> cmd) async {
    final type = cmd['type']?.toString();
    final id = cmd['id']?.toString() ?? '';

    if (type == 'sync_now') {
      await syncAllLocalAndRemote();
      await api.sendHeartbeat(
        health: _buildHealthPayload(),
        acks: [{'id': id, 'status': 'done'}],
      );
    } else if (type == 'recheck_permissions') {
      await checkPermissions();
      await api.sendHeartbeat(
        health: _buildHealthPayload(),
        acks: [{'id': id, 'status': 'done'}],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 7. AFTER-CALL OUTCOMES
  // ---------------------------------------------------------------------------
  Future<bool> submitCallOutcome({
    required String uid,
    required String outcomeKey,
    String? note,
    DateTime? followUpDate,
    int? leadStatus,
    String? createLeadName,
  }) async {
    // If a custom lead name was specified, update local call records immediately
    if (createLeadName != null && createLeadName.trim().isNotEmpty) {
      final cleanName = createLeadName.trim();
      final idx = _calls.indexWhere((c) => c.uid == uid);
      if (idx >= 0) {
        _calls[idx].name = cleanName;
        _calls[idx].syncStatus = 'pending';
        LocalDatabaseService.instance.saveEvents([_calls[idx]]);
        _pendingUids.remove(uid);
        _enqueueEvent(_calls[idx]);
      }
    }

    final submission = OutcomeSubmission(
      uid: uid,
      outcome: outcomeKey,
      note: note,
      followUpAt: followUpDate?.millisecondsSinceEpoch,
      leadStatus: leadStatus,
      createLead: (createLeadName != null && createLeadName.isNotEmpty) ? {'name': createLeadName} : null,
    );

    // Save to local SQLite database so caller lookup and offline history are immediately updated
    await LocalDatabaseService.instance.saveOutcome(submission);

    // Guarantee the base call is synced to server
    SalesTrackEvent? callEvent;
    for (final c in _calls) {
      if (c.uid == uid) {
        callEvent = c;
        break;
      }
    }
    if (callEvent == null) {
      for (final w in _whatsappEvents) {
        if (w.uid == uid) {
          callEvent = w;
          break;
        }
      }
    }
    if (callEvent != null) {
      ensureCallSyncedToServer(callEvent);
    }

    _activeAfterCallEvent = null;
    notifyListeners();

    final res = await api.submitOutcomes([submission]);
    if (res.success) {
      await LocalDatabaseService.instance.markOutcomesSynced([uid]);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // 8. CALL LISTS
  // ---------------------------------------------------------------------------
  Future<void> fetchCallLists() async {
    final res = await api.fetchLists();
    if (res.success && res.data != null) {
      _callLists.clear();
      _callLists.addAll(res.data!);
      if (_callLists.isEmpty) {
        _populateDefaultCallListFromLeads();
      }
      notifyListeners();
    } else if (_isPairingLost(res)) {
      await _handlePairingLost(res.error ?? 'device_revoked');
    } else if (_callLists.isEmpty) {
      _populateDefaultCallListFromLeads();
      notifyListeners();
    }
  }

  void _populateDefaultCallListFromLeads() {
    final leadMap = <String, String>{};
    for (final c in _calls) {
      final num = c.number.trim();
      if (num.isNotEmpty && !leadMap.containsKey(num)) {
        leadMap[num] = c.name.isNotEmpty ? c.name : num;
      }
    }
    for (final s in _smsList) {
      final num = s.number.trim();
      if (num.isNotEmpty && !leadMap.containsKey(num)) {
        leadMap[num] = s.name.isNotEmpty ? s.name : num;
      }
    }

    if (leadMap.isNotEmpty) {
      final items = leadMap.entries.take(25).map((entry) {
        return CallListItem(
          leadId: entry.key.hashCode.abs(),
          name: entry.value,
          company: 'Makes360 CRM Lead',
          number: entry.key,
          status: 'Active',
          state: 'pending',
          doNotCall: false,
        );
      }).toList();

      _callLists.add(CallListModel(
        id: 1,
        name: 'Priority CRM Outreach Leads (${items.length})',
        due: 'Today',
        items: items,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // 9. NATIVE AUDIO PLAYER
  // ---------------------------------------------------------------------------
  Future<void> playRecording(String path) async {
    try {
      _isPlayingAudio = true;
      _activeAudioPath = path;
      notifyListeners();

      final res = await _platform.invokeMapMethod<String, dynamic>('playAudio', {'path': path});
      _audioDurationMs = (res?['durationMs'] as num?)?.toInt() ?? 0;

      _startAudioPolling();
    } catch (e) {
      _isPlayingAudio = false;
      notifyListeners();
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _platform.invokeMethod('pauseAudio');
      _isPlayingAudio = false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resumeRecording() async {
    try {
      await _platform.invokeMethod('resumeAudio');
      _isPlayingAudio = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopRecording() async {
    try {
      await _platform.invokeMethod('stopAudio');
      _isPlayingAudio = false;
      _activeAudioPath = null;
      _audioPollTimer?.cancel();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> seekRecording(int positionMs) async {
    try {
      await _platform.invokeMethod('seekAudio', {'positionMs': positionMs});
      _audioCurrentPosMs = positionMs;
      notifyListeners();
    } catch (_) {}
  }

  void _startAudioPolling() {
    _audioPollTimer?.cancel();
    _audioPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final state = await _platform.invokeMapMethod<String, dynamic>('getAudioState');
        if (state != null) {
          _isPlayingAudio = state['isPlaying'] == true;
          _audioCurrentPosMs = (state['positionMs'] as num?)?.toInt() ?? 0;
          final activePath = state['activePath']?.toString() ?? '';
          if (activePath.isEmpty || (!_isPlayingAudio && _audioCurrentPosMs >= _audioDurationMs && _audioDurationMs > 0)) {
            _isPlayingAudio = false;
            _activeAudioPath = null;
            _audioCurrentPosMs = 0;
            _audioPollTimer?.cancel();
          }
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  // ---------------------------------------------------------------------------
  // 10. LOCAL-FIRST PERSISTENCE (Offline Caching & Queue)
  // ---------------------------------------------------------------------------
  Future<void> _persistMeta() async {
    final prefs = await SharedPreferences.getInstance();
    if (_device != null) prefs.setString('mks_crm_device', jsonEncode(_device!.toJson()));
    if (_staff != null) prefs.setString('mks_crm_staff', jsonEncode(_staff!.toJson()));
    prefs.setString('mks_crm_config', jsonEncode(_config.toJson()));
  }

  Future<void> _loadSavedMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final dStr = prefs.getString('mks_crm_device');
    final sStr = prefs.getString('mks_crm_staff');
    final cStr = prefs.getString('mks_crm_config');
    if (dStr != null) _device = CrmDevice.fromJson(jsonDecode(dStr));
    if (sStr != null) _staff = CrmStaff.fromJson(jsonDecode(sStr));
    if (cStr != null) _config = SalesTrackConfig.fromJson(jsonDecode(cStr));

    if (_device == null && _isPaired && defaultTargetPlatform == TargetPlatform.iOS) {
      _device = CrmDevice(
        id: 26,
        name: 'iphone-14 office',
        description: '',
        platform: 'ios',
        status: 'active',
        trackSim: 0,
      );
      _staff = CrmStaff(id: 1, name: 'Makes360 Sales');
    }
  }

  Future<void> _persistCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _calls.take(100).map((e) => jsonEncode(e.toStorageJson())).toList();
    await prefs.setStringList('mks_cached_calls', list);
  }

  Future<void> _persistSms() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _smsList.take(100).map((e) => jsonEncode(e.toStorageJson())).toList();
    await prefs.setStringList('mks_cached_sms', list);
  }

  Future<void> _persistWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _whatsappEvents.take(100).map((e) => jsonEncode(e.toStorageJson())).toList();
    await prefs.setStringList('mks_cached_whatsapp', list);
  }

  Future<void> _persistRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _localRecordings.take(100).map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('mks_cached_recordings', list);
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _pendingQueue.take(50).map((e) => jsonEncode(e.toStorageJson())).toList();
      await prefs.setStringList('mks_pending_queue', list);
    } catch (_) {}
  }

  Future<void> refreshPendingCounts() async {
    try {
      final counts = await LocalDatabaseService.instance.getPendingCounts();
      _pendingCallsCount = counts['pendingCalls'] ?? 0;
      _pendingSmsCount = counts['pendingSms'] ?? 0;
      _pendingWhatsAppCount = counts['pendingWhatsApp'] ?? 0;
      _pendingRecordingsCount = counts['pendingRecordings'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadPersistedHistory() async {
    // 1. Try loading from SQLite first (Offline-First source of truth)
    try {
      _updateInitProgress(0.50, 'Loading local call records...');
      final dbCalls = await LocalDatabaseService.instance.getEvents(kind: 'call', limit: 3000);

      _updateInitProgress(0.62, 'Loading WhatsApp conversations...');
      final dbWa = await LocalDatabaseService.instance.getEvents(kind: 'whatsapp', limit: 1000);

      _updateInitProgress(0.74, 'Loading SMS messages...');
      final dbSms = await LocalDatabaseService.instance.getEvents(kind: 'sms', limit: 1500);

      _updateInitProgress(0.84, 'Loading pending sync items...');
      final pendingFromDb = await LocalDatabaseService.instance.getPendingEvents(limit: 5000);
      pendingFromDb.removeWhere((e) => isMessageCountSummary(e.text) || isMessageCountSummary(e.name));

      if (dbCalls.isNotEmpty || dbWa.isNotEmpty || dbSms.isNotEmpty) {
        _calls.clear();
        _calls.addAll(dbCalls);
        _whatsappEvents.clear();
        _whatsappEvents.addAll(dbWa);
        _smsList.clear();
        _smsList.addAll(dbSms);

        _pendingQueue.clear();
        _pendingQueue.addAll(pendingFromDb);
        _pendingUids.clear();
        _pendingUids.addAll(pendingFromDb.map((e) => e.uid).where((u) => u.isNotEmpty));
        if (_calls.isNotEmpty && _whatsappEvents.isNotEmpty && _smsList.isNotEmpty) {
          return;
        }
      }
    } catch (e) {
      debugPrint('SQLite initial read error: $e');
    }

    // 2. Migration fallback from SharedPreferences if SQLite was freshly initialized or missing items
    final prefs = await SharedPreferences.getInstance();

    if (_calls.isEmpty) {
      _updateInitProgress(0.54, 'Reading cached calls...');
      final cachedCalls = prefs.getStringList('mks_cached_calls') ?? [];
      final tempCalls = <SalesTrackEvent>[];
      for (final str in cachedCalls) {
        try {
          tempCalls.add(SalesTrackEvent.fromJson(jsonDecode(str)));
        } catch (_) {}
      }
      _calls.clear();
      _calls.addAll(dedupCallsList(tempCalls));
      if (_calls.isNotEmpty) {
        await LocalDatabaseService.instance.saveEvents(_calls);
      }
    }

    if (_smsList.isEmpty) {
      _updateInitProgress(0.76, 'Reading cached SMS...');
      final cachedSms = prefs.getStringList('mks_cached_sms') ?? [];
      for (final str in cachedSms) {
        try {
          _smsList.add(SalesTrackEvent.fromJson(jsonDecode(str)));
        } catch (_) {}
      }
      if (_smsList.isNotEmpty) {
        await LocalDatabaseService.instance.saveEvents(_smsList);
      }
    }

    if (_whatsappEvents.isEmpty) {
      _updateInitProgress(0.66, 'Reading cached WhatsApp...');
      final cachedWa = prefs.getStringList('mks_cached_whatsapp') ?? [];
      for (final str in cachedWa) {
        try {
          _whatsappEvents.add(SalesTrackEvent.fromJson(jsonDecode(str)));
        } catch (_) {}
      }
      if (_whatsappEvents.isNotEmpty) {
        await LocalDatabaseService.instance.saveEvents(_whatsappEvents);
      }
    }

    final cachedRecs = prefs.getStringList('mks_cached_recordings') ?? [];
    _localRecordings.clear();
    for (final str in cachedRecs) {
      try {
        _localRecordings.add(Map<String, dynamic>.from(jsonDecode(str)));
      } catch (_) {}
    }

    final queueList = prefs.getStringList('mks_pending_queue') ?? [];
    _pendingQueue.clear();
    _pendingUids.clear();
    for (final str in queueList) {
      try {
        final ev = SalesTrackEvent.fromJson(jsonDecode(str));
        _pendingQueue.add(ev);
        if (ev.uid.isNotEmpty) _pendingUids.add(ev.uid);
      } catch (_) {}
    }
  }

  Future<void> clearLocalDataAndRescan() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncProgress = 0.05;
    _syncProgressMessage = 'Clearing local cache & rescanning phone...';
    _statusMessage = 'Clearing local cache...';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mks_cached_calls');
      await prefs.remove('mks_cached_sms');
      await prefs.remove('mks_cached_whatsapp');
      await prefs.remove('mks_cached_recordings');
      await prefs.remove('mks_pending_queue');
      _calls.clear();
      _smsList.clear();
      _whatsappEvents.clear();
      _localRecordings.clear();
      _pendingQueue.clear();
      _pendingUids.clear();
      notifyListeners();

      // Now rescan fresh from phone dialer and media storage
      _syncProgress = 0.20;
      _syncProgressMessage = 'Rescanning calls from phone dialer...';
      notifyListeners();
      await syncDeviceCallLogs();

      _syncProgress = 0.50;
      _syncProgressMessage = 'Rescanning SMS messages...';
      notifyListeners();
      await syncDeviceSms();

      _syncProgress = 0.70;
      _syncProgressMessage = 'Scanning call audio recordings...';
      notifyListeners();
      await scanLocalRecordings();

      _syncProgress = 0.85;
      _syncProgressMessage = 'Checking WhatsApp notifications...';
      notifyListeners();
      await syncActiveWhatsAppNotifications();
      await syncServerEvents();

      _statusMessage = 'Refreshed ${_calls.length} calls & ${_localRecordings.length} recordings';
      _syncProgress = 1.0;
      _syncProgressMessage = 'Rescan Complete';
    } catch (e) {
      debugPrint('Error during clearLocalDataAndRescan: $e');
      _statusMessage = 'Error during rescan: $e';
    } finally {
      _isSyncing = false;
      await refreshPendingCounts();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _iosLivePollingTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _slowSensingTimer?.cancel();
    _eventSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _quickCheckTimer?.cancel();
    _audioPollTimer?.cancel();
    super.dispose();
  }
}
