import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated 2D Blueprint Stack with 3D Glossy Upload Cloud & Floating Sparkles
/// Matches the reference design with smooth floating physics.
class FloorPlanUploadIllustration extends StatefulWidget {
  final double height;
  final bool isDark;

  const FloorPlanUploadIllustration({
    super.key,
    this.height = 125,
    this.isDark = false,
  });

  @override
  State<FloorPlanUploadIllustration> createState() =>
      _FloorPlanUploadIllustrationState();
}

class _FloorPlanUploadIllustrationState
    extends State<FloorPlanUploadIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final floatY = math.sin(t * 2 * math.pi) * 6.5;
        final sheetTilt = math.sin((t * 2 * math.pi) + 0.5) * 0.015;
        final sparkleScale = 0.85 + (math.sin(t * 2 * math.pi) * 0.18);
        final sparkleAngle = t * 2 * math.pi;

        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 250,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // ── Background Accent Elements (Dashed Arcs, Rings, Sparkles) ──
                    CustomPaint(
                      size: const Size(250, 180),
                      painter: _BackgroundAccentsPainter(
                        progress: t,
                        isDark: widget.isDark,
                      ),
                    ),

              // ── Layer 1: Bottom Kraft Folder (Angled Right) ──
              Positioned(
                top: 24,
                child: Transform.rotate(
                  angle: 0.16 + (sheetTilt * 0.5),
                  child: Container(
                    width: 145,
                    height: 125,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6C878),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2A747).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(3, 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Layer 2: Mid Kraft Folder (Angled Left) ──
              Positioned(
                top: 18,
                child: Transform.rotate(
                  angle: -0.14 - (sheetTilt * 0.4),
                  child: Container(
                    width: 140,
                    height: 122,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFADAA0),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: const Color(0xFFEBB558).withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(-2, 6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Layer 3: Main White Blueprint Paper Sheet ──
              Positioned(
                top: 12,
                child: Transform.rotate(
                  angle: -0.06 + sheetTilt,
                  child: Container(
                    width: 142,
                    height: 132,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: const Color(0xFFE58A18).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Architectural 2D Floor Plan Image
                          Image.asset(
                            'assets/images/blueprint_placeholder.png',
                            fit: BoxFit.cover,
                          ),
                          // Subtle paper tint gradient
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Layer 4: Floating 3D Glossy Amber Cloud with Arrow ──
              Positioned(
                right: 56,
                bottom: 16 + floatY,
                child: _Glossy3DUploadCloud(
                  floatProgress: t,
                ),
              ),

              // ── Layer 5: Dynamic Sparkle Star (Twinkling) ──
              Positioned(
                left: 60,
                top: 36,
                child: Transform.rotate(
                  angle: sparkleAngle * 0.4,
                  child: Transform.scale(
                    scale: sparkleScale,
                    child: CustomPaint(
                      size: const Size(18, 18),
                      painter: _SparkleStarPainter(
                        color: const Color(0xFFE58A18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
},
);
}
}

/// 3D Glossy Amber Upload Cloud with Upward Arrow & Ambient Shadow
class _Glossy3DUploadCloud extends StatelessWidget {
  final double floatProgress;

  const _Glossy3DUploadCloud({required this.floatProgress});

  @override
  Widget build(BuildContext context) {
    // Arrow vertical glide inside cloud
    final arrowOffset = math.sin(floatProgress * 2 * math.pi) * 1.8;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Realistic Soft Cloud Ambient Drop Shadow
        Container(
          width: 90,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB45309).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFFE58A18).withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),

        // Custom 3D Shaded Cloud Body
        CustomPaint(
          size: const Size(96, 68),
          painter: _Cloud3DPainter(),
          child: SizedBox(
            width: 96,
            height: 68,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, -2 - arrowOffset),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 27,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0x6678350F),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a multi-layered 3D glossy cloud shape with top highlight and base depth
class _Cloud3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cloud Silhouette Path
    final cloudPath = Path();
    // Base pill shape
    cloudPath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, h * 0.42, w - 20, h * 0.50),
        Radius.circular(h * 0.25),
      ),
    );
    // Left puff
    cloudPath.addOval(
      Rect.fromCircle(
        center: Offset(w * 0.30, h * 0.48),
        radius: h * 0.30,
      ),
    );
    // Center-top large puff
    cloudPath.addOval(
      Rect.fromCircle(
        center: Offset(w * 0.52, h * 0.36),
        radius: h * 0.35,
      ),
    );
    // Right puff
    cloudPath.addOval(
      Rect.fromCircle(
        center: Offset(w * 0.74, h * 0.52),
        radius: h * 0.25,
      ),
    );

    // 1. Base 3D Shaded Cloud Fill (Warm Golden Orange Gradient)
    final mainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFDC044), // Sunny bright gold highlight
          Color(0xFFF39200), // Pure rich amber
          Color(0xFFD66900), // Deep warm amber depth
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(cloudPath, mainPaint);

    // 2. Outer Rim Light Highlight Stroke
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.90),
          Colors.white.withValues(alpha: 0.20),
          const Color(0xFFB45309).withValues(alpha: 0.40),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(cloudPath, rimPaint);

    // 3. Top-Left Glossy Specular Light Reflection
    final glossPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(w * 0.50, h * 0.28),
          radius: h * 0.20,
        ),
      );

    final glossPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.15, w * 0.30, h * 0.25));

    canvas.drawPath(glossPath, glossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Background Accents: Dashed circular orbit, amber rings, and floating dots
class _BackgroundAccentsPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _BackgroundAccentsPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final baseAmber = const Color(0xFFE58A18);

    // 1. Right Dotted Orbit Arc
    final orbitPaint = Paint()
      ..color = baseAmber.withValues(alpha: 0.35)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final orbitRect = Rect.fromCircle(
      center: Offset(w * 0.78, h * 0.38),
      radius: 65,
    );

    // Draw dashed arc
    _drawDashedArc(canvas, orbitRect, -0.9, 2.3, orbitPaint);

    // 2. Floating Golden Rings
    final ringPaint = Paint()
      ..color = baseAmber.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Small ring top-right
    canvas.drawCircle(Offset(w * 0.88, h * 0.30), 4.5, ringPaint);

    // Tiny dot near top-right ring
    final dotPaint = Paint()
      ..color = baseAmber.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.84, h * 0.22), 2.2, dotPaint);

    // Small ring top-left
    canvas.drawCircle(Offset(w * 0.15, h * 0.35), 3.5, ringPaint);

    // Floating dot bottom-left
    canvas.drawCircle(Offset(w * 0.18, h * 0.58), 2.5, dotPaint);
  }

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    const double dashAngle = 0.08;
    const double gapAngle = 0.08;
    double currentAngle = startAngle;
    final double endAngle = startAngle + sweepAngle;

    while (currentAngle < endAngle) {
      final double sweep = math.min(dashAngle, endAngle - currentAngle);
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundAccentsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 4-point golden star sparkle
class _SparkleStarPainter extends CustomPainter {
  final Color color;

  _SparkleStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx, cy, cx + r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy + r)
      ..quadraticBezierTo(cx, cy, cx - r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy - r)
      ..close();

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          color,
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
