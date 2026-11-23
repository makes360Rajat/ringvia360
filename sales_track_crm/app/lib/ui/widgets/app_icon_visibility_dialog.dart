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
                  'App Icon Settings',
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
                              isHidden ? 'App Icon is HIDDEN' : 'App Icon is VISIBLE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isHidden ? colors.warning : colors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isHidden
                                  ? 'Hidden from phone screen and app drawer'
                                  : 'Visible on phone screen and app drawer',
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

                // Main Action Button: Toggles state AND immediately opens Phone Launcher Settings
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
                            // Immediately deep link into phone launcher settings
                            await service.openHideAppsSettings();
                            setDialogState(() => isProcessing = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? (targetHidden
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
                          ? 'Opening settings...'
                          : (isHidden ? 'Show App Icon on Phone' : 'Hide App Icon on Phone'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
                        'Tap the button above',
                        'Directly opens Home screen settings',
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
                const SizedBox(height: 10),

                // Secondary Button: Open Samsung Hide Apps Settings Directly
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await service.openHideAppsSettings();
                    },
                    icon: const Icon(Icons.settings_suggest_rounded, size: 17),
                    label: const Text(
                      'Reopen Phone Launcher Settings',
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


