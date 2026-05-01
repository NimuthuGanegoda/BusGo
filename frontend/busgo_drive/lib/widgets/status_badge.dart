import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.active()    => const StatusBadge(label: 'Active',    color: AppColors.success);
  factory StatusBadge.onRoute()   => const StatusBadge(label: 'On Route',  color: AppColors.tripActive);
  factory StatusBadge.atStop()    => const StatusBadge(label: 'At Stop',   color: AppColors.warning);
  factory StatusBadge.idle()      => const StatusBadge(label: 'Idle',      color: AppColors.textMuted);
  factory StatusBadge.emergency() => const StatusBadge(label: 'Emergency', color: AppColors.sosRed);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}







