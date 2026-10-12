import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/providers/app_config_provider.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    final isDark = config.isDarkMode;
    final bgColor = config.bgColor;
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final borderColor = config.borderColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 32.0, bottom: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand Hero
              Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(96, 96),
                          painter: _LogoPainter(color: primaryTextColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 14.0),
                          child: Text(
                            'KI',
                            style: GoogleFonts.syne(
                              fontSize: 31,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 31 * 0.08,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kanavu Illam',
                    style: GoogleFonts.syne(
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      color: primaryTextColor,
                      letterSpacing: -0.34,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              
              // Center Architectural 3D Card
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    height: 260,
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          // Faint grid pattern underlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPainter(color: primaryTextColor),
                            ),
                          ),
                          
                          // 3D Architectural Villa Render Image
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida/AEtjO1U4dme8d1LPK7s4Yav-Viq55cHjDbJnaR-NnR0yiX0Cz3Qedd3UsPqrnaP_MM8mXjJebj3AjstvloDN1LL33jcLzQ9KIie1S0Mie9IVW6PZZnBELw24r7tKfBwAqf74aQz56VO7TsfXn372VvzfmEwWE49FEDhIuYIa2uw89CFOApmFFU-iv4jGLavGJLkQ5Jj8kntINOZmymiVz18BBAxoVOgM_1xKNFx80kDTT4pW-ner3kplkEXFrqE',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.home_work_outlined, size: 64, color: config.surfacePillColor),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          // Blueprint Corner Crosshair Accents
                          Positioned(top: 16, left: 16, child: _CornerAccent(top: true, left: true, color: borderColor)),
                          Positioned(top: 16, right: 16, child: _CornerAccent(top: true, left: false, color: borderColor)),
                          Positioned(bottom: 16, left: 16, child: _CornerAccent(top: false, left: true, color: borderColor)),
                          Positioned(bottom: 16, right: 16, child: _CornerAccent(top: false, left: false, color: borderColor)),
                          
                          // Corner Micro Badge
                          Positioned(
                            bottom: 12,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: config.surfacePillColor,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: primaryTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SCALE 1:100',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: config.secondaryTextColor,
                                      letterSpacing: 0.6,
                                      height: 1.0,
                                    ),
                                  ),
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

              // Bottom Action: "Get started" button
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(isLogin: true),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 22),
                      Text(
                        config.tr('Get started', 'தொடங்குக'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 22,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final bool top;
  final bool left;
  final Color color;
  
  const _CornerAccent({required this.top, required this.left, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color) : BorderSide.none,
          bottom: !top ? BorderSide(color: color) : BorderSide.none,
          left: left ? BorderSide(color: color) : BorderSide.none,
          right: !left ? BorderSide(color: color) : BorderSide.none,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;
    
    const double spacing = 16.0;
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(17, 4);
    path.lineTo(4, 14.5);
    path.lineTo(4, 28.5);
    path.arcToPoint(const Offset(5.5, 30), radius: const Radius.circular(1.5), clockwise: false);
    path.lineTo(28.5, 30);
    path.arcToPoint(const Offset(30, 28.5), radius: const Radius.circular(1.5), clockwise: false);
    path.lineTo(30, 14.5);
    path.close();

    canvas.save();
    canvas.scale(size.width / 34, size.height / 34);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.color != color;
}
