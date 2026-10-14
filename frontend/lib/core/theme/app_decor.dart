import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Standard visual decoration and component helpers following fidelity_theme/DESIGN.md
class AppDecor {
  // ─── Screen Background ──────────────────────────────────────────
  /// Primary screen vertical gradient background (#E9EEF4 to #D8DFE9)
  static const BoxDecoration pageBackground = BoxDecoration(
    gradient: AppColors.pageGradient,
  );

  // ─── Elevated Containers & Cards ────────────────────────────────
  /// Level 1 Card: #FCFDFF surface, 1px border #E9EAEC, 28px radius, cool slate shadow
  static BoxDecoration card({
    double radius = 28,
    Border? border,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.cardBorder, width: 1.0),
        boxShadow: AppColors.coolShadow,
      );

  /// Inner Panel: #F4F3F8 surface, 16-20px rounded corners
  static BoxDecoration innerPanel({
    double radius = 18,
    Border? border,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? AppColors.innerPanel,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      );

  /// Level 2 Hero Card: #364050 to #1B212F vertical gradient, 32px radius, hero shadow
  static BoxDecoration hero({
    double radius = 32,
    Border? border,
  }) =>
      BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
        boxShadow: AppColors.heroShadow,
      );

  /// Level 3 Floating Nav Bar: #FCFDFF, 32px radius, floating nav shadow
  static BoxDecoration floatingNav({
    double radius = 32,
    Border? border,
  }) =>
      BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.cardBorder, width: 1.0),
        boxShadow: AppColors.floatingNavShadow,
      );

  // ─── Buttons & Focus States ──────────────────────────────────────
  /// Primary Amber Button Decoration: 135 deg amber gradient, full pill, amber glow
  static BoxDecoration amberButton({double radius = 100}) => BoxDecoration(
        gradient: AppColors.amberGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppColors.amberGlow,
      );

  /// Backwards-compatible alias for amberButton
  static BoxDecoration orangeButton({double radius = 100}) => amberButton(radius: radius);

  /// Focus / Selected item border (1.5px amber outline)
  static Border selectedBorder = Border.all(
    color: AppColors.amber,
    width: 1.5,
  );

  /// Round Dark Icon Button: #2E3744 circle with white icon
  static Widget darkIconTile({
    required IconData icon,
    double size = 44,
    double iconSize = 20,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.badgeSlate,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: tile,
      );
    }
    return tile;
  }

  /// Round Dark Icon with Amber Ring: #2E3744 circle, thin #FBA73B ring (as on Hero upload card)
  static Widget amberRingIconTile({
    required IconData icon,
    double size = 52,
    double iconSize = 24,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.badgeSlate,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.amberHighlight, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: tile,
      );
    }
    return tile;
  }

  /// Step Number Badge (for workflow cards): #2E3744 circle with white number
  static Widget stepBadge({
    required int step,
    double size = 26,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.badgeSlate,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Primary CTA Button: 56px pill, amber gradient, #1E252D dark ink text & icon, amber glow
  static Widget primaryPillButton({
    String? label,
    String? text,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData icon = Icons.arrow_forward_rounded,
    bool isLoading = false,
    double height = 56,
  }) {
    final effectiveLabel = label ?? text ?? '';
    final effectiveOnTap = onTap ?? onPressed;
    return InkWell(
      onTap: isLoading ? null : effectiveOnTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: amberButton(radius: 100),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAmberInk),
                ),
              )
            else ...[
              Text(
                effectiveLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onAmberInk,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                size: 20,
                color: AppColors.onAmberInk,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Secondary Button: 56px pill, #1B212F fill, white text (used for downloads & confirmations)
  static Widget secondaryPillButton({
    String? label,
    String? text,
    VoidCallback? onTap,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double height = 56,
  }) {
    final effectiveLabel = label ?? text ?? '';
    final effectiveOnTap = onTap ?? onPressed;
    return InkWell(
      onTap: isLoading ? null : effectiveOnTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.structuralSlate,
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[
              Text(
                effectiveLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 20,
                  color: Colors.white,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Format Chip (for dark hero card: JPG, PNG, PDF, MAX 25MB)
  static Widget formatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
