import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/telemetry_sync_service.dart';
import '../widgets/app_icon_visibility_dialog.dart';

class SetupWizardScreen extends StatefulWidget {
  final TelemetrySyncService syncService;
  final VoidCallback onCompleted;

  const SetupWizardScreen({
    super.key,
    required this.syncService,
    required this.onCompleted,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.syncService.isSetupWizardActive = true;
    widget.syncService.addListener(_onServiceChanged);
    widget.syncService.checkPermissions();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.syncService.isSetupWizardActive = false;
    WidgetsBinding.instance.removeObserver(this);
    widget.syncService.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.syncService.checkPermissions().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _buildPermissionItem({
    required BuildContext context,
    required String title,
    String? description,
    required IconData icon,
    required bool isGranted,
    VoidCallback? onRequest,
  }) {
    final colors = context.stColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? colors.primary.withOpacity(0.35) : colors.border,
          width: isGranted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isGranted
                  ? colors.primary.withOpacity(0.12)
                  : colors.surfaceColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isGranted ? colors.primary : colors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (isGranted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: colors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted || onRequest == null)
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 22)
          else
            ElevatedButton(
              onPressed: () {
                onRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Grant',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppIconVisibilityCard(BuildContext context) {
    final colors = context.stColors;
    final isHidden = widget.syncService.isAppIconHidden;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isHidden ? colors.warning : colors.success).withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (isHidden ? colors.warning : colors.success).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                  color: isHidden ? colors.warning : colors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'App Launcher Icon',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (isHidden ? colors.warning : colors.success).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isHidden ? 'HIDDEN' : 'VISIBLE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isHidden ? colors.warning : colors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHidden
                          ? 'Icon is hidden from phone launcher & app drawer'
                          : 'Icon is visible on phone home screen & app drawer',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final target = !isHidden;
                  final ok = await widget.syncService.setAppIconHidden(target);
                  await widget.syncService.checkAppIconHidden();
                  await widget.syncService.openHideAppsSettings();
                  if (mounted) {
                    setState(() {});
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? (target
                                  ? '✓ Hidden! In Settings, tap "Hide apps" to select CallVia360'
                                  : '✓ Restored! In Settings, tap "Hide apps" to uncheck CallVia360')
                              : 'Failed to update app icon setting',
                        ),
                        backgroundColor: ok ? colors.primary : colors.danger,
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHidden ? colors.success : colors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isHidden ? 'Show Icon' : 'Hide Icon',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Telemetry and call recording continue running 24/7 in background.\n'
                  '• Reopen anytime via notification or dialing *#*#3600#*#*.\n'
                  '• Note for Samsung One UI: To find CallVia360 in Samsung "Hide apps", icon must be set to "Show Icon" first so Samsung detects CallVia360 in its list.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.syncService.openHideAppsSettings(),
                        icon: const Icon(Icons.settings_suggest_rounded, size: 15),
                        label: const Text(
                          'Open Samsung Settings',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.primary.withOpacity(0.35)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.open_in_new_rounded, color: colors.primary, size: 18),
                      tooltip: 'Full Icon Dialog',
                      onPressed: () => showAppIconVisibilityDialog(context, widget.syncService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = context.isDarkMode;

    final int totalCount;
    final int grantedCount;
    final bool allGranted;

    if (Platform.isIOS) {
      totalCount = 3;
      int g = 0;
      if (widget.syncService.hasContactsPermission) g++;
      if (widget.syncService.hasRecordingsFolderPermission) g++;
      if (widget.syncService.hasNotificationPermission) g++;
      grantedCount = g;
      allGranted = (g >= 1);
    } else {
      final perms = widget.syncService.permissions;
      totalCount = perms.isNotEmpty ? perms.length : 7;
      grantedCount = perms.values.where((v) => v).length;
      allGranted = perms.isNotEmpty && perms.values.every((v) => v);
    }
    final progress = totalCount > 0 ? (grantedCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final bool isFullyConfigured = allGranted || (totalCount > 0 && grantedCount >= totalCount) || progress >= 0.99;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Setup & Permissions Wizard'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggleTheme(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            tooltip: 'Open App Settings',
            onPressed: () => widget.syncService.openAppSettings(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recheck Permissions',
            onPressed: () => widget.syncService.checkPermissions(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                children: [
                  // Progress Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.security_rounded, size: 20, color: colors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isFullyConfigured
                                        ? 'All Permissions Configured!'
                                        : '$grantedCount of $totalCount Permissions Granted',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    isFullyConfigured
                                        ? 'Phone telemetry tracking is fully operational.'
                                        : 'Grant the required permissions for seamless CRM synchronization.',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: colors.surfaceColor,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'TELEMETRY PERMISSIONS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (Platform.isIOS) ...[
                    // iOS 1. Contacts
                    _buildPermissionItem(
                      context: context,
                      title: 'Contacts Book',
                      description: 'Resolves customer numbers to contact names and client history saved on this iPhone.',
                      icon: Icons.contacts_rounded,
                      isGranted: widget.syncService.hasContactsPermission,
                      onRequest: () => widget.syncService.requestPermission('contacts'),
                    ),

                    // iOS 2. Microphone & Audio
                    _buildPermissionItem(
                      context: context,
                      title: 'Microphone & Audio Access',
                      description: 'Access to record customer call audio, voice notes, and meeting memos.',
                      icon: Icons.mic_rounded,
                      isGranted: widget.syncService.hasRecordingsFolderPermission,
                      onRequest: () => widget.syncService.requestPermission('microphone'),
                    ),

                    // iOS 3. Notifications & CRM Alerts
                    _buildPermissionItem(
                      context: context,
                      title: 'CRM Notifications & Alerts',
                      description: 'Receives real-time lead updates, scheduled call reminders, and sync alerts.',
                      icon: Icons.notifications_active_rounded,
                      isGranted: widget.syncService.hasNotificationPermission,
                      onRequest: () => widget.syncService.requestPermission('notifications'),
                    ),

                    // iOS 4. WhatsApp & Phone Calling
                    _buildPermissionItem(
                      context: context,
                      title: 'WhatsApp & Cellular Dialing',
                      description: 'Integrates one-tap calling and direct WhatsApp messaging from CRM lead lists.',
                      icon: Icons.mark_chat_unread_rounded,
                      isGranted: true,
                      onRequest: null,
                    ),

                    // iOS 5. Background Telemetry Sync
                    _buildPermissionItem(
                      context: context,
                      title: 'Background Telemetry Sync',
                      description: 'Leverages iOS Background Processing to synchronize CRM data and pending interaction queues.',
                      icon: Icons.sync_rounded,
                      isGranted: true,
                      onRequest: null,
                    ),
                  ] else ...[
                    // Android 1. Call Log
                    _buildPermissionItem(
                      context: context,
                      title: 'Call Log Access',
                      description: 'Reads exact talk duration, phone numbers, and timestamps from device call logs.',
                      icon: Icons.history_rounded,
                      isGranted: widget.syncService.hasCallLogPermission,
                      onRequest: () => widget.syncService.requestPermission('call_log'),
                    ),

                    // Android 2. Phone State
                    _buildPermissionItem(
                      context: context,
                      title: 'Phone State Sensing',
                      description: 'Detects real-time incoming, outgoing, answered, and missed phone calls.',
                      icon: Icons.phone_in_talk_rounded,
                      isGranted: widget.syncService.hasPhoneStatePermission,
                      onRequest: () => widget.syncService.requestPermission('phone_state'),
                    ),

                    // Android 3. Contacts
                    _buildPermissionItem(
                      context: context,
                      title: 'Contacts Book',
                      description: 'Resolves customer numbers to contact names saved on this phone.',
                      icon: Icons.contacts_rounded,
                      isGranted: widget.syncService.hasContactsPermission,
                      onRequest: () => widget.syncService.requestPermission('contacts'),
                    ),

                    // Android 4. SMS
                    _buildPermissionItem(
                      context: context,
                      title: 'SMS Message Logs',
                      description: 'Captures incoming and outgoing SMS text interactions with CRM clients.',
                      icon: Icons.sms_rounded,
                      isGranted: widget.syncService.hasSmsPermission,
                      onRequest: () => widget.syncService.requestPermission('sms'),
                    ),

                    // Android 5. WhatsApp Call Access
                    _buildPermissionItem(
                      context: context,
                      title: 'WhatsApp Call Access',
                      description: 'Notification Listener permission to capture WhatsApp & WhatsApp Business calls.',
                      icon: Icons.mark_chat_unread_rounded,
                      isGranted: widget.syncService.hasWhatsAppAccessPermission,
                      onRequest: () => widget.syncService.openNotificationListenerSettings(),
                    ),

                    // Android 6. Recordings Audio & Storage
                    _buildPermissionItem(
                      context: context,
                      title: 'Audio & Storage Access',
                      description: 'Storage permission to detect, link, and upload call audio recordings (.m4a, .mp3, .wav).',
                      icon: Icons.audio_file_rounded,
                      isGranted: widget.syncService.hasRecordingsFolderPermission,
                      onRequest: () => widget.syncService.requestPermission('audio'),
                    ),

                    // Android 7. Battery Unrestricted
                    _buildPermissionItem(
                      context: context,
                      title: 'Battery Background Exemption',
                      description: 'Prevents the Android OS from suspending background telemetry synchronization.',
                      icon: Icons.battery_charging_full_rounded,
                      isGranted: widget.syncService.hasBatteryOptimizationExemption,
                      onRequest: () => widget.syncService.openBatterySettings(),
                    ),

                    // Android 8. Truecaller Overlay (Display Over Other Apps)
                    _buildPermissionItem(
                      context: context,
                      title: 'Display Over Other Apps',
                      description: 'Displays Truecaller-style caller ID and after-call outcome dialogs over phone dialer.',
                      icon: Icons.layers_rounded,
                      isGranted: widget.syncService.hasOverlayPermission,
                      onRequest: () => widget.syncService.openOverlaySettings(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'APP VISIBILITY & HIDE ICON',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // App Launcher Icon Visibility & Hide
                    _buildAppIconVisibilityCard(context),
                  ],
                ],
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (!isFullyConfigured) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => widget.syncService.requestAllPermissions(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Request All',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.syncService.isSetupWizardActive = false;
                        if (widget.syncService.hasCallLogPermission) {
                          widget.syncService.syncDeviceCallLogs();
                        }
                        if (widget.syncService.hasSmsPermission) {
                          widget.syncService.syncDeviceSms();
                        }
                        widget.syncService.scanLocalRecordings();
                        widget.onCompleted();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isFullyConfigured ? 'Continue to App' : 'Skip & Continue',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
