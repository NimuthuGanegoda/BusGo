import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key, required this.text, this.onPressed,
    this.isLoading = false, this.isOutlined = false,
    this.color, this.textColor, this.icon, this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primary;
    final fgColor = textColor ?? (isOutlined ? bgColor : Colors.white);
    return SizedBox(
      width: width ?? double.infinity,
      height: AppDimens.buttonHeight,
      child: isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: fgColor,
              side: BorderSide(color: bgColor, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
            ),
            child: _buildChild(fgColor),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor, foregroundColor: fgColor,
              disabledBackgroundColor: bgColor.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusMd)),
            ),
            child: _buildChild(fgColor),
          ),
    );
  }

  Widget _buildChild(Color fgColor) {
    if (isLoading) return SizedBox(height: 22, width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fgColor));
    if (icon != null) return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 20), const SizedBox(width: 8),
      Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
    ]);
    return Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600));
  }
}








