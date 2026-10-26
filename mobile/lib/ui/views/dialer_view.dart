import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../view_models/dialer_view_model.dart';
import '../../data/models/lead_contact.dart';

class DialerView extends StatelessWidget {
  const DialerView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DialerViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.call_end_outlined, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'RingVia360 Mobile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // SIM Slot Line Switcher
          GestureDetector(
            onTap: viewModel.toggleSim,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: viewModel.selectedSim.isTracked
                    ? AppColors.accentEmerald.withOpacity(0.15)
                    : AppColors.accentRose.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: viewModel.selectedSim.isTracked
                      ? AppColors.accentEmerald.withOpacity(0.4)
                      : AppColors.accentRose.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sim_card,
                    size: 14,
                    color: viewModel.selectedSim.isTracked
                        ? AppColors.accentEmerald
                        : AppColors.accentRose,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    viewModel.selectedSim.slotId,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: viewModel.selectedSim.isTracked
                          ? AppColors.accentEmerald
                          : AppColors.accentRose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
            // Contact Matching Bar
            if (viewModel.matchingContacts.isNotEmpty)
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewModel.matchingContacts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final contact = viewModel.matchingContacts[index];
                    return ActionChip(
                      backgroundColor: AppColors.bgSurfaceElevated,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          contact.name[0],
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      label: Text(
                        contact.name,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMain),
                      ),
                      onPressed: () => viewModel.selectContact(contact),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Phone Number Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text(
                    viewModel.inputNumber.isEmpty ? 'Enter Phone Number' : viewModel.inputNumber,
                    style: TextStyle(
                      fontSize: viewModel.inputNumber.isEmpty ? 22 : 32,
                      fontWeight: FontWeight.w700,
                      color: viewModel.inputNumber.isEmpty ? AppColors.textDim : AppColors.textMain,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (viewModel.inputNumber.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${viewModel.activeContactName} • ${viewModel.activeCompany}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dialpad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF'], viewModel),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], viewModel),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], viewModel),
                  const SizedBox(height: 12),
                  _buildKeypadRow(['*', '0', '#'], ['', '+', ''], viewModel),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Call Action Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Simulate Inbound Call Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ring_volume, color: AppColors.accentCyan),
                        iconSize: 26,
                        onPressed: () {
                          viewModel.triggerIncomingCallSim();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.bgSurfaceElevated,
                              duration: Duration(seconds: 2),
                              content: Text('📞 Incoming customer call received...'),
                            ),
                          );
                        },
                        tooltip: 'Simulate Inbound Call from Client',
                      ),
                      const Text(
                        'Inbound',
                        style: TextStyle(fontSize: 10, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  // Quick Test Lead Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: AppColors.accentAmber),
                        iconSize: 26,
                        onPressed: () {
                          viewModel.selectContact(
                            const LeadContact(
                              id: 'c-1',
                              name: 'Aarav Sharma',
                              phoneNumber: '+919820143210',
                              company: 'Tata Consultancy Services',
                              title: 'VP Enterprise Sales',
                              openDealValue: 48000,
                              lastContacted: '8m ago',
                              crmAccountId: 'rv360-001',
                            ),
                          );
                        },
                        tooltip: 'Load Quick Lead',
                      ),
                      const Text(
                        'Lead',
                        style: TextStyle(fontSize: 10, color: AppColors.accentAmber, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  // Green Dial Button (Tap = In-App Call Tracking + Native Tel: Launch)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      viewModel.startCall(null, true);
                    },
                    onLongPress: () {
                      viewModel.startCall(null, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.bgSurfaceElevated,
                          content: Text('📱 Opening native phone dialer (tel:)...'),
                        ),
                      );
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accentEmerald, Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentEmerald.withOpacity(0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.phone, color: Colors.white, size: 30),
                    ),
                  ),

                  // Backspace / Delete Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: AppColors.textDim),
                        iconSize: 26,
                        onPressed: viewModel.deleteDigit,
                        onLongPress: viewModel.clearNumber,
                      ),
                      const Text(
                        'Delete',
                        style: TextStyle(fontSize: 10, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tap green to dial via Phone App & Track Call Status',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildKeypadRow(List<String> digits, List<String> subtitles, DialerViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final digit = digits[index];
        final sub = subtitles[index];
        return _KeypadButton(
          digit: digit,
          subtitle: sub,
          onTap: () => vm.appendDigit(digit),
        );
      }),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String digit;
  final String subtitle;
  final VoidCallback onTap;

  const _KeypadButton({
    required this.digit,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textDim,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
