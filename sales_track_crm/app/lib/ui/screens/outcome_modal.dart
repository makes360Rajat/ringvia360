import 'package:flutter/material.dart';
import '../../core/theme/sales_track_theme.dart';
import '../../models/sales_track_models.dart';
import '../../services/telemetry_sync_service.dart';

class OutcomeModal extends StatefulWidget {
  final SalesTrackEvent event;
  final TelemetrySyncService syncService;

  const OutcomeModal({
    super.key,
    required this.event,
    required this.syncService,
  });

  @override
  State<OutcomeModal> createState() => _OutcomeModalState();
}

class _OutcomeModalState extends State<OutcomeModal> {
  String? _selectedOutcomeKey;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _leadNameController = TextEditingController();
  DateTime? _followUpDate;
  int? _selectedLeadStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final config = widget.syncService.config;
    if (config.outcomesList.isNotEmpty) {
      _selectedOutcomeKey = config.outcomesList.first.key;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _leadNameController.dispose();
    super.dispose();
  }

  Color _getToneColor(String tone, SalesTrackColors colors) {
    switch (tone.toLowerCase()) {
      case 'green':
        return colors.success;
      case 'amber':
      case 'orange':
        return colors.warning;
      case 'violet':
      case 'purple':
        return colors.secondaryLight;
      case 'rose':
      case 'red':
        return colors.danger;
      default:
        return colors.textSecondary;
    }
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
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call outcome logged successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit outcome. Saved to offline queue.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.stColors;
    final isDark = context.isDarkMode;
    final config = widget.syncService.config;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.call_end_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Call Outcome',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.event.name.isNotEmpty ? widget.event.name : widget.event.number} • ${widget.event.duration}s talk',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      widget.syncService.dismissAfterCallPopup();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.close_rounded, color: colors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Outcome Chips
              Text(
                'SELECT OUTCOME',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: config.outcomesList.map((outcome) {
                  final isSelected = _selectedOutcomeKey == outcome.key;
                  final toneColor = _getToneColor(outcome.tone, colors);
                  return ChoiceChip(
                    label: Text(outcome.label),
                    selected: isSelected,
                    selectedColor: toneColor.withOpacity(0.18),
                    backgroundColor: colors.surfaceColor,
                    labelStyle: TextStyle(
                      color: isSelected ? toneColor : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? toneColor : colors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedOutcomeKey = outcome.key;
                          if (outcome.followUp && _followUpDate == null) {
                            _followUpDate = DateTime.now().add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Note Input
              Text(
                'CALL NOTE ${config.outcomesNoteRequired ? "(REQUIRED)" : "(OPTIONAL)"}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: config.outcomesNoteRequired
                      ? 'Enter mandatory summary of the discussion...'
                      : 'Add summary notes from this call...',
                  prefixIcon: Icon(Icons.notes_rounded, color: colors.textMuted),
                ),
              ),
              const SizedBox(height: 14),

              // Follow-up Date Picker
              if (_selectedOutcomeKey != null &&
                  config.outcomesList
                      .firstWhere((o) => o.key == _selectedOutcomeKey,
                          orElse: () => config.outcomesList.first)
                      .followUp) ...[
                Text(
                  'FOLLOW-UP SCHEDULE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 10, minute: 0),
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
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: colors.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _followUpDate != null
                              ? 'Follow-up: ${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year} ${_followUpDate!.hour.toString().padLeft(2, '0')}:${_followUpDate!.minute.toString().padLeft(2, '0')}'
                              : 'Set Follow-up reminder date & time',
                          style: TextStyle(
                            color: _followUpDate != null ? colors.textPrimary : colors.textMuted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_month_rounded, color: colors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Create Lead Input (for unknown callers)
              if (config.outcomesCreateLead) ...[
                Text(
                  'CREATE NEW CRM LEAD (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _leadNameController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Lead person or company name',
                    prefixIcon: Icon(Icons.person_add_rounded, color: colors.textMuted),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Call Outcome',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
