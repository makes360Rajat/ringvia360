import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../services/telemetry_sync_service.dart';

void showAppIconVisibilityDialog(BuildContext context, TelemetrySyncService service) {
  bool isProcessing = false;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final isHidden = service.isAppIconHidden;
        final colors = context.stColors;

        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isHidden ? colors.warning : colors.success).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: isHidden ? colors.warning : colors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'App Icon Visibility',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isHidden ? colors.warning : colors.success).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isHidden ? colors.warning : colors.success).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHidden ? Icons.visibility_off_rounded : Icons.check_circle_rounded,
                        color: isHidden ? colors.warning : colors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHidden
                                  ? 'App Icon is HIDDEN inside App List'
                                  : 'App Icon is VISIBLE inside App List',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isHidden ? colors.warning : colors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isHidden
                                  ? 'Hidden from phone screen and app list'
                                  : 'Visible on phone screen and app list',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Action Button: Toggles component state without opening settings
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setDialogState(() => isProcessing = true);
                            final targetHidden = !isHidden;
                            final ok = await service.setAppIconHidden(targetHidden);
                            await service.checkAppIconHidden();
                            setDialogState(() => isProcessing = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? (targetHidden
                                            ? '✓ App icon hidden from app list'
                                            : '✓ App icon restored to app list')
                                        : 'Failed to update app icon setting',
                                  ),
                                  backgroundColor: ok ? colors.primary : colors.danger,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 19,
                          ),
                    label: Text(
                      isProcessing
                          ? 'Updating icon...'
                          : (isHidden
                              ? 'Show App Icon inside App List'
                              : 'Hide App Icon inside App List'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHidden ? colors.success : colors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Button: Directly below the main app icon button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await service.openHideAppsSettings();
                    },
                    icon: const Icon(Icons.settings_suggest_rounded, size: 17),
                    label: const Text(
                      'Hide/Show the App Launcher Settings',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Step-by-Step Direct Visual Guide
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Quick Step-by-Step Guide:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStepRow(
                        colors,
                        '1',
                        'Tap "Hide/Show the App Launcher Settings"',
                        'Directly opens phone launcher settings',
                      ),
                      const SizedBox(height: 6),
                      _buildStepRow(
                        colors,
                        '2',
                        'Tap "Hide apps on Home & Apps screens"',
                        'Located in the Home settings list',
                      ),
                      const SizedBox(height: 6),
                      _buildStepRow(
                        colors,
                        '3',
                        isHidden
                            ? 'Uncheck "CallVia360" & tap "Done"'
                            : 'Select "CallVia360" & tap "Done"',
                        'CallVia360 appears right at the top',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Background & Dial Access Note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: colors.surfaceColor,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: colors.border.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Telemetry and call recording continue running 24/7.\n'
                        '• Reopen anytime via the persistent notification or by dialing *#*#3600#*#*.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Close', style: TextStyle(color: colors.textSecondary)),
            ),
          ],
        );
      },
    ),
  );
}

/// Dedicated dialog for CRM Custom Branding (App Name & Launcher Icon)
void showCrmBrandingDialog(BuildContext context, TelemetrySyncService service) {
  bool isProcessing = false;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final colors = context.stColors;
        final hasIcon = service.cachedIconPath != null && File(service.cachedIconPath!).existsSync();
        final appName = service.effectiveAppName;

        return AlertDialog(
          backgroundColor: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: hasIcon
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(service.cachedIconPath!),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.palette_rounded, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CRM Custom Branding',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branding Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      if (hasIcon)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(service.cachedIconPath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.business_rounded, color: colors.primary, size: 28),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Active Branding',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Connected',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Synced from CRM server',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Explanation note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border.withOpacity(0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Place this custom icon and title on your phone Home screen at runtime without reinstalling the APK.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Action: Set on Home Screen Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setDialogState(() => isProcessing = true);
                            final ok = await service.updateHomeScreenLauncher();
                            setDialogState(() => isProcessing = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? '✓ Shortcut requested! Tap "Add" if prompted to place "$appName" on Home screen.'
                                        : 'Home screen shortcut updated.',
                                  ),
                                  backgroundColor: colors.primary,
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_to_home_screen_rounded, size: 20),
                    label: Text(
                      isProcessing ? 'Setting on Home screen...' : 'Set "$appName" on Home Screen',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Button to hide old icon if desired
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      showAppIconVisibilityDialog(context, service);
                    },
                    icon: const Icon(Icons.visibility_off_rounded, size: 17),
                    label: const Text(
                      'Hide Original Icon inside App List',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.warning,
                      side: BorderSide(color: colors.warning.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Close', style: TextStyle(color: colors.textSecondary)),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildStepRow(dynamic colors, String number, String title, String subtitle) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
