import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? unit;

  const StatCard({super.key, required this.label, required this.value,
      required this.icon, this.color, this.unit});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm)),
          child: Icon(icon, size: 16, color: c)),
        const SizedBox(height: AppDimens.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: GoogleFonts.inter(fontSize: 20,
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (unit != null) ...[const SizedBox(width: 2),
            Text(unit!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))],
        ]),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}








