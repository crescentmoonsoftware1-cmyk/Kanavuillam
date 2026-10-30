import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Progressive Pen-Draw Isometric Vector House Animation
/// Based on stitch_kanavu_illam_home_screeneditrd/code.html
/// 10s looping animation:
/// Stage 1: Plot diamond (0 - 0.8s) -> 0% to 8%
/// Stage 2: Driveway & stepping stones (0.8s - 2s) -> 8% to 20%
/// Stage 3: Ground floor (2s - 4s) -> 20% to 40%
/// Stage 4: Upper floor (4s - 5.5s) -> 40% to 55%
/// Stage 5: Roof, parapet, canopy, terrace, pergola (5.5s - 6.5s) -> 55% to 65%
/// Stage 6: Foliage, tree, shrubs, planters (6.5s - 7.5s) -> 65% to 75%
/// Hold full state until 94%, then fade out 94% -> 100%.
class IsometricHouseWidget extends StatefulWidget {
  final double width;
  final double height;
  final bool isDark;

  const IsometricHouseWidget({
    super.key,
    this.width = 280,
    this.height = 150,
    this.isDark = false,
  });

  @override
  State<IsometricHouseWidget> createState() => _IsometricHouseWidgetState();
}

class _IsometricHouseWidgetState extends State<IsometricHouseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _IsometricHousePainter(
              progress: _controller.value,
              isDark: widget.isDark,
            ),
          );
        },
      ),
    );
  }
}

class _IsometricHousePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isDark;

  _IsometricHousePainter({
    required this.progress,
    required this.isDark,
  });

  // Target original viewBox: 400 wide x 360 high
  static const double srcW = 400.0;
  static const double srcH = 360.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Overall loop fade out near the end (0.94 -> 1.0)
    double globalOpacity = 1.0;
    if (progress > 0.94) {
      globalOpacity = ((1.0 - progress) / 0.06).clamp(0.0, 1.0);
    }

    if (globalOpacity <= 0.0) return;

    // Uniform scaling to fit size
    final double scale = math.min(size.width / srcW, size.height / srcH);
    final double dx = (size.width - (srcW * scale)) / 2.0;
    final double dy = (size.height - (srcH * scale)) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    // Helpers to scale opacity with globalOpacity
    Color c(Color color, [double alphaMul = 1.0]) {
      return color.withValues(alpha: color.a * globalOpacity * alphaMul);
    }

    // Line & stroke standard
    final outlineColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final strokePaint = Paint()
      ..color = c(outlineColor)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 1: Plot diamond (0.0 to 0.08)
    // ─────────────────────────────────────────────────────────────────────────
    final plotOpacity = _stageOpacity(progress, 0.0, 0.08);
    if (plotOpacity > 0.0) {
      final plotPath = Path()
        ..moveTo(200, 120)
        ..lineTo(375, 221)
        ..lineTo(200, 322)
        ..lineTo(25, 221)
        ..close();

      fillPaint.color = c(isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0), plotOpacity);
      canvas.drawPath(plotPath, fillPaint);

      // Dashed boundary
      _drawDashedPath(
        canvas,
        plotPath,
        Paint()
          ..color = c(isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8), plotOpacity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        dashLength: 6.0,
        gapLength: 5.0,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 2: Driveway & Stepping Stones (0.08 to 0.20)
    // ─────────────────────────────────────────────────────────────────────────
    final drivewayProgress = _stageProgress(progress, 0.08, 0.20);
    if (drivewayProgress > 0.0) {
      final drivewayPath = Path()
        ..moveTo(145, 252)
        ..lineTo(80, 289)
        ..lineTo(118, 311)
        ..lineTo(183, 274)
        ..close();

      fillPaint.color = c(const Color(0xFF64748B), drivewayProgress);
      canvas.drawPath(drivewayPath, fillPaint);
      canvas.drawPath(drivewayPath, strokePaint..color = c(const Color(0xFF64748B), drivewayProgress));

      // Stepping stones
      final stoneColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9);
      final stones = [
        [const Offset(172, 258), const Offset(184, 251), const Offset(192, 255), const Offset(180, 262)],
        [const Offset(186, 266), const Offset(198, 259), const Offset(206, 263), const Offset(194, 270)],
        [const Offset(200, 274), const Offset(212, 267), const Offset(220, 271), const Offset(208, 278)],
      ];

      for (final stone in stones) {
        final p = Path()..addPolygon(stone, true);
        fillPaint.color = c(stoneColor, drivewayProgress);
        canvas.drawPath(p, fillPaint);
        canvas.drawPath(p, strokePaint..color = c(const Color(0xFF64748B), drivewayProgress));
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 3: Ground Floor (0.20 to 0.40)
    // ─────────────────────────────────────────────────────────────────────────
    final groundProgress = _stageProgress(progress, 0.20, 0.40);
    if (groundProgress > 0.0) {
      // Right face (Warm off-white #EFE3DA)
      final rightFace = Path()
        ..moveTo(200, 284)
        ..lineTo(315, 217)
        ..lineTo(315, 152)
        ..lineTo(200, 218)
        ..close();
      fillPaint.color = c(const Color(0xFFEFE3DA), groundProgress);
      canvas.drawPath(rightFace, fillPaint);
      canvas.drawPath(rightFace, strokePaint..color = c(outlineColor, groundProgress));

      // Left face (Pure White #FFFFFF)
      final leftFace = Path()
        ..moveTo(200, 284)
        ..lineTo(100, 226)
        ..lineTo(100, 161)
        ..lineTo(200, 218)
        ..close();
      fillPaint.color = c(const Color(0xFFFFFFFF), groundProgress);
      canvas.drawPath(leftFace, fillPaint);
      canvas.drawPath(leftFace, strokePaint..color = c(outlineColor, groundProgress));

      // Garage Door #334155
      final garage = Path()
        ..moveTo(106, 220)
        ..lineTo(162, 252)
        ..lineTo(162, 207)
        ..lineTo(106, 175)
        ..close();
      fillPaint.color = c(const Color(0xFF334155), groundProgress);
      canvas.drawPath(garage, fillPaint);
      canvas.drawPath(garage, strokePaint..color = c(outlineColor, groundProgress));

      // Garage lines
      final linePaint = Paint()
        ..color = c(const Color(0xFFCBD5E1), groundProgress)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(106, 187), const Offset(162, 219), linePaint);
      canvas.drawLine(const Offset(106, 198), const Offset(162, 230), linePaint);
      canvas.drawLine(const Offset(106, 209), const Offset(162, 241), linePaint);

      // Narrow door beside garage
      final door = Path()
        ..moveTo(168, 255)
        ..lineTo(186, 266)
        ..lineTo(186, 222)
        ..lineTo(168, 211)
        ..close();
      fillPaint.color = c(const Color(0xFF334155), groundProgress);
      canvas.drawPath(door, fillPaint);
      canvas.drawPath(door, strokePaint..color = c(outlineColor, groundProgress));

      // Vertical Wood-slat Fin next to door #E3A83B
      final finPaint = Paint()
        ..color = c(const Color(0xFFE3A83B), groundProgress)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(189, 267), const Offset(189, 223), finPaint);

      // Wood deck #D9B26B
      final deck = Path()
        ..moveTo(214, 276)
        ..lineTo(270, 243)
        ..lineTo(282, 250)
        ..lineTo(226, 283)
        ..close();
      fillPaint.color = c(const Color(0xFFD9B26B), groundProgress);
      canvas.drawPath(deck, fillPaint);
      canvas.drawPath(deck, strokePaint..color = c(outlineColor, groundProgress));

      // Glass entrance #CBD5E1
      final glass = Path()
        ..moveTo(216, 268)
        ..lineTo(268, 238)
        ..lineTo(268, 198)
        ..lineTo(216, 228)
        ..close();
      fillPaint.color = c(const Color(0xFFCBD5E1), groundProgress);
      canvas.drawPath(glass, fillPaint);
      canvas.drawPath(glass, strokePaint..color = c(outlineColor, groundProgress));

      // Mullions
      final mulDark = Paint()..color = c(const Color(0xFF334155), groundProgress)..strokeWidth = 1.4;
      final mulLight = Paint()..color = c(const Color(0xFFCBD5E1), groundProgress)..strokeWidth = 1.4;
      canvas.drawLine(const Offset(229, 260), const Offset(229, 220), mulDark);
      canvas.drawLine(const Offset(242, 253), const Offset(242, 213), mulLight);
      canvas.drawLine(const Offset(255, 245), const Offset(255, 205), mulDark);

      // Small corner strip window #334155
      final win = Path()
        ..moveTo(203, 243)
        ..lineTo(211, 238)
        ..lineTo(211, 231)
        ..lineTo(203, 236)
        ..close();
      fillPaint.color = c(const Color(0xFF334155), groundProgress);
      canvas.drawPath(win, fillPaint);
      canvas.drawPath(win, strokePaint..color = c(outlineColor, groundProgress));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 4: Upper Floor (0.40 to 0.55)
    // ─────────────────────────────────────────────────────────────────────────
    final upperProgress = _stageProgress(progress, 0.40, 0.55);
    if (upperProgress > 0.0) {
      canvas.save();
      // Slight vertical rise animation as it lands
      final ty = (1.0 - upperProgress) * 6.0;
      canvas.translate(0, ty);

      // Upper Right Face #EFE3DA
      final upperRight = Path()
        ..moveTo(196, 214)
        ..lineTo(308, 149)
        ..lineTo(308, 86)
        ..lineTo(196, 151)
        ..close();
      fillPaint.color = c(const Color(0xFFEFE3DA), upperProgress);
      canvas.drawPath(upperRight, fillPaint);
      canvas.drawPath(upperRight, strokePaint..color = c(outlineColor, upperProgress));

      // Upper Left Face #FFFFFF
      final upperLeft = Path()
        ..moveTo(196, 214)
        ..lineTo(96, 156)
        ..lineTo(96, 93)
        ..lineTo(196, 151)
        ..close();
      fillPaint.color = c(const Color(0xFFFFFFFF), upperProgress);
      canvas.drawPath(upperLeft, fillPaint);
      canvas.drawPath(upperLeft, strokePaint..color = c(outlineColor, upperProgress));

      // Wood-slat band at base #E3A83B
      final woodBand = Path()
        ..moveTo(104, 150)
        ..lineTo(188, 199)
        ..lineTo(188, 193)
        ..lineTo(104, 144)
        ..close();
      fillPaint.color = c(const Color(0xFFE3A83B), upperProgress);
      canvas.drawPath(woodBand, fillPaint);
      canvas.drawPath(woodBand, strokePaint..color = c(outlineColor, upperProgress));

      // Glass band with mullions
      final glassBand = Path()
        ..moveTo(104, 144)
        ..lineTo(188, 193)
        ..lineTo(188, 162)
        ..lineTo(104, 113)
        ..close();
      fillPaint.color = c(const Color(0xFFCBD5E1), upperProgress);
      canvas.drawPath(glassBand, fillPaint);
      canvas.drawPath(glassBand, strokePaint..color = c(outlineColor, upperProgress));

      final upperMul = Paint()..color = c(const Color(0xFF334155), upperProgress)..strokeWidth = 1.4;
      canvas.drawLine(const Offset(125, 156), const Offset(125, 125), upperMul);
      canvas.drawLine(const Offset(146, 168), const Offset(146, 137), upperMul);
      canvas.drawLine(const Offset(167, 181), const Offset(167, 150), upperMul);

      // Upper Right Face: Horizontal window
      final winRight = Path()
        ..moveTo(204, 175)
        ..lineTo(224, 163)
        ..lineTo(224, 147)
        ..lineTo(204, 159)
        ..close();
      fillPaint.color = c(const Color(0xFF334155), upperProgress);
      canvas.drawPath(winRight, fillPaint);
      canvas.drawPath(winRight, strokePaint..color = c(outlineColor, upperProgress));

      // Wood panel with horizontal slats
      final woodPanel = Path()
        ..moveTo(230, 160)
        ..lineTo(280, 131)
        ..lineTo(280, 105)
        ..lineTo(230, 134)
        ..close();
      fillPaint.color = c(const Color(0xFFE3A83B), upperProgress);
      canvas.drawPath(woodPanel, fillPaint);
      canvas.drawPath(woodPanel, strokePaint..color = c(outlineColor, upperProgress));

      final slatPaint = Paint()..color = c(const Color(0xFFB87314), upperProgress)..strokeWidth = 1.0;
      canvas.drawLine(const Offset(230, 140), const Offset(280, 111), slatPaint);
      canvas.drawLine(const Offset(230, 146), const Offset(280, 117), slatPaint);
      canvas.drawLine(const Offset(230, 152), const Offset(280, 123), slatPaint);

      // Far narrow window
      final farWin = Path()
        ..moveTo(288, 126)
        ..lineTo(298, 120)
        ..lineTo(298, 96)
        ..lineTo(288, 102)
        ..close();
      fillPaint.color = c(const Color(0xFF334155), upperProgress);
      canvas.drawPath(farWin, fillPaint);
      canvas.drawPath(farWin, strokePaint..color = c(outlineColor, upperProgress));

      canvas.restore();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 5: Roof, Parapet, Canopy, Terrace & Pergola (0.55 to 0.65)
    // ─────────────────────────────────────────────────────────────────────────
    final roofProgress = _stageProgress(progress, 0.55, 0.65);
    if (roofProgress > 0.0) {
      // Entrance Canopy
      final canopySide = Path()
        ..moveTo(206, 218)
        ..lineTo(244, 196)
        ..lineTo(250, 199)
        ..lineTo(212, 221)
        ..close();
      fillPaint.color = c(const Color(0xFFE3A83B), roofProgress);
      canvas.drawPath(canopySide, fillPaint);
      canvas.drawPath(canopySide, strokePaint..color = c(outlineColor, roofProgress));

      final canopyTop = Path()
        ..moveTo(212, 221)
        ..lineTo(250, 199)
        ..lineTo(245, 196)
        ..lineTo(207, 218)
        ..close();
      fillPaint.color = c(const Color(0xFF475569), roofProgress);
      canvas.drawPath(canopyTop, fillPaint);
      canvas.drawPath(canopyTop, strokePaint..color = c(outlineColor, roofProgress));

      // Small Terrace on Lower Roof
      final terrace = Path()
        ..moveTo(268, 198)
        ..lineTo(315, 171)
        ..lineTo(306, 166)
        ..lineTo(259, 193)
        ..close();
      fillPaint.color = c(const Color(0xFFD9B26B), roofProgress);
      canvas.drawPath(terrace, fillPaint);
      canvas.drawPath(terrace, strokePaint..color = c(outlineColor, roofProgress));

      // Parapet around terrace
      final terraceParapet = Path()
        ..moveTo(268, 198)
        ..lineTo(315, 171)
        ..lineTo(315, 166)
        ..lineTo(268, 193)
        ..close();
      fillPaint.color = c(const Color(0xFFFFFFFF), roofProgress);
      canvas.drawPath(terraceParapet, fillPaint);
      canvas.drawPath(terraceParapet, strokePaint..color = c(outlineColor, roofProgress));

      // Wood pergola
      final pergolaPaint = Paint()
        ..color = c(const Color(0xFFE3A83B), roofProgress)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(284, 189), const Offset(284, 175), pergolaPaint);
      canvas.drawLine(const Offset(304, 177), const Offset(304, 163), pergolaPaint);
      canvas.drawLine(const Offset(280, 177), const Offset(308, 161), pergolaPaint..strokeWidth = 1.8);
      canvas.drawLine(const Offset(286, 175), const Offset(300, 167), pergolaPaint..strokeWidth = 1.2);

      // Main Flat Roof: Parapet outer rim #FFFFFF
      final mainParapet = Path()
        ..moveTo(196, 152)
        ..lineTo(312, 85)
        ..lineTo(212, 27)
        ..lineTo(96, 92)
        ..close();
      fillPaint.color = c(const Color(0xFFFFFFFF), roofProgress);
      canvas.drawPath(mainParapet, fillPaint);
      canvas.drawPath(mainParapet, strokePaint..color = c(outlineColor, roofProgress));

      // Inner Slate Roof #475569
      final innerRoof = Path()
        ..moveTo(196, 149)
        ..lineTo(306, 86)
        ..lineTo(212, 32)
        ..lineTo(102, 93)
        ..close();
      fillPaint.color = c(const Color(0xFF475569), roofProgress);
      canvas.drawPath(innerRoof, fillPaint);
      canvas.drawPath(innerRoof, strokePaint..color = c(outlineColor, roofProgress));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STAGE 6: Landscaping (Tree, Shrubs, Planters) (0.65 to 0.75)
    // ─────────────────────────────────────────────────────────────────────────
    final foliageProgress = _stageProgress(progress, 0.65, 0.75);
    if (foliageProgress > 0.0) {
      // Elastic pop scale
      final double popScale = (foliageProgress < 0.6)
          ? (foliageProgress / 0.6 * 1.08)
          : (1.08 - (foliageProgress - 0.6) / 0.4 * 0.08);

      // Left of garage: White planter box
      final p1 = Path()..moveTo(62, 228)..lineTo(78, 219)..lineTo(86, 224)..lineTo(70, 233)..close();
      final p2 = Path()..moveTo(62, 228)..lineTo(70, 233)..lineTo(70, 241)..lineTo(62, 236)..close();
      final p3 = Path()..moveTo(70, 233)..lineTo(86, 224)..lineTo(86, 232)..lineTo(70, 241)..close();

      fillPaint.color = c(const Color(0xFFFFFFFF), foliageProgress);
      canvas.drawPath(p1, fillPaint);
      canvas.drawPath(p1, strokePaint..color = c(outlineColor, foliageProgress));
      canvas.drawPath(p2, fillPaint);
      canvas.drawPath(p2, strokePaint..color = c(outlineColor, foliageProgress));

      fillPaint.color = c(const Color(0xFFEFE3DA), foliageProgress);
      canvas.drawPath(p3, fillPaint);
      canvas.drawPath(p3, strokePaint..color = c(outlineColor, foliageProgress));

      // Tree trunk #4B3B2B
      final trunkPaint = Paint()
        ..color = c(const Color(0xFF4B3B2B), foliageProgress)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(74, 228), const Offset(74, 204), trunkPaint);

      // Rounded Foliage #3F6B45 with pop scale
      canvas.save();
      canvas.translate(74, 195);
      canvas.scale(popScale, popScale);
      fillPaint.color = c(const Color(0xFF3F6B45), foliageProgress);
      canvas.drawCircle(Offset.zero, 14.0, fillPaint);
      canvas.drawCircle(Offset.zero, 14.0, strokePaint..color = c(outlineColor, foliageProgress));

      fillPaint.color = c(const Color(0xFF528359), foliageProgress * 0.4);
      canvas.drawCircle(const Offset(-3, -4), 5.0, fillPaint);
      canvas.restore();

      // Right edge: Long low white planter box
      final rp1 = Path()..moveTo(325, 214)..lineTo(365, 191)..lineTo(369, 193)..lineTo(329, 216)..close();
      final rp2 = Path()..moveTo(325, 214)..lineTo(329, 216)..lineTo(329, 222)..lineTo(325, 220)..close();
      final rp3 = Path()..moveTo(329, 216)..lineTo(369, 193)..lineTo(369, 199)..lineTo(329, 222)..close();

      fillPaint.color = c(const Color(0xFFFFFFFF), foliageProgress);
      canvas.drawPath(rp1, fillPaint);
      canvas.drawPath(rp1, strokePaint..color = c(outlineColor, foliageProgress));
      canvas.drawPath(rp2, fillPaint);
      canvas.drawPath(rp2, strokePaint..color = c(outlineColor, foliageProgress));

      fillPaint.color = c(const Color(0xFFEFE3DA), foliageProgress);
      canvas.drawPath(rp3, fillPaint);
      canvas.drawPath(rp3, strokePaint..color = c(outlineColor, foliageProgress));

      // 3 small round green shrubs
      final shrubs = [const Offset(334, 210), const Offset(347, 202), const Offset(360, 195)];
      for (final sh in shrubs) {
        canvas.save();
        canvas.translate(sh.dx, sh.dy);
        canvas.scale(popScale, popScale);
        fillPaint.color = c(const Color(0xFF3F6B45), foliageProgress);
        canvas.drawCircle(Offset.zero, 5.5, fillPaint);
        canvas.drawCircle(Offset.zero, 5.5, strokePaint..color = c(outlineColor, foliageProgress));
        canvas.restore();
      }
    }

    canvas.restore();
  }

  static double _stageOpacity(double p, double start, double end) {
    if (p < start) return 0.0;
    if (p > 0.94) return 1.0;
    if (p >= end) return 1.0;
    return (p - start) / (end - start);
  }

  static double _stageProgress(double p, double start, double end) {
    if (p < start) return 0.0;
    if (p > 0.94) return 1.0;
    if (p >= end) return 1.0;
    return ((p - start) / (end - start)).clamp(0.0, 1.0);
  }

  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      double start = 0.0;
      while (start < metric.length) {
        final double end = math.min(start + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricHousePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
