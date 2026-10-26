import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_record.dart';
import '../models/lead_contact.dart';
import '../services/cloud_sync_service.dart';

class CallRepository {
  final CloudSyncService _cloudSyncService;
  static const String _localStorageKey = 'ringvia360_saved_calls_v2';
  final StreamController<List<CallRecord>> _callsStreamController =
      StreamController<List<CallRecord>>.broadcast();

  Stream<List<CallRecord>> get callsStream => _callsStreamController.stream;

  CallRepository({required CloudSyncService cloudSyncService})
      : _cloudSyncService = cloudSyncService {
    _initLocalStorage();
  }

  final List<CallRecord> _cachedCalls = [];

  final List<LeadContact> _mockContacts = const [];

  Future<void> _initLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_localStorageKey);
      if (storedJson != null && storedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(storedJson);
        final List<CallRecord> storedCalls = [];
        for (final item in decoded) {
          try {
            storedCalls.add(CallRecord.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
        final cleanStored = storedCalls.where((c) =>
            !c.id.startsWith('call-10') &&
            c.contactName != 'Aarav Sharma' &&
            c.contactName != 'Priya Patel' &&
            !(c.recordingPath != null && c.recordingPath!.contains('mixkit.co'))
        ).toList();

        if (cleanStored.isNotEmpty) {
          final storedIds = cleanStored.map((c) => c.id).toSet();
          final uniqueCached = _cachedCalls.where((c) => !storedIds.contains(c.id)).toList();
          _cachedCalls.clear();
          _cachedCalls.addAll([...cleanStored, ...uniqueCached]);
          _cachedCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _callsStreamController.add(List.unmodifiable(_cachedCalls));
        } else {
          _cachedCalls.clear();
          _callsStreamController.add(List.unmodifiable(_cachedCalls));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _cachedCalls.map((c) => c.toJson()).toList();
      await prefs.setString(_localStorageKey, jsonEncode(listMap));
    } catch (_) {}
  }

  Future<List<CallRecord>> getCalls() async {
    await _initLocalStorage();

    try {
      final cloudCalls = await _cloudSyncService.fetchCallsFromCloud();
      final cleanCloud = cloudCalls.where((c) =>
          !c.id.startsWith('call-10') &&
          c.contactName != 'Aarav Sharma' &&
          c.contactName != 'Priya Patel' &&
          !(c.recordingPath != null && c.recordingPath!.contains('mixkit.co'))
      ).toList();
      if (cleanCloud.isNotEmpty) {
        _cachedCalls.clear();
        _cachedCalls.addAll(cleanCloud);
        _cachedCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        await _saveToLocalStorage();
        _callsStreamController.add(List.unmodifiable(_cachedCalls));
      }
    } catch (_) {}
    return List.unmodifiable(_cachedCalls);
  }

  Future<void> addCall(CallRecord call) async {
    final callWithRecording = call;

    // 1. Immediately insert into local memory list
    _cachedCalls.removeWhere((c) => c.id == callWithRecording.id);
    _cachedCalls.insert(0, callWithRecording);

    // 2. Persist to local database (SharedPreferences)
    await _saveToLocalStorage();

    // 3. Emit real-time stream event to update Feed View
    _callsStreamController.add(List.unmodifiable(_cachedCalls));

    // 4. Background push to cloud API
    await _syncCall(callWithRecording);
  }

  Future<void> _syncCall(CallRecord call) async {
    try {
      final res = await _cloudSyncService.syncCallToCloud(call);
      if (res.success) {
        final index = _cachedCalls.indexWhere((c) => c.id == call.id);
        if (index != -1) {
          _cachedCalls[index] = _cachedCalls[index].copyWith(
            crmSyncStatus: CrmSyncStatus.synced,
            recordingPath: (res.recordingUrl != null && res.recordingUrl!.isNotEmpty && !res.recordingUrl!.contains('mixkit'))
                ? res.recordingUrl
                : _cachedCalls[index].recordingPath,
          );
          await _saveToLocalStorage();
          _callsStreamController.add(List.unmodifiable(_cachedCalls));
        }
      }
    } catch (_) {}
  }

  /// Uploads a local audio file to the server immediately and returns the
  /// hosted URL, or null if upload failed.
  Future<String?> uploadRecording(String callId, String localFilePath) async {
    return _cloudSyncService.uploadAudioFile(localFilePath, callId);
  }

  Future<List<LeadContact>> searchContacts(String query) async {
    final List<LeadContact> allContacts = List.of(_mockContacts);
    try {
      final cloudLeads = await _cloudSyncService.fetchLeadsFromCloud();
      if (cloudLeads.isNotEmpty) {
        final existingIds = allContacts.map((c) => c.id).toSet();
        for (final l in cloudLeads) {
          if (!existingIds.contains(l.id)) {
            allContacts.add(l);
          }
        }
      }
    } catch (_) {}

    if (query.isEmpty) return allContacts;
    final clean = query.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();

    return allContacts.where((c) {
      final cleanPhone = c.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return c.name.toLowerCase().contains(query.toLowerCase()) ||
          c.company.toLowerCase().contains(query.toLowerCase()) ||
          cleanPhone.contains(clean);
    }).toList();
  }
}
