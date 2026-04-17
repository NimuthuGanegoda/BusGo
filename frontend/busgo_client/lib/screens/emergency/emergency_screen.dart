import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/emergency_provider.dart';
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const _otherTypeIndex = 4; // Index of "Other" in emergencyTypes
  final _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyProvider>().resetForm();
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred background
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dark overlay
          Container(
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          // Modal content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildModalContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalContent() {
    return Consumer<EmergencyProvider>(
      builder: (context, emergency, _) {
        if (emergency.alertSent) {
          return _buildSuccessView(emergency);
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFFFE0E0),
                    ),
                  ),
                ),
                child: const Text(
                  '⚠️ Emergency Alert',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Select the type of emergency you are experiencing:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Emergency type options
              ...List.generate(EmergencyProvider.displayTypes.length,
                  (index) {
                final isSelected = emergency.selectedType == index;
                return GestureDetector(
                  onTap: () {
                    emergency.setSelectedType(index);
                    if (index != _otherTypeIndex) {
                      _detailsController.clear();
                      emergency.setDetails('');
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFF5F5)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.danger : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.danger
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.danger
                                  : const Color(0xFFCCCCCC),
                              width: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          EmergencyProvider.displayTypes[index],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              // Additional details - only enabled for "Other"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emergency.selectedType == _otherTypeIndex
                      ? 'Describe the situation'
                      : 'Additional Details (only for "Other")',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: emergency.selectedType == _otherTypeIndex ? 1.0 : 0.5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: emergency.selectedType == _otherTypeIndex
                        ? AppColors.inputBg
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: emergency.selectedType == _otherTypeIndex
                          ? AppColors.border
                          : const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    enabled: emergency.selectedType == _otherTypeIndex,
                    onChanged: (value) => emergency.setDetails(value),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF333333)),
                    decoration: InputDecoration(
                      hintText: emergency.selectedType == _otherTypeIndex
                          ? 'Describe the situation...'
                          : 'Select "Other" to describe',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Hold instruction
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text('⏳', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'Hold button for 5 seconds to activate',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Send Alert button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: emergency.isLoading
                      ? null
                      : () async {
                          await emergency.sendAlert();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: emergency.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '🚨 Send Alert',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 6),

              // Cancel link
              GestureDetector(
                onTap: () => context.pop(),
                child: const Text(
                  'Cancel',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessView(EmergencyProvider emergency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Alert Sent Successfully',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency type: ${EmergencyProvider.displayTypes[emergency.selectedType]}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (emergency.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Details: ${emergency.details}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Help is on the way. Stay calm.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Close',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
