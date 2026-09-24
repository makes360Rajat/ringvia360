import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/cloud_sync_service.dart';
import 'data/services/telephony_service.dart';
import 'data/services/audio_recorder_service.dart';
import 'data/repositories/call_repository.dart';
import 'ui/view_models/dialer_view_model.dart';
import 'ui/view_models/call_feed_view_model.dart';
import 'ui/views/shell_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RingVia360App());
}

class RingVia360App extends StatelessWidget {
  const RingVia360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<CloudSyncService>(
          create: (_) => CloudSyncService(),
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
          update: (_, cloudSync, _) => CallRepository(cloudSyncService: cloudSync),
        ),

        // ViewModels
        ChangeNotifierProxyProvider3<TelephonyService, CallRepository, AudioRecorderService, DialerViewModel>(
          create: (context) => DialerViewModel(
            telephonyService: context.read<TelephonyService>(),
            callRepository: context.read<CallRepository>(),
            audioRecorderService: context.read<AudioRecorderService>(),
          ),
          update: (_, telephony, repo, recorder, vm) => vm ?? DialerViewModel(
            telephonyService: telephony,
            callRepository: repo,
            audioRecorderService: recorder,
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
