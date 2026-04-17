import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class AppInput extends StatelessWidget {
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextEditingController? controller;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const AppInput({
    super.key, required this.label, required this.hint,
    this.prefixIcon, this.suffixIcon, this.obscureText = false,
    this.controller, this.errorText, this.keyboardType,
    this.onChanged, this.validator, this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType, onChanged: onChanged,
        validator: validator, enabled: enabled,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: AppColors.textMuted) : null,
          suffixIcon: suffixIcon, errorText: errorText,
          errorStyle: GoogleFonts.inter(fontSize: 12),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
}
