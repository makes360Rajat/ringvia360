import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/sales_track_api_service.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final bool isMandatory;
  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.isMandatory,
    required this.onUpdate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final targetVersion = updateInfo.latestVersion.isNotEmpty
        ? updateInfo.latestVersion
        : updateInfo.minVersion;

    return PopScope(
      canPop: !isMandatory,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isMandatory ? colors.warning.withOpacity(0.5) : colors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMandatory
                          ? [
                              const Color(0xFFEF4444),
                              const Color(0xFFDC2626),
                            ]
                          : [
                              const Color(0xFF2563EB),
                              const Color(0xFF1D4ED8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMandatory
                              ? Icons.warning_amber_rounded
                              : Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isMandatory ? 'MANDATORY UPDATE' : 'NEW VERSION AVAILABLE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMandatory ? 'Update Required' : 'Update Available',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Version Comparison Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone_android_rounded, size: 16, color: colors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Current: v${SalesTrackApiService.currentAppVersion}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF3B82F6)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v$targetVersion',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Notice Text
                      Text(
                        isMandatory
                            ? 'A required update is available with essential security, telemetry sync, and caller ID fixes. You must update CallVia360 to continue.'
                            : 'A new version of CallVia360 is ready with faster background sync and improvements.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                          height: 1.4,
                        ),
                      ),

                      if (updateInfo.notes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          "What's New:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            updateInfo.notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Actions
                      Row(
                        children: [
                          if (!isMandatory) ...[
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onDismiss?.call();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: colors.border),
                                ),
                                child: Text(
                                  'Later',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: onUpdate,
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(
                                isMandatory ? 'Update Required' : 'Update Now',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMandatory ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
        ),
      ),
    );
  }
}

