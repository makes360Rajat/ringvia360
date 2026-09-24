import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
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
