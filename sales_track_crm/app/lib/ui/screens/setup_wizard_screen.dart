import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/telemetry_sync_service.dart';

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
    widget.syncService.checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.syncService.checkPermissions();
    }
  }

  Widget _buildPermissionItem({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    final colors = context.stColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? colors.primary.withOpacity(0.35) : colors.border,
          width: isGranted ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.15 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isGranted
                  ? colors.primary.withOpacity(0.12)
                  : colors.surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isGranted ? colors.primary : colors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isGranted) ...[
                      const SizedBox(width: 6),
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
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted)
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 24)
          else
            ElevatedButton(
              onPressed: () {
                onRequest();
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) widget.syncService.checkPermissions();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Grant',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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

    final perms = widget.syncService.permissions;
    final totalCount = perms.length > 0 ? perms.length : 7;
    final grantedCount = perms.values.where((v) => v).length;
    final allGranted = perms.isNotEmpty && perms.values.every((v) => v);
    final progress = totalCount > 0 ? (grantedCount / totalCount).clamp(0.0, 1.0) : 0.0;

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
                                    allGranted
                                        ? 'All Permissions Configured!'
                                        : '$grantedCount of $totalCount Permissions Granted',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    allGranted
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

                  // 1. Call Log
                  _buildPermissionItem(
                    context: context,
                    title: 'Call Log Access',
                    description: 'Reads exact talk duration, phone numbers, and timestamps from device call logs.',
                    icon: Icons.history_rounded,
                    isGranted: widget.syncService.hasCallLogPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 2. Phone State
                  _buildPermissionItem(
                    context: context,
                    title: 'Phone State Sensing',
                    description: 'Detects real-time incoming, outgoing, answered, and missed phone calls.',
                    icon: Icons.phone_in_talk_rounded,
                    isGranted: widget.syncService.hasPhoneStatePermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 3. Contacts
                  _buildPermissionItem(
                    context: context,
                    title: 'Contacts Book',
                    description: 'Resolves customer numbers to contact names saved on this phone.',
                    icon: Icons.contacts_rounded,
                    isGranted: widget.syncService.hasContactsPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 4. SMS
                  _buildPermissionItem(
                    context: context,
                    title: 'SMS Message Logs',
                    description: 'Captures incoming and outgoing SMS text interactions with CRM clients.',
                    icon: Icons.sms_rounded,
                    isGranted: widget.syncService.hasSmsPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 5. WhatsApp Call Access
                  _buildPermissionItem(
                    context: context,
                    title: 'WhatsApp Call Access',
                    description: 'Notification Listener permission to capture WhatsApp & WhatsApp Business calls.',
                    icon: Icons.mark_chat_unread_rounded,
                    isGranted: widget.syncService.hasWhatsAppAccessPermission,
                    onRequest: () => widget.syncService.openNotificationListenerSettings(),
                  ),

                  // 6. Recordings Folder
                  _buildPermissionItem(
                    context: context,
                    title: 'Call Recordings Storage',
                    description: 'Storage access to discover, link, and upload call audio files (.m4a, .mp3, .amr).',
                    icon: Icons.folder_special_rounded,
                    isGranted: widget.syncService.hasRecordingsFolderPermission,
                    onRequest: () => widget.syncService.openAllFilesSettings(),
                  ),

                  // 7. Battery Unrestricted
                  _buildPermissionItem(
                    context: context,
                    title: 'Battery Background Exemption',
                    description: 'Prevents the Android OS from suspending background telemetry synchronization.',
                    icon: Icons.battery_charging_full_rounded,
                    isGranted: widget.syncService.hasBatteryOptimizationExemption,
                    onRequest: () => widget.syncService.openBatterySettings(),
                  ),
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
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: widget.onCompleted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        allGranted ? 'Continue to App' : 'Skip & Continue',
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
