import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/telemetry_sync_service.dart';
import 'after_call_dialog.dart';

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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

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

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AfterCallDialog(
        event: tempEvent,
        callerInfo: info,
        syncService: syncService,
        onDismiss: () {},
      ),
    );
  }

  Widget _buildAvatar(CallerIdInfo currentInfo, SalesTrackColors colors, String initial) {
    final photo = currentInfo.photoUrl;
    Widget avatarChild;

    if (photo != null && photo.isNotEmpty && (photo.startsWith('http://') || photo.startsWith('https://'))) {
      avatarChild = ClipOval(
        child: Image.network(
          photo,
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackInitial(initial, currentInfo, colors),
        ),
      );
    } else {
      avatarChild = _buildFallbackInitial(initial, currentInfo, colors);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: (currentInfo.hasCrmLead ? colors.primary : const Color(0xFF0066FF)).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: avatarChild,
        ),
        // Truecaller Verified Badge on Avatar
        Positioned(
          bottom: 0,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: currentInfo.hasCrmLead ? const Color(0xFF10B981) : const Color(0xFF0066FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitial(String initial, CallerIdInfo currentInfo, SalesTrackColors colors) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: currentInfo.hasCrmLead
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFF0066FF), const Color(0xFF0044CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: syncService,
      builder: (context, _) {
        final currentInfo = syncService.activeCallerId ?? info;
        final colors = context.stColors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isIncoming = currentInfo.direction == 'incoming';

        final displayName = (currentInfo.name.isNotEmpty &&
                currentInfo.name != currentInfo.phoneNumber &&
                !currentInfo.name.toLowerCase().contains('unknown') &&
                !currentInfo.name.toLowerCase().contains('incoming caller'))
            ? currentInfo.name
            : (currentInfo.company != null && currentInfo.company!.isNotEmpty
                ? currentInfo.company!
                : 'Unsaved Number');

        final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

        // Truecaller Header Color (Blue or Emerald for verified lead)
        final headerColor = currentInfo.hasCrmLead ? const Color(0xFF10B981) : const Color(0xFF0066FF);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: screenSize.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.6 : 0.22),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Truecaller Signature Top Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIncoming ? 'INCOMING CALL' : 'OUTGOING CALL',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                currentInfo.hasCrmLead
                                    ? 'Identified CRM Lead'
                                    : 'CallVia360 Caller ID',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (currentInfo.isSearching)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Searching...',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          IconButton(
                            onPressed: () {
                              onDismiss();
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),

                  // 2. Main Identity & Profile Area (Large Truecaller Layout)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(currentInfo, colors, initial),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Contact / Lead Name
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // Formatted Phone Number
                              Text(
                                currentInfo.phoneNumber,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Verification & CRM Badge
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (currentInfo.hasCrmLead)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                                          const SizedBox(width: 4),
                                          Text(
                                            currentInfo.leadStatus != null && currentInfo.leadStatus!.isNotEmpty
                                                ? currentInfo.leadStatus!
                                                : 'CRM Lead',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (currentInfo.isUnsaved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_search_rounded, size: 12, color: Color(0xFFF59E0B)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Unsaved Number',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (currentInfo.company != null && currentInfo.company!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.business_rounded, size: 12, color: colors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            currentInfo.company!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
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

                  // 3. Sales & Interaction Intelligence Box (CRM History)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: headerColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.analytics_outlined, size: 16, color: headerColor),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'CRM Sales Intelligence',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: headerColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${currentInfo.totalPreviousCalls} Calls Logged',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: headerColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (currentInfo.totalPreviousCalls > 0 && currentInfo.lastCallTime != null) ...[
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: colors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Last Call: ${_formatTime(currentInfo.lastCallTime!)} (${_formatDuration(currentInfo.lastDuration ?? 0)})',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (currentInfo.lastOutcome != null && currentInfo.lastOutcome!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.label_important_rounded, size: 14, color: headerColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Outcome: ${currentInfo.lastOutcome!.replaceAll('_', ' ').toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (currentInfo.lastNote != null && currentInfo.lastNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF111827) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.format_quote_rounded, size: 16, color: colors.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        currentInfo.lastNote!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (currentInfo.followUpAt != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Follow-up due: ${_formatTime(currentInfo.followUpAt!)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'No previous call logs found. New contact detected — tap "Log Lead" to add remarks and follow-up.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Truecaller-Style Bottom Action Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: Row(
                      children: [
                        // WhatsApp Button
                        _buildCircleActionButton(
                          icon: Icons.chat_rounded,
                          color: const Color(0xFF25D366),
                          label: 'WhatsApp',
                          onTap: () => syncService.openWhatsAppChat(currentInfo.phoneNumber),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),

                        // Dismiss Button
                        _buildCircleActionButton(
                          icon: Icons.close_rounded,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          label: 'Dismiss',
                          onTap: () {
                            onDismiss();
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),

                        // Prominent "Log Lead" Button (Truecaller style primary action)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openLeadOutcomeModal(context),
                            icon: const Icon(Icons.post_add_rounded, size: 18),
                            label: const Text(
                              'Log Lead',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
