import 'package:flutter/material.dart';
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
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SalesTrackTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? SalesTrackTheme.primary.withOpacity(0.4) : SalesTrackTheme.surfaceColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted ? SalesTrackTheme.primary.withOpacity(0.15) : SalesTrackTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isGranted ? SalesTrackTheme.primary : SalesTrackTheme.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SalesTrackTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SalesTrackTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SalesTrackTheme.primary, size: 24),
              ],
            )
          else
            OutlinedButton(
              onPressed: () {
                onRequest();
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) widget.syncService.checkPermissions();
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                side: const BorderSide(color: SalesTrackTheme.primary),
              ),
              child: const Text('Grant', style: TextStyle(color: SalesTrackTheme.primaryLight, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = widget.syncService.permissions;
    final allGranted = perms.values.every((v) => v);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup & Permissions Wizard'),
        actions: [
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
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Grant Required Telemetry Permissions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SalesTrackTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To automatically track calls, recordings, SMS, and WhatsApp calls for company phones, Sales Track needs system access:',
                    style: TextStyle(fontSize: 13, color: SalesTrackTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // 1. Call Log
                  _buildPermissionItem(
                    title: 'Call Log',
                    description: 'Reads exact talk duration and call timestamps from device log.',
                    icon: Icons.history_rounded,
                    isGranted: widget.syncService.hasCallLogPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 2. Phone State
                  _buildPermissionItem(
                    title: 'Phone State',
                    description: 'Detects incoming, outgoing, answered, and missed phone calls.',
                    icon: Icons.phone_in_talk_rounded,
                    isGranted: widget.syncService.hasPhoneStatePermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 3. Contacts
                  _buildPermissionItem(
                    title: 'Contacts',
                    description: 'Resolves phone numbers to employee/customer address book names.',
                    icon: Icons.contacts_rounded,
                    isGranted: widget.syncService.hasContactsPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 4. SMS
                  _buildPermissionItem(
                    title: 'SMS',
                    description: 'Tracks customer SMS text exchanges.',
                    icon: Icons.sms_rounded,
                    isGranted: widget.syncService.hasSmsPermission,
                    onRequest: () => widget.syncService.requestAllPermissions(),
                  ),

                  // 5. WhatsApp Call Access
                  _buildPermissionItem(
                    title: 'WhatsApp Call Access',
                    description: 'Notification Listener permission to sense WhatsApp & WhatsApp Business calls.',
                    icon: Icons.mark_chat_unread_rounded,
                    isGranted: widget.syncService.hasWhatsAppAccessPermission,
                    onRequest: () => widget.syncService.openNotificationListenerSettings(),
                  ),

                  // 6. Recordings Folder
                  _buildPermissionItem(
                    title: 'Recordings Folder',
                    description: 'All Files Access to locate and upload call audio recordings (.m4a, .mp3).',
                    icon: Icons.folder_special_rounded,
                    isGranted: widget.syncService.hasRecordingsFolderPermission,
                    onRequest: () => widget.syncService.openAllFilesSettings(),
                  ),

                  // 7. Battery Unrestricted
                  _buildPermissionItem(
                    title: 'Battery Unrestricted',
                    description: 'Prevents the Android OS from stopping the background sync service.',
                    icon: Icons.battery_charging_full_rounded,
                    isGranted: widget.syncService.hasBatteryOptimizationExemption,
                    onRequest: () => widget.syncService.openBatterySettings(),
                  ),
                ],
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: SalesTrackTheme.cardBackground,
                border: Border(top: BorderSide(color: SalesTrackTheme.surfaceColor)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => widget.syncService.requestAllPermissions(),
                          child: const Text('Request All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onCompleted,
                          child: Text(allGranted ? 'Continue to App' : 'Skip & Continue'),
                        ),
                      ),
                    ],
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
