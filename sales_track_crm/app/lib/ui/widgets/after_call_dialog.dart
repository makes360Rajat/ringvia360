import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/telemetry_sync_service.dart';

class AfterCallDialog extends StatefulWidget {
  final SalesTrackEvent event;
  final TelemetrySyncService syncService;
  final CallerIdInfo? callerInfo;
  final VoidCallback onDismiss;

  const AfterCallDialog({
    super.key,
    required this.event,
    required this.syncService,
    this.callerInfo,
    required this.onDismiss,
  });

  @override
  State<AfterCallDialog> createState() => _AfterCallDialogState();
}

class _AfterCallDialogState extends State<AfterCallDialog> with SingleTickerProviderStateMixin {
  String? _selectedOutcomeKey;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _leadNameController = TextEditingController();
  DateTime? _followUpDate;
  int? _selectedLeadStatus;
  bool _isSubmitting = false;
  bool _isEditingName = false;
  Uint8List? _contactPhotoBytes;
  CallerIdInfo? _enrichedInfo;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static final List<OutcomeOptionModel> _defaultOutcomes = [
    OutcomeOptionModel(key: 'interested', label: 'Interested', tone: 'green', followUp: true, leadStatus: 1, fixed: false),
    OutcomeOptionModel(key: 'callback', label: 'Callback Requested', tone: 'amber', followUp: true, leadStatus: 1, fixed: false),
    OutcomeOptionModel(key: 'meeting', label: 'Meeting Fixed', tone: 'purple', followUp: true, leadStatus: 2, fixed: false),
    OutcomeOptionModel(key: 'busy', label: 'Busy / In Meeting', tone: 'orange', followUp: true, leadStatus: 0, fixed: false),
    OutcomeOptionModel(key: 'not_interested', label: 'Not Interested', tone: 'rose', followUp: false, leadStatus: 3, fixed: false),
    OutcomeOptionModel(key: 'wrong_number', label: 'Wrong Number', tone: 'slate', followUp: false, leadStatus: 4, fixed: false),
    OutcomeOptionModel(key: 'deal_won', label: 'Deal Closed', tone: 'green', followUp: false, leadStatus: 5, fixed: false),
    OutcomeOptionModel(key: 'rnr', label: 'RNR (No Answer)', tone: 'slate', followUp: true, leadStatus: 0, fixed: false),
  ];

  static const List<String> _quickNoteChips = [
    'Quotation sent on WhatsApp',
    'Callback requested tomorrow',
    'Discussed pricing & discount',
    'Quotation shared',
    'Decision maker in meeting',
    'Interested in software demo',
    'Meeting scheduled',
    'Follow up next week',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();

    final config = widget.syncService.config;
    final available = config.outcomesList.isNotEmpty ? config.outcomesList : _defaultOutcomes;
    _selectedOutcomeKey = available.first.key;

    _enrichedInfo = widget.callerInfo ?? widget.syncService.activeCallerId;

    final initialName = widget.event.name.isNotEmpty &&
            widget.event.name != widget.event.number &&
            !widget.event.name.toLowerCase().contains('unknown') &&
            !widget.event.name.toLowerCase().contains('caller')
        ? widget.event.name
        : (_enrichedInfo?.name.isNotEmpty == true &&
                _enrichedInfo!.name != widget.event.number &&
                !_enrichedInfo!.name.toLowerCase().contains('unknown')
            ? _enrichedInfo!.name
            : '');

    if (initialName.isNotEmpty) {
      _leadNameController.text = initialName;
    }

    _loadContactPhoto();
  }

  Future<void> _loadContactPhoto() async {
    final photoUri = _enrichedInfo?.photoUrl;
    final bytes = await widget.syncService.getContactPhotoBytes(
      photoUri: photoUri,
      phoneNumber: widget.event.number,
    );
    if (mounted && bytes != null && bytes.isNotEmpty) {
      setState(() {
        _contactPhotoBytes = bytes;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    _leadNameController.dispose();
    super.dispose();
  }

  void _addQuickNote(String chip) {
    final current = _noteController.text.trim();
    if (current.isEmpty) {
      _noteController.text = chip;
    } else {
      _noteController.text = '$current • $chip';
    }
    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
    setState(() {});
  }

  void _setFollowUpPreset(Duration offset, {int targetHour = 10}) {
    final now = DateTime.now();
    DateTime target = now.add(offset);
    if (offset.inDays > 0) {
      target = DateTime(target.year, target.month, target.day, targetHour, 0);
    }
    setState(() {
      _followUpDate = target;
    });
  }

  Future<void> _pickCustomFollowUp() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _followUpDate != null
            ? TimeOfDay.fromDateTime(_followUpDate!)
            : const TimeOfDay(hour: 10, minute: 0),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _followUpDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Color _getToneColor(String tone, SalesTrackColors colors) {
    switch (tone.toLowerCase()) {
      case 'green':
        return const Color(0xFF10B981);
      case 'amber':
      case 'orange':
        return const Color(0xFFF59E0B);
      case 'violet':
      case 'purple':
        return const Color(0xFF8B5CF6);
      case 'rose':
      case 'red':
        return const Color(0xFFEF4444);
      default:
        return colors.textSecondary;
    }
  }

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
    return '${d.day}/${d.month} at $timeStr';
  }

  Future<void> _submit() async {
    if (_selectedOutcomeKey == null) return;
    final config = widget.syncService.config;
    if (config.outcomesNoteRequired && _noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A note is required for this call outcome')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await widget.syncService.submitCallOutcome(
      uid: widget.event.uid,
      outcomeKey: _selectedOutcomeKey!,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      followUpDate: _followUpDate,
      leadStatus: _selectedLeadStatus,
      createLeadName: _leadNameController.text.trim().isNotEmpty ? _leadNameController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      widget.onDismiss();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(success ? 'Call outcome & lead logged to CRM!' : 'Outcome saved to offline queue'),
            ],
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildAvatar(SalesTrackColors colors, String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    Widget avatarContent;
    if (_contactPhotoBytes != null) {
      avatarContent = Image.memory(
        _contactPhotoBytes!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    } else if (_enrichedInfo?.photoUrl != null &&
        _enrichedInfo!.photoUrl!.isNotEmpty &&
        (_enrichedInfo!.photoUrl!.startsWith('http://') || _enrichedInfo!.photoUrl!.startsWith('https://'))) {
      avatarContent = Image.network(
        _enrichedInfo!.photoUrl!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackInitial(initial),
      );
    } else {
      avatarContent = _buildFallbackInitial(initial);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0066FF).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ClipOval(child: avatarContent),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.check, size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0066FF), Color(0xFF0044CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final isDark = context.isDarkMode;
    final config = widget.syncService.config;

    final isMissed = widget.event.direction == 'missed' || (widget.event.direction == 'incoming' && widget.event.duration == 0);
    final isOutgoing = widget.event.direction == 'outgoing';

    // Truecaller colors
    final headerGradient = isMissed
        ? const [Color(0xFFDC2626), Color(0xFFB91C1C)]
        : const [Color(0xFF0066FF), Color(0xFF004BB8)];

    final displayName = _leadNameController.text.trim().isNotEmpty
        ? _leadNameController.text.trim()
        : (widget.event.name.isNotEmpty &&
                widget.event.name != widget.event.number &&
                !widget.event.name.toLowerCase().contains('unknown')
            ? widget.event.name
            : 'Unsaved Contact');

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.55 : 0.22),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Signature Truecaller Top Header Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: headerGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isMissed ? 'MISSED CALL' : 'CALL COMPLETED',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  widget.onDismiss();
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                isMissed
                                    ? Icons.call_missed_rounded
                                    : (isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMissed
                                    ? 'Missed call • 0s'
                                    : '${isOutgoing ? "Outgoing Call" : "Incoming Call"} • ${_formatDuration(widget.event.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTime(widget.event.time),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. Caller Identity Card
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(colors, displayName),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Editable Lead Name
                                if (_isEditingName)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _leadNameController,
                                          autofocus: true,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter lead / contact name',
                                            hintStyle: TextStyle(fontSize: 13, color: colors.textMuted),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF0066FF)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.check_rounded, color: Color(0xFF10B981)),
                                        onPressed: () => setState(() => _isEditingName = false),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                                else
                                  InkWell(
                                    onTap: () => setState(() => _isEditingName = true),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: colors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: const Color(0xFF0066FF).withOpacity(0.8),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 4),

                                // Phone number row
                                Row(
                                  children: [
                                    Text(
                                      widget.event.number,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: widget.event.number));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Phone number copied!'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Icon(Icons.copy_rounded, size: 13, color: colors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Badges: SIM & Recording
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'SIM ${widget.event.sim}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (widget.event.recording) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.mic_rounded, size: 10, color: Color(0xFF10B981)),
                                            SizedBox(width: 3),
                                            Text(
                                              'Audio Saved',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Sales & Call Tracking Body
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section: Select Outcome
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF0066FF)),
                              const SizedBox(width: 6),
                              Text(
                                'CALL OUTCOME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (config.outcomesList.isNotEmpty ? config.outcomesList : _defaultOutcomes).map((outcome) {
                              final isSelected = _selectedOutcomeKey == outcome.key;
                              final toneColor = _getToneColor(outcome.tone, colors);
                              return ChoiceChip(
                                label: Text(
                                  outcome.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : colors.textPrimary,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: toneColor,
                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                side: BorderSide(
                                  color: isSelected ? toneColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedOutcomeKey = outcome.key;
                                      _selectedLeadStatus = outcome.leadStatus;
                                      if (outcome.followUp && _followUpDate == null) {
                                        _setFollowUpPreset(const Duration(days: 1), targetHour: 10);
                                      }
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Section: Sales Remarks & Notes
                          Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0066FF)),
                              const SizedBox(width: 6),
                              Text(
                                'SALES REMARKS & NOTES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteController,
                            maxLines: 2,
                            style: TextStyle(fontSize: 13, color: colors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Add conversation notes, customer requirements...',
                              hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Quick Note Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _quickNoteChips.map((chip) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      chip,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    onPressed: () => _addQuickNote(chip),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section: Next Follow-Up Reminder
                          Row(
                            children: [
                              const Icon(Icons.alarm_rounded, size: 15, color: Color(0xFF0066FF)),
                              const SizedBox(width: 6),
                              Text(
                                'NEXT FOLLOW-UP',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: colors.textMuted,
                                ),
                              ),
                              const Spacer(),
                              if (_followUpDate != null)
                                InkWell(
                                  onTap: () => setState(() => _followUpDate = null),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Follow-Up Presets
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildFollowUpPresetChip('+2 Hours', () => _setFollowUpPreset(const Duration(hours: 2)), isDark),
                              _buildFollowUpPresetChip('Tomorrow 10 AM', () => _setFollowUpPreset(const Duration(days: 1), targetHour: 10), isDark),
                              _buildFollowUpPresetChip('In 3 Days', () => _setFollowUpPreset(const Duration(days: 3), targetHour: 10), isDark),
                              _buildFollowUpPresetChip('Next Monday', () {
                                final now = DateTime.now();
                                final daysToMon = (DateTime.monday - now.weekday + 7) % 7;
                                _setFollowUpPreset(Duration(days: daysToMon == 0 ? 7 : daysToMon), targetHour: 10);
                              }, isDark),
                              ActionChip(
                                avatar: const Icon(Icons.event_rounded, size: 14, color: Color(0xFF0066FF)),
                                label: Text(
                                  _followUpDate != null ? _formatFollowUpDisplay(_followUpDate!) : 'Pick Date',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _followUpDate != null ? const Color(0xFF0066FF) : colors.textSecondary,
                                  ),
                                ),
                                backgroundColor: _followUpDate != null
                                    ? const Color(0xFF0066FF).withOpacity(0.12)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                side: BorderSide(
                                  color: _followUpDate != null
                                      ? const Color(0xFF0066FF)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onPressed: _pickCustomFollowUp,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 4. Truecaller Bottom Action Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // WhatsApp Button
                          _buildCircleActionButton(
                            icon: Icons.chat_rounded,
                            color: const Color(0xFF25D366),
                            label: 'WhatsApp',
                            onTap: () => widget.syncService.openWhatsAppChat(widget.event.number),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),

                          // Call Back Button
                          _buildCircleActionButton(
                            icon: Icons.call_rounded,
                            color: const Color(0xFF0066FF),
                            label: 'Call Back',
                            onTap: () => widget.syncService.dialPhoneNumber(widget.event.number),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),

                          // Dismiss Button
                          _buildCircleActionButton(
                            icon: Icons.close_rounded,
                            color: colors.textMuted,
                            label: 'Skip',
                            onTap: () {
                              widget.onDismiss();
                              Navigator.of(context).pop();
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(width: 10),

                          // Save & Log Lead Button (Primary Truecaller Action)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.cloud_upload_rounded, size: 18),
                              label: Text(
                                _isSubmitting ? 'Saving...' : 'SAVE & LOG',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0066FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
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
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpPresetChip(String label, VoidCallback onTap, bool isDark) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onPressed: onTap,
    );
  }

  String _formatFollowUpDisplay(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow = dt.difference(DateTime(now.year, now.month, now.day)).inDays == 1;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today at $time';
    if (isTomorrow) return 'Tmrw at $time';
    return '${dt.day}/${dt.month} $time';
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
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
