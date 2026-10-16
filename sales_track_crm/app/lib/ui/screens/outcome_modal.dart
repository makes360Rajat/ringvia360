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

  Color _getToneColor(String tone) {
    switch (tone.toLowerCase()) {
      case 'green':
        return SalesTrackTheme.success;
      case 'amber':
      case 'orange':
        return SalesTrackTheme.warning;
      case 'violet':
      case 'purple':
        return SalesTrackTheme.secondaryLight;
      case 'rose':
      case 'red':
        return SalesTrackTheme.danger;
      default:
        return SalesTrackTheme.surfaceLight;
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
    final config = widget.syncService.config;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
      decoration: const BoxDecoration(
        color: SalesTrackTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SalesTrackTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.call_end_rounded, color: SalesTrackTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'After-Call Outcome',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SalesTrackTheme.textPrimary),
                      ),
                      Text(
                        '${widget.event.name.isNotEmpty ? widget.event.name : widget.event.number} • ${widget.event.duration}s talk',
                        style: const TextStyle(fontSize: 13, color: SalesTrackTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.syncService.dismissAfterCallPopup();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded, color: SalesTrackTheme.textMuted),
                )
              ],
            ),
            const SizedBox(height: 18),

            // Outcome Chips
            const Text('Outcome', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SalesTrackTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: config.outcomesList.map((outcome) {
                final isSelected = _selectedOutcomeKey == outcome.key;
                final toneColor = _getToneColor(outcome.tone);
                return ChoiceChip(
                  label: Text(outcome.label),
                  selected: isSelected,
                  selectedColor: toneColor.withOpacity(0.25),
                  backgroundColor: SalesTrackTheme.surfaceColor,
                  labelStyle: TextStyle(
                    color: isSelected ? toneColor : SalesTrackTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: isSelected ? toneColor : Colors.transparent),
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
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: config.outcomesNoteRequired ? 'Call note (required)...' : 'Add a note about this call...',
                prefixIcon: const Icon(Icons.notes_rounded, color: SalesTrackTheme.textMuted),
              ),
            ),
            const SizedBox(height: 14),

            // Follow-up Date Picker
            if (_selectedOutcomeKey != null && config.outcomesList.firstWhere((o) => o.key == _selectedOutcomeKey, orElse: () => config.outcomesList.first).followUp) ...[
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: SalesTrackTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: SalesTrackTheme.primaryLight, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _followUpDate != null
                            ? 'Follow-up: ${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year} ${_followUpDate!.hour.toString().padLeft(2, '0')}:${_followUpDate!.minute.toString().padLeft(2, '0')}'
                            : 'Set Follow-up reminder',
                        style: const TextStyle(color: SalesTrackTheme.textPrimary, fontSize: 14),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, color: SalesTrackTheme.textMuted, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Create Lead Input (for unknown callers)
            if (config.outcomesCreateLead) ...[
              TextField(
                controller: _leadNameController,
                decoration: const InputDecoration(
                  labelText: 'Create CRM Lead (Optional)',
                  hintText: 'Lead or company name',
                  prefixIcon: Icon(Icons.person_add_rounded, color: SalesTrackTheme.textMuted),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Outcome'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
