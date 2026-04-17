import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';
import '../models/route_model.dart';

class RouteCard extends StatelessWidget {
  final BusRoute route;
  final VoidCallback? onTap;
  final bool isSelected;

  const RouteCard({super.key, required this.route, this.onTap, this.isSelected = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: route.color,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm)),
            child: Text(route.routeNumber, style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(route.name, style: GoogleFonts.inter(fontSize: 14,
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(route.routeDirection, style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary)),
          ])),
          if (route.isAssigned) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12)),
            child: Text('Assigned', style: GoogleFonts.inter(fontSize: 10,
                fontWeight: FontWeight.w600, color: AppColors.success)),
          ),
        ]),
        const SizedBox(height: AppDimens.md),
        Row(children: [
          _StatChip(icon: Icons.location_on_outlined, label: '${route.totalStops} stops'),
          const SizedBox(width: AppDimens.lg),
          _StatChip(icon: Icons.straighten, label: route.distanceDisplay),
          const SizedBox(width: AppDimens.lg),
          _StatChip(icon: Icons.schedule, label: route.durationDisplay),
        ]),
      ]),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: AppColors.textSecondary),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
  ]);
}
