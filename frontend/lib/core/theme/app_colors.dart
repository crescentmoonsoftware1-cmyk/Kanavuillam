import 'package:flutter/material.dart';

/// Design tokens for Kanavu Illam based on fidelity_theme/DESIGN.md
/// Visual direction: Calm Minimalism with Atmospheric Layering.
class AppColors {
  // ─── Base Canvas & Environmental Surfaces ─────────────────────────
  /// Canvas top gradient #E9EEF4
  static const Color bgGradientTop = Color(0xFFE9EEF4);
  /// Canvas bottom gradient #D8DFE9
  static const Color bgGradientBottom = Color(0xFFD8DFE9);
  /// Flat surface/background token wherever a gradient is not used: #F4F7FB
  static const Color pageGround = Color(0xFFF4F7FB);
  /// Card & Sheet Surfaces (elevated containers): #FCFDFF
  static const Color card = Color(0xFFFCFDFF);
  /// Card & container border: #E9EAEC
  static const Color cardBorder = Color(0xFFE9EAEC);
  /// Inner panel surface / surface-container-low: #F4F3F8
  static const Color innerPanel = Color(0xFFF4F3F8);
  /// Surface dim token: #DAD9DF
  static const Color surfaceDim = Color(0xFFDAD9DF);
  /// Surface bright token: #FAF8FE
  static const Color surfaceBright = Color(0xFFFAF8FE);

  // ─── Inks & Structural Tones ──────────────────────────────────────
  /// Deep Ink: #18191D (titles, app name, most important text)
  static const Color deepInk = Color(0xFF18191D);
  /// Structural Slate: #1B212F (hero end, dark sheets, inverse surfaces)
  static const Color structuralSlate = Color(0xFF1B212F);
  /// Steel Binder: #364050 (hero start, secondary neutral, ghost borders)
  static const Color steelBinder = Color(0xFF364050);
  /// Badge Slate: #2E3744 (step-number badges, dark icon circle)
  static const Color badgeSlate = Color(0xFF2E3744);
  /// Quiet Grey: #8E94A0 (subtitles, inactive nav icons/labels, secondary text)
  static const Color quietGrey = Color(0xFF8E94A0);
  /// Reading Slate: #64748B (helper text, descriptions, form hints)
  static const Color readingSlate = Color(0xFF64748B);

  // ─── Functional Accents (Logo Amber) ──────────────────────────────
  /// Amber: #E58A18 (primary action, active page dot, focus borders, checkmarks)
  static const Color amber = Color(0xFFE58A18);
  /// Amber Highlight: #FBA73B (gradient start, upload ring, active highlights)
  static const Color amberHighlight = Color(0xFFFBA73B);
  /// Amber Deep: #B46205 (text on light backgrounds, pressed states)
  static const Color amberDeep = Color(0xFFB46205);
  /// Amber Tint: #FDEBCB (soft fills, selected rows, info chips)
  static const Color amberTint = Color(0xFFFDEBCB);
  /// On-Amber Ink: #1E252D (all text & icons placed on amber; 5.9:1 contrast)
  static const Color onAmberInk = Color(0xFF1E252D);

  // ─── Dark Hero Card Gradient ──────────────────────────────────────
  static const Color heroTop = steelBinder; // #364050
  static const Color heroBottom = structuralSlate; // #1B212F

  // ─── Status Colors ────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ─── Backward-Compatibility Aliases (Preserves Existing Callers) ───
  static const Color primary = amber; // #E58A18
  static const Color secondary = steelBinder; // #364050
  static const Color background = bgGradientTop; // #E9EEF4
  static const Color surface = card; // #FCFDFF
  static const Color border = cardBorder; // #E9EAEC
  static const Color borderLight = cardBorder; // #E9EAEC
  static const Color textPrimary = deepInk; // #18191D
  static const Color textSecondary = quietGrey; // #8E94A0
  static const Color textTertiary = readingSlate; // #64748B
  static const Color textDark = structuralSlate; // #1B212F
  static const Color textTitle = deepInk; // #18191D
  static const Color textBody = readingSlate; // #64748B
  static const Color textMuted = quietGrey; // #8E94A0
  static const Color surfaceSecondary = innerPanel; // #F4F3F8
  static const Color surfaceTertiary = innerPanel; // #F4F3F8
  static const Color darkIconBtn = badgeSlate; // #2E3744

  // Ergonomic token aliases matching Stitch prototype annotations
  static const Color inkPrimary = deepInk; // #18191D
  static const Color inkDark = structuralSlate; // #1B212F
  static const Color inkMuted = steelBinder; // #364050
  static const Color inkQuiet = quietGrey; // #8E94A0
  static const Color inkReading = readingSlate; // #64748B

  static const Color amberDefault = amber; // #E58A18
  static const Color amberHover = amberHighlight; // #FBA73B
  static const Color amberDark = amberDeep; // #B46205
  static const Color onAmber = onAmberInk; // #1E252D

  static const Color canvasGradientTop = bgGradientTop; // #E9EEF4
  static const Color canvasGradientBottom = bgGradientBottom; // #D8DFE9

  // Aliases for retired orange tokens -> redirect to official Amber
  static const Color orangeGradientStart = amberHighlight; // #FBA73B
  static const Color orangeGradientEnd = amber; // #E58A18
  static const Color orangeHighlight = amberHighlight; // #FBA73B
  static const Color orangeText = amberDeep; // #B46205

  // ─── Gradients ───────────────────────────────────────────────────
  /// Screen background vertical gradient #E9EEF4 to #D8DFE9
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradientTop, bgGradientBottom],
  );
  static const LinearGradient canvasGradient = pageGradient;

  /// Hero card vertical gradient #364050 to #1B212F
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [heroTop, heroBottom],
  );

  /// Primary button & active accent gradient (135 deg: #FBA73B to #E58A18)
  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amberHighlight, amber],
  );

  /// Backwards-compatible alias for orangeGradient
  static const LinearGradient orangeGradient = amberGradient;

  // ─── Elevation & Depth Shadows ────────────────────────────────────
  /// Level 1 Card Shadow: 0 12px 32px rgba(27, 33, 47, 0.10)
  static const List<BoxShadow> coolShadow = [
    BoxShadow(
      color: Color(0x1A1B212F),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Level 2 Hero Shadow: 0 16px 40px rgba(27, 33, 47, 0.22)
  static const List<BoxShadow> heroShadow = [
    BoxShadow(
      color: Color(0x381B212F),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];

  /// Level 3 Floating Nav Shadow: 0 12px 32px rgba(27, 33, 47, 0.12)
  static const List<BoxShadow> floatingNavShadow = [
    BoxShadow(
      color: Color(0x1F1B212F),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Primary Button Amber Glow: 0 8px 24px rgba(229, 138, 24, 0.35)
  static const List<BoxShadow> amberGlow = [
    BoxShadow(
      color: Color(0x59E58A18),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Backwards-compatible alias for orangeGlow
  static const List<BoxShadow> orangeGlow = amberGlow;
}
