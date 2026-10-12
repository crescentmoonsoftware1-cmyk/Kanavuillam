import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Color? fillColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? hintColor;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.fillColor,
    this.borderColor,
    this.textColor,
    this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    AppConfigProvider? config;
    try {
      config = Provider.of<AppConfigProvider>(context);
    } catch (_) {}

    final isDark = config?.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final effectiveBgColor = fillColor ?? (isDark ? const Color(0xFF1D2128) : Colors.white);
    final effectiveBorderColor = borderColor ?? (isDark ? const Color(0xFF2C323D) : AppColors.border);
    final effectiveTextColor = textColor ?? (isDark ? Colors.white : AppColors.primary);
    final effectiveHintColor = hintColor ?? (isDark ? const Color(0xFF9EACB9) : AppColors.textTertiary);

    return Container(
      decoration: BoxDecoration(
        color: effectiveBgColor,
        border: Border.all(color: effectiveBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        obscureText: isPassword && obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: effectiveTextColor,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          prefixIcon: Icon(prefixIcon, color: effectiveHintColor, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: effectiveHintColor,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: effectiveHintColor,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
