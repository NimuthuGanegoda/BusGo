import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool isError;
  final String? errorText;
  final String? initialValue;
  final bool filled;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.isError = false,
    this.errorText,
    this.initialValue,
    this.filled = false,
    this.controller,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF5F5) : AppColors.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isError ? AppColors.danger : AppColors.border,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  initialValue ?? hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: initialValue != null
                        ? const Color(0xFF333333)
                        : const Color(0xFF999999),
                  ),
                ),
              ),
              if (suffixIcon != null) suffixIcon!,
            ],
          ),
        ),
        if (isError && errorText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 12, color: AppColors.danger),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class InputTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const InputTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.controller,
    this.suffixIcon,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFF5F5) : AppColors.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError ? AppColors.danger : AppColors.border,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
              ),
              prefixIcon: Icon(icon, size: 16, color: AppColors.textMuted),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              isDense: true,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 12, color: AppColors.danger),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}
