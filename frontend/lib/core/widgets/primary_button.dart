import '../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool showArrow;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onTap,
    this.showArrow = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    AppConfigProvider? config;
    try {
      config = Provider.of<AppConfigProvider>(context);
    } catch (_) {}

    final isDark = config?.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final buttonBg = isDark ? Colors.white : AppColors.primary;
    final textColor = isDark ? Colors.black : Colors.white;
    final arrowBg = isDark ? Colors.black : Colors.white;
    final arrowColor = isDark ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.primary).withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (showArrow)
                    Positioned(
                      right: 16,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: arrowBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: arrowColor,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
