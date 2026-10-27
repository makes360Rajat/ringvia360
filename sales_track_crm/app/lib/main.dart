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
  runApp(const SalesTrackApp());
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class SalesTrackApp extends StatelessWidget {
  const SalesTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetrySyncService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final isDark = themeProvider.isDark(context);
          
          // Dynamically adjust status bar and navigation bar styling based on current brightness
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: isDark 
                  ? SalesTrackTheme.darkColors.cardBackground 
                  : SalesTrackTheme.lightColors.cardBackground,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
          );

          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'CallVia360',
            debugShowCheckedModeBanner: false,
            theme: SalesTrackTheme.lightTheme,
            darkTheme: SalesTrackTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppRootRouter(),
          );
        },
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
    final colors = context.stColors;

    if (!syncService.isInitialized) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: colors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing CallVia360...',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
