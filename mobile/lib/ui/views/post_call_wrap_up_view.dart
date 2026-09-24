import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/call_record.dart';
import '../view_models/dialer_view_model.dart';

class PostCallWrapUpView extends StatefulWidget {
  const PostCallWrapUpView({super.key});

  @override
  State<PostCallWrapUpView> createState() => _PostCallWrapUpViewState();
}

class _PostCallWrapUpViewState extends State<PostCallWrapUpView> {
  String _selectedOutcome = 'Demo Completed - Contract Requested';
  final _notesController = TextEditingController(
    text: 'Client validated RingVia360 mobile dialer. Confirmed 50 seats pilot.',
  );
  final _dealValueController = TextEditingController(text: '48000');
  SentimentScore _selectedSentiment = SentimentScore.positive;
  final String _selectedCrm = 'RingVia360';

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
    if (wrapUpCall == null) return const SizedBox.shrink();

    final mins = wrapUpCall.durationSeconds ~/ 60;
    final secs = wrapUpCall.durationSeconds % 60;

    return Material(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderGlass),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          color: AppColors.primary.withOpacity(0.4),
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
            color: isSelected ? color.withOpacity(0.2) : AppColors.bgSurface,
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
