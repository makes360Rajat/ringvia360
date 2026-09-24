import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/call_record.dart';
import '../view_models/call_feed_view_model.dart';

class ActivityFeedView extends StatelessWidget {
  const ActivityFeedView({super.key});

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0s (Missed)';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CallFeedViewModel>();
    final calls = viewModel.filteredCalls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: viewModel.loadCalls,
            tooltip: 'Refresh Feed',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Search Field
                TextField(
                  onChanged: viewModel.setSearchQuery,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                  decoration: InputDecoration(
                    hintText: 'Search call logs, contacts...',
                    hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textDim, size: 18),
                    filled: true,
                    fillColor: AppColors.bgSurfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Direction Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Calls',
                        isSelected: viewModel.selectedDirectionFilter == null,
                        onTap: () => viewModel.setFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Inbound',
                        isSelected: viewModel.selectedDirectionFilter == CallDirection.inbound,
                        onTap: () => viewModel.setFilter(CallDirection.inbound),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Outbound',
                        isSelected: viewModel.selectedDirectionFilter == CallDirection.outbound,
                        onTap: () => viewModel.setFilter(CallDirection.outbound),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Missed',
                        isSelected: viewModel.selectedDirectionFilter == CallDirection.missed,
                        onTap: () => viewModel.setFilter(CallDirection.missed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Call List
          Expanded(
            child: calls.isEmpty
                ? const Center(
                    child: Text('No calls match your filter', style: TextStyle(color: AppColors.textDim)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: calls.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final call = calls[index];
                      final isPlaying = viewModel.currentlyPlayingCallId == call.id && viewModel.isPlaying;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Direction, Time, CRM Sync Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      call.direction == CallDirection.inbound
                                          ? Icons.call_received
                                          : call.direction == CallDirection.outbound
                                              ? Icons.call_made
                                              : Icons.call_missed,
                                      size: 16,
                                      color: call.direction == CallDirection.inbound
                                          ? AppColors.accentCyan
                                          : call.direction == CallDirection.outbound
                                              ? AppColors.accentEmerald
                                              : AppColors.accentRose,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      call.direction.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: call.direction == CallDirection.inbound
                                            ? AppColors.accentCyan
                                            : call.direction == CallDirection.outbound
                                                ? AppColors.accentEmerald
                                                : AppColors.accentRose,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${call.simSlot}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textDim),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentEmerald.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check, size: 10, color: AppColors.accentEmerald),
                                      const SizedBox(width: 4),
                                      Text(
                                        call.crmType,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentEmerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Contact Name & Company
                            Text(
                              call.contactName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${call.company} • ${call.phoneNumber}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                            ),

                            const SizedBox(height: 6),

                            // Notes
                            Text(
                              '"${call.outcome}" — ${call.notes}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Bottom Player Strip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => viewModel.togglePlayAudio(call.id),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(call.durationSeconds),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.lock, size: 12, color: AppColors.accentEmerald),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'AES-256 E2EE',
                                    style: TextStyle(fontSize: 9, color: AppColors.accentEmerald),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.bgSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
