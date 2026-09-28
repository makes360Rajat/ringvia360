import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/call_record.dart';
import '../../data/services/local_recording_service.dart';
import '../view_models/dialer_view_model.dart';

class PostCallWrapUpView extends StatefulWidget {
  const PostCallWrapUpView({super.key});

  @override
  State<PostCallWrapUpView> createState() => _PostCallWrapUpViewState();
}

class _PostCallWrapUpViewState extends State<PostCallWrapUpView> {
  String _selectedOutcome = 'Demo Completed - Contract Requested';
  final _notesController = TextEditingController();
  final _dealValueController = TextEditingController(text: '0');
  SentimentScore _selectedSentiment = SentimentScore.neutral;
  final String _selectedCrm = 'RingVia360';
  String? _initializedCallId;

  /// Populate fields from the wrapUpCall once per unique call ID — avoid overwriting user edits on rebuild.
  void _maybeInit(CallRecord call) {
    if (_initializedCallId == call.id) return;
    _initializedCallId = call.id;
    _notesController.text = call.notes.isNotEmpty ? call.notes : '';
    _dealValueController.text = call.dealValue > 0
        ? call.dealValue.toStringAsFixed(0)
        : '0';
    _selectedSentiment = call.sentiment;
    const validOutcomes = [
      'Demo Completed - Contract Requested',
      'Follow-up Scheduled',
      'Gatekeeper Blocked',
      'Left Voicemail',
    ];
    if (validOutcomes.contains(call.outcome)) {
      _selectedOutcome = call.outcome;
    } else {
      _selectedOutcome = 'Demo Completed - Contract Requested';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _dealValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DialerViewModel>();
    final wrapUpCall = viewModel.wrapUpCall;
    if (wrapUpCall == null) {
      _initializedCallId = null;
      return const SizedBox.shrink();
    }

    // Pre-fill form the first time the overlay appears for this call
    _maybeInit(wrapUpCall);

    final isBackgroundCall = wrapUpCall.id.startsWith('native-call-');
    final mins = wrapUpCall.durationSeconds ~/ 60;
    final secs = wrapUpCall.durationSeconds % 60;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = (screenHeight - viewInsets.bottom).clamp(320.0, screenHeight);

    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom > 0 ? viewInsets.bottom : 0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutQuad,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap inside container from unfocusing
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  constraints: BoxConstraints(
                    maxHeight: availableHeight * 0.88,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderGlass),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // Top Header Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Post-Call Wrap-up',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        // Badge shown only for background-recorded calls
                        if (isBackgroundCall) ...
                          [
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2A1A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.accentEmerald.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.fiber_manual_record, size: 8, color: AppColors.accentEmerald),
                                  SizedBox(width: 4),
                                  Text(
                                    'BG Recorded',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentEmerald),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textDim, size: 20),
                      onPressed: viewModel.dismissWrapUp,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Call Meta Title
                Text(
                  wrapUpCall.contactName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain),
                ),
                Text(
                  '${wrapUpCall.company} • Duration: ${mins}m ${secs}s • Recorded & Encrypted',
                  style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                        ? AppColors.accentEmerald.withValues(alpha: 0.1)
                        : AppColors.accentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                          ? AppColors.accentEmerald.withValues(alpha: 0.25)
                          : AppColors.accentAmber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                            ? Icons.mic
                            : Icons.mic_none,
                        size: 14,
                        color: (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                            ? AppColors.accentEmerald
                            : AppColors.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                              ? wrapUpCall.recordingPath!.split('/').last
                              : 'No auto-recording linked',
                          style: TextStyle(
                            fontSize: 11,
                            color: (wrapUpCall.recordingPath != null && wrapUpCall.recordingPath!.isNotEmpty)
                                ? AppColors.accentEmerald
                                : AppColors.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final service = context.read<LocalRecordingService>();
                          final picked = await service.pickAndImportAudio();
                          if (picked != null) {
                            viewModel.setWrapUpRecordingPath(picked.filePath);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Select Audio', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 28, color: AppColors.borderSubtle),

                // Outcome Disposition
                const Text(
                  'CALL DISPOSITION / OUTCOME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedOutcome,
                      isExpanded: true,
                      dropdownColor: AppColors.bgSurfaceElevated,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                      items: const [
                        DropdownMenuItem(
                          value: 'Demo Completed - Contract Requested',
                          child: Text('Demo Completed - Contract Requested'),
                        ),
                        DropdownMenuItem(
                          value: 'Follow-up Scheduled',
                          child: Text('Follow-up Scheduled'),
                        ),
                        DropdownMenuItem(
                          value: 'Gatekeeper Blocked',
                          child: Text('Gatekeeper Blocked'),
                        ),
                        DropdownMenuItem(
                          value: 'Left Voicemail',
                          child: Text('Left Voicemail'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedOutcome = val!),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes Field
                const Text(
                  'CALL NOTES (SYNCS TO CRM TASK)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    hintText: 'Enter notes or tap mic for voice-to-text...',
                    hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 16),

                // Deal Pipeline Amount
                const Text(
                  'PIPELINE DEAL VALUE (₹ INR)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _dealValueController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgSurface,
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: AppColors.accentEmerald),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sentiment Selector
                const Text(
                  'BUYER SENTIMENT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _SentimentPill(
                      label: 'Positive',
                      isSelected: _selectedSentiment == SentimentScore.positive,
                      color: AppColors.accentEmerald,
                      onTap: () => setState(() => _selectedSentiment = SentimentScore.positive),
                    ),
                    const SizedBox(width: 8),
                    _SentimentPill(
                      label: 'Neutral',
                      isSelected: _selectedSentiment == SentimentScore.neutral,
                      color: AppColors.accentAmber,
                      onTap: () => setState(() => _selectedSentiment = SentimentScore.neutral),
                    ),
                    const SizedBox(width: 8),
                    _SentimentPill(
                      label: 'Objection / Risk',
                      isSelected: _selectedSentiment == SentimentScore.negative,
                      color: AppColors.accentRose,
                      onTap: () => setState(() => _selectedSentiment = SentimentScore.negative),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit Button
                GestureDetector(
                  onTap: () {
                    viewModel.submitWrapUp(
                      outcome: _selectedOutcome,
                      notes: _notesController.text,
                      sentiment: _selectedSentiment,
                      dealValue: double.tryParse(_dealValueController.text) ?? 20000,
                      crmType: _selectedCrm,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.bgSurfaceElevated,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.accentEmerald, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Call logged and queued for $_selectedCrm sync!',
                              style: const TextStyle(color: AppColors.textMain),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Save & Push to $_selectedCrm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentimentPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SentimentPill({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? color : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
