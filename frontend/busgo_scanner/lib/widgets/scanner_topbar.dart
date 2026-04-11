import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScannerTopbar extends StatelessWidget {
  final int    scanCount;
  final String mode;

  const ScannerTopbar({
    super.key,
    required this.scanCount,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scannerSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BUSGO Scanner',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$mode Mode',
                  style: const TextStyle(
                    color:    Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Scan count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryLight.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.lightBlue,
                  size:  16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$scanCount scanned',
                  style: const TextStyle(
                    color:      AppColors.lightBlue,
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}