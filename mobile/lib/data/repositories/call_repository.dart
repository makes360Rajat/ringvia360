import 'dart:async';
import '../models/call_record.dart';
import '../models/lead_contact.dart';
import '../services/cloud_sync_service.dart';

class CallRepository {
  final CloudSyncService _cloudSyncService;

  CallRepository({required CloudSyncService cloudSyncService})
      : _cloudSyncService = cloudSyncService;

  final List<CallRecord> _cachedCalls = [
    CallRecord(
      id: 'call-101',
      contactName: 'Aarav Sharma',
      phoneNumber: '+91 98201 43210',
      company: 'Tata Consultancy Services',
      direction: CallDirection.outbound,
      durationSeconds: 384,
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      outcome: 'Demo Completed - Contract Requested',
      notes: 'Decision maker confirmed budget for 50 licenses. Requested RingVia360 field mapping.',
      sentiment: SentimentScore.positive,
      dealValue: 48000,
      dealStage: 'Proposal / Review',
      crmSyncStatus: CrmSyncStatus.synced,
      crmType: 'RingVia360',
      simSlot: 'SIM 1 (Corporate)',
      isEncrypted: true,
      recordingPath: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      keyActionItems: [
        'Send Docusign MSA for 50 licenses',
        'Schedule kickoff call with IT Director'
      ],
    ),
    CallRecord(
      id: 'call-102',
      contactName: 'Priya Patel',
      phoneNumber: '+91 98450 12890',
      company: 'Infosys Technologies',
      direction: CallDirection.inbound,
      durationSeconds: 512,
      timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
      outcome: 'Technical Validation Passed',
      notes: 'Client tested inbound call capture on Samsung Knox devices with zero battery impact.',
      sentiment: SentimentScore.positive,
      dealValue: 72000,
      dealStage: 'Technical Validation',
      crmSyncStatus: CrmSyncStatus.synced,
      crmType: 'RingVia360',
      simSlot: 'SIM 1 (Corporate)',
      isEncrypted: true,
      recordingPath: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      keyActionItems: [
        'Email Knox MDM deployment guide'
      ],
    ),
    CallRecord(
      id: 'call-103',
      contactName: 'Vikram Malhotra',
      phoneNumber: '+91 97110 56789',
      company: 'Wipro Enterprises',
      direction: CallDirection.missed,
      durationSeconds: 0,
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 12)),
      outcome: 'Missed Call - Auto Follow-up Dispatched',
      notes: 'Auto-responder dispatched instant WhatsApp template with meeting link.',
      sentiment: SentimentScore.neutral,
      dealValue: 15000,
      dealStage: 'Discovery',
      crmSyncStatus: CrmSyncStatus.synced,
      crmType: 'RingVia360',
      simSlot: 'SIM 1 (Corporate)',
      isEncrypted: true,
      recordingPath: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      keyActionItems: [
        'Check if client booked calendar slot'
      ],
    ),
    CallRecord(
      id: 'call-104',
      contactName: 'Ananya Iyer',
      phoneNumber: '+91 99001 77654',
      company: 'HDFC Bank Corporate',
      direction: CallDirection.outbound,
      durationSeconds: 215,
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      outcome: 'Follow-up Scheduled',
      notes: 'Spoke with Ananya. Reviewed banking compliance and Knox E2EE isolation.',
      sentiment: SentimentScore.neutral,
      dealValue: 24000,
      dealStage: 'Evaluation',
      crmSyncStatus: CrmSyncStatus.synced,
      crmType: 'RingVia360',
      simSlot: 'SIM 1 (Corporate)',
      isEncrypted: true,
      recordingPath: 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      keyActionItems: [
        'Send RingVia360 security battlecard'
      ],
    ),
  ];

  final List<LeadContact> _mockContacts = const [
    LeadContact(
      id: 'c-1',
      name: 'Aarav Sharma',
      phoneNumber: '+919820143210',
      company: 'Tata Consultancy Services',
      title: 'VP of Enterprise Sales',
      openDealValue: 48000,
      lastContacted: '8m ago',
      crmAccountId: 'rv360-001',
    ),
    LeadContact(
      id: 'c-2',
      name: 'Priya Patel',
      phoneNumber: '+919845012890',
      company: 'Infosys Technologies',
      title: 'Chief Technology Officer',
      openDealValue: 72000,
      lastContacted: '35m ago',
      crmAccountId: 'rv360-002',
    ),
    LeadContact(
      id: 'c-3',
      name: 'Vikram Malhotra',
      phoneNumber: '+919711056789',
      company: 'Wipro Enterprises',
      title: 'Head of Cloud Infrastructure',
      openDealValue: 15000,
      lastContacted: '1h ago',
      crmAccountId: 'rv360-003',
    ),
    LeadContact(
      id: 'c-4',
      name: 'Ananya Iyer',
      phoneNumber: '+919900177654',
      company: 'HDFC Bank Corporate',
      title: 'Director of Procurement',
      openDealValue: 24000,
      lastContacted: '2h ago',
      crmAccountId: 'rv360-004',
    ),
    LeadContact(
      id: 'c-5',
      name: 'Rohan Mehta',
      phoneNumber: '+919819023456',
      company: 'Razorpay Software',
      title: 'Managing Director',
      openDealValue: 36000,
      lastContacted: 'Yesterday',
      crmAccountId: 'rv360-005',
    ),
  ];

  Future<List<CallRecord>> getCalls() async {
    try {
      final cloudCalls = await _cloudSyncService.fetchCallsFromCloud();
      if (cloudCalls.isNotEmpty) {
        final cloudIds = cloudCalls.map((c) => c.id).toSet();
        final localOnly = _cachedCalls.where((c) => !cloudIds.contains(c.id)).toList();
        _cachedCalls.clear();
        _cachedCalls.addAll([...localOnly, ...cloudCalls]);
        _cachedCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (_) {}
    return List.unmodifiable(_cachedCalls);
  }

  Future<void> addCall(CallRecord call) async {
    final callWithRecording = call.copyWith(
      recordingPath: (call.recordingPath != null && call.recordingPath!.isNotEmpty)
          ? call.recordingPath
          : 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
    );
    _cachedCalls.insert(0, callWithRecording);

    // Auto sync to cloud
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
          );
        }
      }
    } catch (_) {}
  }

  Future<List<LeadContact>> searchContacts(String query) async {
    if (query.isEmpty) return _mockContacts;
    final clean = query.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();

    return _mockContacts.where((c) {
      final cleanPhone = c.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return c.name.toLowerCase().contains(query.toLowerCase()) ||
          c.company.toLowerCase().contains(query.toLowerCase()) ||
          cleanPhone.contains(clean);
    }).toList();
  }
}
