import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_pairing_service.dart';
import '../view_models/call_feed_view_model.dart';
import 'device_pairing_view.dart';
import 'dialer_view.dart';
import 'activity_feed_view.dart';
import 'rep_scorecard_view.dart';
import 'privacy_settings_view.dart';
import 'in_call_overlay_view.dart';
import 'incoming_call_overlay_view.dart';
import 'post_call_wrap_up_view.dart';

class ShellView extends StatefulWidget {
  const ShellView({super.key});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DialerView(),
    ActivityFeedView(),
    RepScorecardView(),
    PrivacySettingsView(),
  ];

  void _showPairingOptions(BuildContext context, AuthPairingService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: AppColors.accentEmerald, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.orgName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textMain),
                        ),
                        Text(
                          'Paired Rep: ${auth.repName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.borderSubtle, height: 28),
              // Feed Privatization switch
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: auth.privatizeToMeOnly ? AppColors.accentCyan.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    auth.privatizeToMeOnly ? Icons.lock : Icons.group,
                    color: auth.privatizeToMeOnly ? AppColors.accentCyan : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text('Privatize Live Feed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  auth.privatizeToMeOnly ? 'Only showing your private calls & recordings' : 'Showing all company team activities',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                trailing: Switch(
                  value: auth.privatizeToMeOnly,
                  activeThumbColor: AppColors.accentCyan,
                  onChanged: (val) async {
                    await auth.setPrivatizeToMeOnly(val);
                    if (context.mounted) {
                      context.read<CallFeedViewModel>().loadCalls();
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Unpair Button
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await auth.unpair();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentRose,
                  side: const BorderSide(color: AppColors.accentRose),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Unpair Phone & Disconnect Tenant', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthPairingService>();

    if (auth.isInitialized && !auth.isPaired) {
      return const DevicePairingView();
    }

    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              // Knox Enterprise Multi-tenant Header Bar
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurfaceElevated,
                    border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accentEmerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${auth.orgName} • ${auth.repName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showPairingOptions(context, auth),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: auth.privatizeToMeOnly
                                ? AppColors.accentCyan.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: auth.privatizeToMeOnly
                                  ? AppColors.accentCyan.withValues(alpha: 0.4)
                                  : AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                auth.privatizeToMeOnly ? Icons.lock_outline : Icons.corporate_fare,
                                size: 11,
                                color: auth.privatizeToMeOnly ? AppColors.accentCyan : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                auth.privatizeToMeOnly ? 'Private Feed' : 'Company Feed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: auth.privatizeToMeOnly ? AppColors.accentCyan : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.bgSurface,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textDim,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dialpad),
                  activeIcon: Icon(Icons.dialpad, color: AppColors.primary),
                  label: 'Dialer',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  activeIcon: Icon(Icons.history, color: AppColors.primary),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events_outlined),
                  activeIcon: Icon(Icons.emoji_events, color: AppColors.primary),
                  label: 'Scorecard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.security_outlined),
                  activeIcon: Icon(Icons.security, color: AppColors.primary),
                  label: 'Privacy',
                ),
              ],
            ),
          ),
        ),

        // Live Incoming Call Alert (Ringing HUD)
        const IncomingCallOverlayView(),

        // Live In-Call HUD Overlay
        const InCallOverlayView(),

        // Salestrail-Style Post-Call Wrap-Up Modal
        const PostCallWrapUpView(),
      ],
    );
  }
}
