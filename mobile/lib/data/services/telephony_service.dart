import 'dart:async';
import '../models/call_record.dart';
import '../models/sim_config.dart';

enum TelephonyState { idle, ringing, connected, disconnected }

class TelephonyEvent {
  final TelephonyState state;
  final String phoneNumber;
  final String contactName;
  final String company;
  final CallDirection direction;
  final DateTime startTime;
  final int durationSeconds;
  final SimConfig activeSim;
  final bool isTrackingAllowed;

  TelephonyEvent({
    required this.state,
    required this.phoneNumber,
    required this.contactName,
    required this.company,
    required this.direction,
    required this.startTime,
    required this.durationSeconds,
    required this.activeSim,
    required this.isTrackingAllowed,
  });
}

class TelephonyService {
  final _eventController = StreamController<TelephonyEvent>.broadcast();
  Stream<TelephonyEvent> get onCallEvent => _eventController.stream;

  TelephonyState _currentState = TelephonyState.idle;
  TelephonyState get currentState => _currentState;

  Timer? _callTimer;
  int _activeDuration = 0;
  DateTime? _callStartTime;

  SimConfig _activeSim = const SimConfig(
    slotId: 'SIM 1',
    label: 'SIM 1 (Work Corporate)',
    carrier: 'AT&T Business',
    phoneNumber: '+1 (415) 700-1122',
    isTracked: true,
    isCorporate: true,
  );

  SimConfig get activeSim => _activeSim;

  void setActiveSim(SimConfig sim) {
    _activeSim = sim;
  }

  void startOutboundCall({
    required String phoneNumber,
    required String contactName,
    required String company,
    required WorkHoursSchedule schedule,
  }) {
    _callStartTime = DateTime.now();
    _activeDuration = 0;
    _currentState = TelephonyState.connected;

    final isAllowed = _activeSim.isTracked && schedule.isCurrentlyActive();

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _activeDuration++;
      _eventController.add(TelephonyEvent(
        state: TelephonyState.connected,
        phoneNumber: phoneNumber,
        contactName: contactName,
        company: company,
        direction: CallDirection.outbound,
        startTime: _callStartTime!,
        durationSeconds: _activeDuration,
        activeSim: _activeSim,
        isTrackingAllowed: isAllowed,
      ));
    });
  }

  TelephonyEvent endCurrentCall({
    required String phoneNumber,
    required String contactName,
    required String company,
    required CallDirection direction,
    required WorkHoursSchedule schedule,
  }) {
    _callTimer?.cancel();
    _currentState = TelephonyState.disconnected;

    final finalDuration = _activeDuration;
    final isAllowed = _activeSim.isTracked && schedule.isCurrentlyActive();

    final event = TelephonyEvent(
      state: TelephonyState.disconnected,
      phoneNumber: phoneNumber,
      contactName: contactName,
      company: company,
      direction: direction,
      startTime: _callStartTime ?? DateTime.now(),
      durationSeconds: finalDuration,
      activeSim: _activeSim,
      isTrackingAllowed: isAllowed,
    );

    _eventController.add(event);
    _currentState = TelephonyState.idle;
    _activeDuration = 0;
    _callStartTime = null;

    return event;
  }

  void simulateInboundRinging({
    required String phoneNumber,
    required String contactName,
    required String company,
    required WorkHoursSchedule schedule,
  }) {
    _currentState = TelephonyState.ringing;
    _activeDuration = 0;
    _callStartTime = DateTime.now();

    final isAllowed = _activeSim.isTracked && schedule.isCurrentlyActive();

    _eventController.add(TelephonyEvent(
      state: TelephonyState.ringing,
      phoneNumber: phoneNumber,
      contactName: contactName,
      company: company,
      direction: CallDirection.inbound,
      startTime: _callStartTime!,
      durationSeconds: 0,
      activeSim: _activeSim,
      isTrackingAllowed: isAllowed,
    ));
  }

  void answerInboundCall({
    required String phoneNumber,
    required String contactName,
    required String company,
    required WorkHoursSchedule schedule,
  }) {
    _currentState = TelephonyState.connected;
    _activeDuration = 0;
    _callStartTime = DateTime.now();

    final isAllowed = _activeSim.isTracked && schedule.isCurrentlyActive();

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _activeDuration++;
      _eventController.add(TelephonyEvent(
        state: TelephonyState.connected,
        phoneNumber: phoneNumber,
        contactName: contactName,
        company: company,
        direction: CallDirection.inbound,
        startTime: _callStartTime!,
        durationSeconds: _activeDuration,
        activeSim: _activeSim,
        isTrackingAllowed: isAllowed,
      ));
    });
  }

  TelephonyEvent rejectInboundCall({
    required String phoneNumber,
    required String contactName,
    required String company,
    required WorkHoursSchedule schedule,
  }) {
    _callTimer?.cancel();
    _currentState = TelephonyState.disconnected;

    final isAllowed = _activeSim.isTracked && schedule.isCurrentlyActive();

    final event = TelephonyEvent(
      state: TelephonyState.disconnected,
      phoneNumber: phoneNumber,
      contactName: contactName,
      company: company,
      direction: CallDirection.inbound,
      startTime: _callStartTime ?? DateTime.now(),
      durationSeconds: 0,
      activeSim: _activeSim,
      isTrackingAllowed: isAllowed,
    );

    _eventController.add(event);
    _currentState = TelephonyState.idle;
    _activeDuration = 0;
    _callStartTime = null;

    return event;
  }

  void dispose() {
    _callTimer?.cancel();
    _eventController.close();
  }
}
