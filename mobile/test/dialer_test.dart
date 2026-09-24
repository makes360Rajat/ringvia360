import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/services/cloud_sync_service.dart';
import 'package:mobile/data/services/telephony_service.dart';
import 'package:mobile/data/repositories/call_repository.dart';
import 'package:mobile/ui/view_models/dialer_view_model.dart';
import 'package:mobile/data/models/call_record.dart';

void main() {
  group('Dialer & Telephony Call Lifecycle Tests', () {
    late CloudSyncService cloudSyncService;
    late TelephonyService telephonyService;
    late CallRepository callRepository;
    late DialerViewModel dialerViewModel;

  setUp(() {
    cloudSyncService = CloudSyncService();
    telephonyService = TelephonyService();
    callRepository = CallRepository(cloudSyncService: cloudSyncService);
    dialerViewModel = DialerViewModel(
      telephonyService: telephonyService,
      callRepository: callRepository,
    );
  });

  tearDown(() {
    dialerViewModel.dispose();
    telephonyService.dispose();
  });

  test('Keypad appends digits and clears correctly', () {
    expect(dialerViewModel.inputNumber, isEmpty);

    dialerViewModel.appendDigit('1');
    dialerViewModel.appendDigit('4');
    dialerViewModel.appendDigit('1');
    dialerViewModel.appendDigit('5');
    expect(dialerViewModel.inputNumber, equals('1415'));

    dialerViewModel.deleteDigit();
    expect(dialerViewModel.inputNumber, equals('141'));

    dialerViewModel.clearNumber();
    expect(dialerViewModel.inputNumber, isEmpty);
  });

  test('Dual-SIM toggles between Corporate SIM 1 and Personal SIM 2', () {
    expect(dialerViewModel.selectedSim.slotId, equals('SIM 1'));
    expect(dialerViewModel.selectedSim.isTracked, isTrue);

    // Toggle to SIM 2 (Personal)
    dialerViewModel.toggleSim();
    expect(dialerViewModel.selectedSim.slotId, equals('SIM 2'));
    expect(dialerViewModel.selectedSim.isTracked, isFalse);

    // Toggle back to SIM 1 (Work)
    dialerViewModel.toggleSim();
    expect(dialerViewModel.selectedSim.slotId, equals('SIM 1'));
    expect(dialerViewModel.selectedSim.isTracked, isTrue);
  });

  test('Call flow triggers active call and post-call wrap up', () async {
    expect(dialerViewModel.isInCall, isFalse);

    // Start call
    dialerViewModel.startCall();
    expect(dialerViewModel.isInCall, isTrue);

    // End call
    dialerViewModel.endCall();
    expect(dialerViewModel.isInCall, isFalse);
    expect(dialerViewModel.wrapUpCall, isNotNull);

    // Submit wrap-up notes
    final initialCount = (await callRepository.getCalls()).length;
    await dialerViewModel.submitWrapUp(
      outcome: 'Demo Completed - Contract Requested',
      notes: 'Test call completed successfully',
      sentiment: SentimentScore.positive,
      dealValue: 50000,
      crmType: 'RingVia360',
    );

    expect(dialerViewModel.wrapUpCall, isNull);
    final updatedCalls = await callRepository.getCalls();
    expect(updatedCalls.length, equals(initialCount + 1));
    expect(updatedCalls.any((c) => c.outcome == 'Demo Completed - Contract Requested'), isTrue);
  });

  test('Inbound call ringing, answer, and wrap-up flow', () async {
    expect(dialerViewModel.isIncomingCallRinging, isFalse);
    expect(dialerViewModel.isInCall, isFalse);

    // Incoming call arrives
    dialerViewModel.triggerIncomingCallSim();
    expect(dialerViewModel.isIncomingCallRinging, isTrue);
    expect(dialerViewModel.activeDirection, equals(CallDirection.inbound));
    expect(dialerViewModel.activeContactName, equals('Priya Patel'));

    // Answer call
    dialerViewModel.answerIncomingCall();
    expect(dialerViewModel.isIncomingCallRinging, isFalse);
    expect(dialerViewModel.isInCall, isTrue);

    // End answered inbound call
    dialerViewModel.endCall();
    expect(dialerViewModel.isInCall, isFalse);
    expect(dialerViewModel.wrapUpCall, isNotNull);
    expect(dialerViewModel.wrapUpCall!.direction, equals(CallDirection.inbound));
    expect(dialerViewModel.wrapUpCall!.outcome, contains('Inbound Call Completed'));
  });

  test('Inbound call decline triggers immediate missed-call wrap-up', () async {
    // Incoming call arrives
    dialerViewModel.triggerIncomingCallSim();
    expect(dialerViewModel.isIncomingCallRinging, isTrue);

    // Rep declines / misses call
    dialerViewModel.declineIncomingCall();
    expect(dialerViewModel.isIncomingCallRinging, isFalse);
    expect(dialerViewModel.isInCall, isFalse);
    expect(dialerViewModel.wrapUpCall, isNotNull);
    expect(dialerViewModel.wrapUpCall!.direction, equals(CallDirection.inbound));
    expect(dialerViewModel.wrapUpCall!.outcome, contains('Missed Inbound Call'));
  });
});
}
