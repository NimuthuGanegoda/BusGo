import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyles {
  AppStyles._();

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: 1.5,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 10,
    color: AppColors.textMuted,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
  );

  static const TextStyle link = TextStyle(
    fontSize: 12,
    color: AppColors.secondary,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 11,
    color: AppColors.danger,
  );

  // Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.07),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration inputDecoration = BoxDecoration(
    color: AppColors.inputBg,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border, width: 1.5),
  );

  static BoxDecoration inputErrorDecoration = BoxDecoration(
    color: const Color(0xFFFFF5F5),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.danger, width: 1.5),
  );
}
