import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacySettingsView extends StatefulWidget {
  const PrivacySettingsView({super.key});

  @override
  State<PrivacySettingsView> createState() => _PrivacySettingsViewState();
}

class _PrivacySettingsViewState extends State<PrivacySettingsView> {
  bool _enforceWorkHours = true;
  bool _e2eeEnabled = true;
  bool _twoPartyConsentTone = true;
  bool _autoRedactPii = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Fleet Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Work Hours Auto-Pause Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule, color: AppColors.accentCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Work-Hours Tracking Schedule',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enforceWorkHours,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _enforceWorkHours = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Automatically stops call recording and activity tracking outside of corporate hours to protect employee personal privacy.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Days:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text('Monday – Friday', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Hours:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text('08:30 AM – 06:30 PM (EST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentEmerald)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dual-SIM Hardware Isolation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sim_card_outlined, color: AppColors.accentEmerald, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Hardware Dual-SIM Routing',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimStatusTile(
                    slot: 'SIM Slot 1',
                    carrier: 'AT&T Business (+1 415-700-1122)',
                    status: 'TRACKED & ENCRYPTED',
                    color: AppColors.accentEmerald,
                  ),
                  const SizedBox(height: 8),
                  _SimStatusTile(
                    slot: 'SIM Slot 2',
                    carrier: 'Verizon Personal (+1 415-300-9988)',
                    status: 'EXCLUDED / PRIVACY LOCKED',
                    color: AppColors.accentRose,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Security Controls Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ENTERPRISE COMPLIANCE & KMS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End-to-End Encryption (AES-256-GCM)', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Local encryption before cloud upload', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _e2eeEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _e2eeEnabled = val),
                  ),
                  const Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Two-Party Consent Periodic Beep', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Plays audible tone every 15s for legal compliance', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _twoPartyConsentTone,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _twoPartyConsentTone = val),
                  ),
                  const Divider(color: AppColors.borderSubtle),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Redact PII in Whisper Transcripts', style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                    subtitle: const Text('Masks credit cards and SSNs automatically', style: TextStyle(fontSize: 11, color: AppColors.textDim)),
                    value: _autoRedactPii,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _autoRedactPii = val),
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

class _SimStatusTile extends StatelessWidget {
  final String slot;
  final String carrier;
  final String status;
  final Color color;

  const _SimStatusTile({
    required this.slot,
    required this.carrier,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMain)),
              const SizedBox(height: 2),
              Text(carrier, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
