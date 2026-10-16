import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/sales_track_theme.dart';
import 'services/telemetry_sync_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/pairing_screen.dart';
import 'ui/screens/setup_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SalesTrackTheme.cardBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SalesTrackApp());
}

class SalesTrackApp extends StatelessWidget {
  const SalesTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetrySyncService()),
      ],
      child: MaterialApp(
        title: 'Sales Track CRM',
        debugShowCheckedModeBanner: false,
        theme: SalesTrackTheme.themeData,
        home: const AppRootRouter(),
      ),
    );
  }
}

class AppRootRouter extends StatefulWidget {
  const AppRootRouter({super.key});

  @override
  State<AppRootRouter> createState() => _AppRootRouterState();
}

class _AppRootRouterState extends State<AppRootRouter> {
  bool _showSetupWizardAfterPairing = false;

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<TelemetrySyncService>();

    if (!syncService.isInitialized) {
      return const Scaffold(
        backgroundColor: SalesTrackTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: SalesTrackTheme.primaryLight),
        ),
      );
    }

    if (!syncService.isPaired) {
      return PairingScreen(
        syncService: syncService,
        onPaired: () {
          setState(() => _showSetupWizardAfterPairing = true);
        },
      );
    }

    if (_showSetupWizardAfterPairing) {
      return SetupWizardScreen(
        syncService: syncService,
        onCompleted: () {
          setState(() => _showSetupWizardAfterPairing = false);
        },
      );
    }

    return HomeScreen(
      syncService: syncService,
      onUnpaired: () {
        setState(() => _showSetupWizardAfterPairing = false);
      },
    );
  }
}
