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
      final targetProgress = syncService.initProgress.clamp(0.0, 1.0);
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0066FF), Color(0xFF004BB8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0066FF).withOpacity(0.32),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CallVia360',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sales Telemetry & CRM Automation',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 38),

                  // Fluid animated progress bar with continuous real-time percentages
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.05, end: targetProgress),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedVal, _) {
                      final percent = (animatedVal * 100).toInt().clamp(0, 100);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: animatedVal,
                                backgroundColor: colors.border.withOpacity(0.4),
                                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  syncService.initStatusMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
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
