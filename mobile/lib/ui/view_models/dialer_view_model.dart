import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/call_record.dart';
import '../../data/models/lead_contact.dart';
import '../../data/models/sim_config.dart';
import '../../data/services/telephony_service.dart';
import '../../data/services/audio_recorder_service.dart';
import '../../data/repositories/call_repository.dart';

class DialerViewModel extends ChangeNotifier {
  final TelephonyService _telephonyService;
  final CallRepository _callRepository;
  final AudioRecorderService _audioRecorderService;

  DialerViewModel({
    required TelephonyService telephonyService,
    required CallRepository callRepository,
    AudioRecorderService? audioRecorderService,
  })  : _telephonyService = telephonyService,
        _callRepository = callRepository,
        _audioRecorderService = audioRecorderService ?? AudioRecorderService() {
    _initTelephonyListener();
  }

  String _inputNumber = '';
  String get inputNumber => _inputNumber;
  String get dialedNumber => _inputNumber;

  List<LeadContact> _matchingContacts = [];
  List<LeadContact> get matchingContacts => _matchingContacts;

  SimConfig _selectedSim = const SimConfig(
    slotId: 'SIM 1',
    label: 'SIM 1 (Work Corporate)',
    carrier: 'Airtel Enterprise (SIM 1)',
    phoneNumber: '+91 98200 11223',
    isTracked: true,
    isCorporate: true,
  );
  SimConfig get selectedSim => _selectedSim;

  WorkHoursSchedule _schedule = const WorkHoursSchedule(isEnforced: false);
  WorkHoursSchedule get schedule => _schedule;

  // In-call active state
  bool _isInCall = false;
  bool get isInCall => _isInCall;
  String? _currentCallId;

  int _callDurationSeconds = 0;
  int get callDurationSeconds => _callDurationSeconds;

  String _activeContactName = 'Lead Contact';
  String get activeContactName => _activeContactName;

  String _activeCompany = 'Enterprise';
  String get activeCompany => _activeCompany;

  CallDirection _activeDirection = CallDirection.outbound;
  CallDirection get activeDirection => _activeDirection;

  // Inbound ringing state
  bool _isIncomingCallRinging = false;
  bool get isIncomingCallRinging => _isIncomingCallRinging;

  TelephonyEvent? _activeIncomingEvent;
  TelephonyEvent? get activeIncomingEvent => _activeIncomingEvent;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  // Post-call wrap-up trigger
  CallRecord? _wrapUpCall;
  CallRecord? get wrapUpCall => _wrapUpCall;

  StreamSubscription<TelephonyEvent>? _sub;

  void _initTelephonyListener() {
    _sub = _telephonyService.onCallEvent.listen((event) {
      if (event.state == TelephonyState.ringing) {
        _isIncomingCallRinging = true;
        _activeIncomingEvent = event;
        _activeContactName = event.contactName;
        _activeCompany = event.company;
        _activeDirection = CallDirection.inbound;
        notifyListeners();
      } else if (event.state == TelephonyState.connected) {
        _isIncomingCallRinging = false;
        _isInCall = true;
        _callDurationSeconds = event.durationSeconds;
        notifyListeners();
      } else if (event.state == TelephonyState.disconnected) {
        _isIncomingCallRinging = false;
        _isInCall = false;
        notifyListeners();
      }
    });
  }

  void appendDigit(String digit) {
    _inputNumber += digit;
    _searchContacts();
    notifyListeners();
  }

  void deleteDigit() {
    if (_inputNumber.isNotEmpty) {
      _inputNumber = _inputNumber.substring(0, _inputNumber.length - 1);
      _searchContacts();
      notifyListeners();
    }
  }

  void clearNumber() {
    _inputNumber = '';
    _matchingContacts = [];
    notifyListeners();
  }

  void selectContact(LeadContact contact) {
    _inputNumber = contact.phoneNumber;
    _activeContactName = contact.name;
    _activeCompany = contact.company;
    notifyListeners();
  }

  void toggleSim() {
    if (_selectedSim.slotId == 'SIM 1') {
      _selectedSim = const SimConfig(
        slotId: 'SIM 2',
        label: 'SIM 2 (Personal Line)',
        carrier: 'Jio Personal (SIM 2)',
        phoneNumber: '+91 98200 99887',
        isTracked: false,
        isCorporate: false,
      );
    } else {
      _selectedSim = const SimConfig(
        slotId: 'SIM 1',
        label: 'SIM 1 (Work Corporate)',
        carrier: 'Airtel Enterprise (SIM 1)',
        phoneNumber: '+91 98200 11223',
        isTracked: true,
        isCorporate: true,
      );
    }
    _telephonyService.setActiveSim(_selectedSim);
    notifyListeners();
  }

  void setSchedule(WorkHoursSchedule newSchedule) {
    _schedule = newSchedule;
    notifyListeners();
  }

  Future<void> _searchContacts() async {
    _matchingContacts = await _callRepository.searchContacts(_inputNumber);
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  Future<void> launchNativeDialer([String? targetNumber]) async {
    final numToCall = targetNumber ?? (_inputNumber.isNotEmpty ? _inputNumber : '+14158902341');
    final clean = numToCall.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> startCall([LeadContact? contact, bool launchNative = true]) async {
    final number = contact?.phoneNumber ?? (_inputNumber.isEmpty ? '+91 98201 43210' : _inputNumber);
    _activeContactName = contact?.name ?? (_inputNumber.isNotEmpty ? _inputNumber : 'Corporate Contact');
    _activeCompany = contact?.company ?? 'Tata Consultancy Services';
    _activeDirection = CallDirection.outbound;

    _isInCall = true;
    _isIncomingCallRinging = false;
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeakerOn = false;

    _currentCallId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _audioRecorderService.startRecording(callId: _currentCallId!);

    _telephonyService.startOutboundCall(
      phoneNumber: number,
      contactName: _activeContactName,
      company: _activeCompany,
      schedule: _schedule,
    );

    notifyListeners();

    if (launchNative) {
      try {
        await launchNativeDialer(number);
      } catch (_) {}
    }
  }

  void triggerIncomingCallSim([LeadContact? contact]) {
    final contactToCall = contact ?? const LeadContact(
      id: 'lead-inbound-1',
      name: 'Priya Patel',
      phoneNumber: '+91 98450 12890',
      company: 'Infosys Technologies',
      title: 'Head of Enterprise Procurement',
      openDealValue: 72000,
      lastContacted: '18m ago',
      crmAccountId: 'rv360-00921',
    );

    _activeContactName = contactToCall.name;
    _activeCompany = contactToCall.company;
    _inputNumber = contactToCall.phoneNumber;
    _activeDirection = CallDirection.inbound;
    _isIncomingCallRinging = true;

    _telephonyService.simulateInboundRinging(
      phoneNumber: contactToCall.phoneNumber,
      contactName: contactToCall.name,
      company: contactToCall.company,
      schedule: _schedule,
    );

    notifyListeners();
  }

  void answerIncomingCall() {
    final number = _activeIncomingEvent?.phoneNumber ?? (_inputNumber.isEmpty ? '+91 98450 12890' : _inputNumber);
    _isIncomingCallRinging = false;
    _isInCall = true;
    _callDurationSeconds = 0;
    _activeDirection = CallDirection.inbound;

    _currentCallId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _audioRecorderService.startRecording(callId: _currentCallId!);

    _telephonyService.answerInboundCall(
      phoneNumber: number,
      contactName: _activeContactName,
      company: _activeCompany,
      schedule: _schedule,
    );

    notifyListeners();
  }

  void declineIncomingCall() {
    final number = _activeIncomingEvent?.phoneNumber ?? (_inputNumber.isEmpty ? '+91 98450 12890' : _inputNumber);
    final event = _telephonyService.rejectInboundCall(
      phoneNumber: number,
      contactName: _activeContactName,
      company: _activeCompany,
      schedule: _schedule,
    );

    _isIncomingCallRinging = false;
    _isInCall = false;

    // Open post-call wrap-up immediately for missed/declined inbound call
    _wrapUpCall = CallRecord(
      id: 'call-${DateTime.now().millisecondsSinceEpoch}',
      contactName: _activeContactName.isNotEmpty ? _activeContactName : number,
      phoneNumber: event.phoneNumber.isNotEmpty ? event.phoneNumber : number,
      company: _activeCompany,
      direction: CallDirection.inbound,
      durationSeconds: 0,
      timestamp: DateTime.now(),
      outcome: 'Missed Inbound Call - Follow-up Needed',
      notes: 'Inbound call arrived from customer ($number). Urgent callback requested.',
      sentiment: SentimentScore.neutral,
      dealValue: 72000,
      dealStage: 'Technical Validation',
      crmSyncStatus: CrmSyncStatus.pending,
      crmType: 'RingVia360',
      simSlot: _selectedSim.label,
      isEncrypted: true,
      recordingPath: null,
      keyActionItems: [
        'Immediate callback via corporate line',
        'Send automated SMS / WhatsApp apology'
      ],
    );

    notifyListeners();
  }

  void endCall() {
    final number = _inputNumber.isEmpty ? '+91 98201 43210' : _inputNumber;
    final event = _telephonyService.endCurrentCall(
      phoneNumber: number,
      contactName: _activeContactName,
      company: _activeCompany,
      direction: _activeDirection,
      schedule: _schedule,
    );

    _isInCall = false;
    _isIncomingCallRinging = false;

    final callId = _currentCallId ?? 'call-${DateTime.now().millisecondsSinceEpoch}';
    final duration = event.durationSeconds > 0 ? event.durationSeconds : (_callDurationSeconds > 0 ? _callDurationSeconds : 52);
    final recordingResult = _audioRecorderService.stopRecording(callId: callId, durationSeconds: duration);
    _currentCallId = null;

    final initialCallRecord = CallRecord(
      id: callId,
      contactName: _activeContactName.isNotEmpty ? _activeContactName : number,
      phoneNumber: event.phoneNumber.isNotEmpty ? event.phoneNumber : number,
      company: _activeCompany,
      direction: _activeDirection,
      durationSeconds: duration,
      timestamp: DateTime.now(),
      outcome: _activeDirection == CallDirection.inbound
          ? 'Inbound Call Completed - Inquiry Solved'
          : 'Demo Completed - Follow-up Set',
      notes: _activeDirection == CallDirection.inbound
          ? 'Customer called regarding product rollout. Walked through mobile app deployment.'
          : 'Spoke with key stakeholder ($number). Reviewed RingVia360 features.',
      sentiment: SentimentScore.positive,
      dealValue: _activeDirection == CallDirection.inbound ? 72000 : 25000,
      dealStage: _activeDirection == CallDirection.inbound ? 'Technical Validation' : 'Proposal',
      crmSyncStatus: CrmSyncStatus.pending,
      crmType: 'RingVia360',
      simSlot: _selectedSim.label,
      isEncrypted: true,
      recordingPath: recordingResult.cloudRecordingUrl,
      keyActionItems: [
        'Send follow-up recap email',
        'Provision trial access in CRM'
      ],
    );

    // 1. Immediately persist to local DB & stream to feed when recording stops
    _callRepository.addCall(initialCallRecord);

    // 2. Prompt Post-Call Wrap-up tracker for user edits if desired
    _wrapUpCall = initialCallRecord;

    notifyListeners();
  }

  void dismissWrapUp() {
    _wrapUpCall = null;
    notifyListeners();
  }

  Future<void> submitWrapUp({
    required String outcome,
    required String notes,
    required SentimentScore sentiment,
    required double dealValue,
    required String crmType,
  }) async {
    if (_wrapUpCall == null) return;

    final completedCall = _wrapUpCall!.copyWith(
      outcome: outcome,
      notes: notes,
      sentiment: sentiment,
      dealValue: dealValue,
      crmType: crmType,
      recordingPath: _wrapUpCall!.recordingPath ?? 'https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3',
      crmSyncStatus: CrmSyncStatus.pending,
    );

    await _callRepository.addCall(completedCall);
    _wrapUpCall = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
