import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_pairing_service.dart';
import 'data/services/cloud_sync_service.dart';
import 'data/services/telephony_service.dart';
import 'data/services/audio_recorder_service.dart';
import 'data/services/native_call_sensor_service.dart';
import 'data/services/local_recording_service.dart';
import 'data/repositories/call_repository.dart';
import 'ui/view_models/dialer_view_model.dart';
import 'ui/view_models/call_feed_view_model.dart';
import 'ui/views/shell_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions required for auto call sensing and wrap-up popup:
  // - phone             → READ_PHONE_STATE (detects call state changes)
  // - microphone        → RECORD_AUDIO    (audio capture)
  // - notification      → POST_NOTIFICATIONS (Android 13+ — call-ended notification)
  // - systemAlertWindow → SYSTEM_ALERT_WINDOW (display wrap-up popup on top of screen)
  await [
    Permission.phone,
    Permission.microphone,
    Permission.notification,
    Permission.systemAlertWindow,
  ].request();

  runApp(const RingVia360App());
}


class RingVia360App extends StatelessWidget {
  const RingVia360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication & Pairing Service
        ChangeNotifierProvider<AuthPairingService>(
          create: (_) => AuthPairingService(),
        ),

        // Services
        ProxyProvider<AuthPairingService, CloudSyncService>(
          update: (_, auth, previous) => CloudSyncService(
            orgId: auth.orgId,
            repId: auth.repId,
            repName: auth.repName,
            privatizeToMeOnly: auth.privatizeToMeOnly,
          ),
        ),
        Provider<TelephonyService>(
          create: (_) => TelephonyService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AudioRecorderService>(
          create: (_) => AudioRecorderService(),
        ),

        // Repository
        ProxyProvider<CloudSyncService, CallRepository>(
          update: (_, cloudSync, previous) => CallRepository(cloudSyncService: cloudSync),
        ),

        // Native Call Sensor & Local Storage Services
        Provider<NativeCallSensorService>(
          create: (_) => NativeCallSensorService(),
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider3<NativeCallSensorService, CloudSyncService, CallRepository, LocalRecordingService>(
          update: (_, sensor, cloudSync, repo, previous) => LocalRecordingService(
            nativeSensor: sensor,
            cloudSync: cloudSync,
            callRepository: repo,
          ),
        ),

        // ViewModels
        ChangeNotifierProxyProvider4<TelephonyService, CallRepository, AudioRecorderService, NativeCallSensorService, DialerViewModel>(
          create: (context) => DialerViewModel(
            telephonyService: context.read<TelephonyService>(),
            callRepository: context.read<CallRepository>(),
            audioRecorderService: context.read<AudioRecorderService>(),
            nativeCallSensor: context.read<NativeCallSensorService>(),
          ),
          update: (_, telephony, repo, recorder, sensor, vm) => vm ?? DialerViewModel(
            telephonyService: telephony,
            callRepository: repo,
            audioRecorderService: recorder,
            nativeCallSensor: sensor,
          ),
        ),
        ChangeNotifierProxyProvider<CallRepository, CallFeedViewModel>(
          create: (context) => CallFeedViewModel(
            callRepository: context.read<CallRepository>(),
          ),
          update: (_, repo, vm) => vm ?? CallFeedViewModel(callRepository: repo),
        ),
      ],
      child: MaterialApp(
        title: 'RingVia360 Sales Companion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const ShellView(),
      ),
    );
  }
}
