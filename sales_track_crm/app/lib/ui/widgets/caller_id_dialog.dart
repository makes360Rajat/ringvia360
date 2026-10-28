import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/telemetry_sync_service.dart';
import '../screens/outcome_modal.dart';

class CallerIdDialog extends StatelessWidget {
  final CallerIdInfo info;
  final TelemetrySyncService syncService;
  final VoidCallback onDismiss;

  const CallerIdDialog({
    super.key,
    required this.info,
    required this.syncService,
    required this.onDismiss,
  });

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today at $timeStr';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
    if (isYesterday) return 'Yesterday at $timeStr';
    return '${d.day}/${d.month}/${d.year} at $timeStr';
  }

  void _openLeadOutcomeModal(BuildContext context) {
    onDismiss();
    Navigator.of(context).pop();

    final tempEvent = SalesTrackEvent(
      uid: 'call-now-${DateTime.now().millisecondsSinceEpoch}',
      kind: 'call',
      time: DateTime.now().millisecondsSinceEpoch,
      direction: info.direction,
      number: info.phoneNumber,
      name: info.name,
      sim: 1,
      duration: 0,
      source: 'auto',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OutcomeModal(
        event: tempEvent,
        syncService: syncService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncoming = info.direction == 'incoming';

    final displayName = (info.name.isNotEmpty &&
            info.name != info.phoneNumber &&
            !info.name.toLowerCase().contains('unknown') &&
            !info.name.toLowerCase().contains('incoming caller'))
        ? info.name
        : (info.company != null && info.company!.isNotEmpty ? info.company! : 'Unsaved Contact');

    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: info.hasCrmLead
                ? colors.primary.withOpacity(0.4)
                : colors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(isDark ? 0.25 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isIncoming
                    ? (isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9))
                    : (isDark ? const Color(0xFF1E2F40) : const Color(0xFFE3F2FD)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isIncoming ? colors.success : colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isIncoming ? 'INCOMING CALL DETECTED' : 'OUTGOING CALL IN PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isIncoming
                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                            : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0)),
                      ),
                    ),
                  ),
                  if (info.isSearching)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Searching CRM...',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'CallVia360 ID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Caller Profile Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: info.hasCrmLead
                            ? [colors.primary, const Color(0xFF8B5CF6)]
                            : [colors.primaryLight, colors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name & Category Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          info.phoneNumber,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Badges Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (info.hasCrmLead)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colors.success.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 11, color: colors.success),
                                    const SizedBox(width: 4),
                                    Text(
                                      info.leadStatus != null && info.leadStatus!.isNotEmpty
                                          ? 'CRM: ${info.leadStatus}'
                                          : 'CRM Lead',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (info.isUnsaved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colors.warning.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 11, color: colors.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Unsaved in Phone',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: colors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (info.company != null && info.company!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  info.company!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
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

            const Divider(height: 1),

            // Sales Intelligence History Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_rounded, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'CRM Interaction History',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${info.totalPreviousCalls} calls logged',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (info.totalPreviousCalls > 0 && info.lastCallTime != null) ...[
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Last Call: ${_formatTime(info.lastCallTime!)} (${_formatDuration(info.lastDuration ?? 0)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (info.lastOutcome != null && info.lastOutcome!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.label_outline_rounded, size: 13, color: colors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Last Outcome: ${info.lastOutcome!.replaceAll('_', ' ').toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (info.lastNote != null && info.lastNote!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            'Note: "${info.lastNote!}"',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: colors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No previous calls on record. This is a new contact ready for lead creation.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // WhatsApp Quick Button
                  IconButton(
                    onPressed: () => syncService.openWhatsAppChat(info.phoneNumber),
                    icon: Icon(Icons.chat_rounded, color: colors.whatsappGreen),
                    tooltip: 'Open in WhatsApp',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.whatsappGreen.withOpacity(0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Dismiss Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onDismiss();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Log Lead / Outcome Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _openLeadOutcomeModal(context),
                      icon: const Icon(Icons.note_alt_outlined, size: 16),
                      label: const Text('Log Lead', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
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
