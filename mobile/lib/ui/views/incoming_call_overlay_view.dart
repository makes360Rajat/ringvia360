import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../view_models/dialer_view_model.dart';

class IncomingCallOverlayView extends StatelessWidget {
  const IncomingCallOverlayView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DialerViewModel>();
    if (!viewModel.isIncomingCallRinging) return const SizedBox.shrink();

    return Material(
      color: AppColors.bgBase.withOpacity(0.97),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Incoming Call Pill Badge
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ring_volume, size: 14, color: AppColors.accentCyan),
                        SizedBox(width: 8),
                        Text(
                          'INCOMING CALL • SIM 1 (WORK)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RingVia360 Telephony Listener Active',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                ],
              ),

              // Contact Avatar & Caller ID
              Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accentCyan, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.35),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&auto=format&fit=crop&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    viewModel.activeContactName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${viewModel.activeCompany} • ${viewModel.inputNumber}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Matching Lead in RingVia360 CRM (₹72,000 Opportunity)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentEmerald,
                      ),
                    ),
                  ),
                ],
              ),

              // Call Controls: Decline (Red) & Accept (Green)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Decline / Missed Button
                    GestureDetector(
                      onTap: viewModel.declineIncomingCall,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.accentRose,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentRose.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Decline',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),

                    // Accept / Answer Button
                    GestureDetector(
                      onTap: viewModel.answerIncomingCall,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.accentEmerald, Color(0xFF059669)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentEmerald.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.phone, color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Accept',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentEmerald),
                          ),
                        ],
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
  }
}
