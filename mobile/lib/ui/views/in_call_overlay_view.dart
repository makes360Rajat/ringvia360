import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../view_models/dialer_view_model.dart';

class InCallOverlayView extends StatelessWidget {
  const InCallOverlayView({super.key});

  String _formatTimer(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DialerViewModel>();
    if (!viewModel.isInCall) return const SizedBox.shrink();

    return Material(
      color: AppColors.bgBase.withOpacity(0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Tags
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentEmerald.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 10, color: AppColors.accentEmerald),
                        SizedBox(width: 6),
                        Text(
                          'Call Recording & E2EE Active',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentEmerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Contact Avatar & Name
              Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    viewModel.dialedNumber.isNotEmpty
                        ? viewModel.dialedNumber
                        : viewModel.activeContactName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    viewModel.dialedNumber.isNotEmpty && viewModel.activeContactName != viewModel.dialedNumber
                        ? '${viewModel.activeContactName} • ${viewModel.activeCompany}'
                        : viewModel.activeCompany,
                    style: const TextStyle(fontSize: 15, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatTimer(viewModel.callDurationSeconds),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: AppColors.accentCyan,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Connect via Carrier / Native Phone dialer
                  GestureDetector(
                    onTap: () => viewModel.launchNativeDialer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_forwarded, color: AppColors.accentCyan, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Open Phone App (tel:)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Mid Controls Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InCallControlBtn(
                    icon: viewModel.isMuted ? Icons.mic_off : Icons.mic,
                    label: viewModel.isMuted ? 'Muted' : 'Mute',
                    isActive: viewModel.isMuted,
                    onTap: viewModel.toggleMute,
                  ),
                  _InCallControlBtn(
                    icon: Icons.dialpad,
                    label: 'Keypad',
                    isActive: false,
                    onTap: () {},
                  ),
                  _InCallControlBtn(
                    icon: viewModel.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: 'Speaker',
                    isActive: viewModel.isSpeakerOn,
                    onTap: viewModel.toggleSpeaker,
                  ),
                ],
              ),

              // End Call Red Button & Wrap-Up Tracker trigger
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: viewModel.endCall,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.accentRose,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentRose.withOpacity(0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 34),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'End Call & Open Wrap-Up Tracker',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentRose,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InCallControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _InCallControlBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.bgSurfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(icon, color: isActive ? Colors.white : AppColors.textMain, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}
