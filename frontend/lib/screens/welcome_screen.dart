import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Fallback underneath image)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8DDA8),
                  Color(0xFFCBC5A3),
                ],
              ),
            ),
          ),

          // High-Res Sunrise City & Forest Skyline Background Image
          Image.asset(
            'assets/images/welcome_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (context, error, stackTrace) {
              return Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuCBUPb3DMaSkii6P2yKSPV6AOssvt8d8F3_bnxmC3p5HGTMzd3saG_3e522TpIPRC83AYPng07UOiK4kFM0_7sSKd2RHYSr1ZUTDN9LxiW-L7jUZo2C4prbdgLSBq1SSPIsz7w0LPYWRgWTz3QdiYP6FELpBRFGED94LfpfGQApo_8-yhkvybQUTjS-nxocmis9-AShjcC6a-WqXKlUaA62Q_ilnwCSiLl7woKIffr6W7M-CTtVZx0Ahg',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );
            },
          ),

          // Ambient Top Amber Overlay Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55FFE082), // Soft amber tint
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Ambient Bottom Subtle Dark Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: const [
                    Color(0x59000000), // 35% black opacity
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Brand Hero Section
                Padding(
                  padding: EdgeInsets.only(top: mediaQuery.size.height * 0.04),
                  child: Column(
                    children: [
                      // Official App Logo (KI Kanavu Illam)
                      Image.asset(
                        'assets/images/logo.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ).animate().fadeIn(duration: 800.ms).scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1.0, 1.0),
                          duration: 800.ms),
                    ],
                  ),
                ),

                // Middle Area Left Uncluttered to Showcase Skyline & Mist
                const Spacer(),

                // Bottom Action: Glassmorphism "Get Started" Pill Button
                Padding(
                  padding:
                      const EdgeInsets.only(left: 24, right: 24, bottom: 28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xF5F6F1DC), // Cream translucent fill
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000), // 20% black opacity
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      const AuthScreen(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    return FadeTransition(
                                        opacity: animation, child: child);
                                  },
                                  transitionDuration:
                                      const Duration(milliseconds: 600),
                                ),
                              );
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(
                                      width:
                                          32), // Symmetry balance for arrow button
                                  const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1B211C),
                                    ),
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1F2A21),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Color(0xFFF6F1DC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 800.ms)
                    .slideY(begin: 0.4, end: 0, duration: 800.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the exact KI House Outline Logo matching code.html SVG
class HouseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 34.0;
    final scaleY = size.height / 34.0;

    final paint = Paint()
      ..color = const Color(0xFF1B211C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // M17 4 L4 14.5 V28.5 C4 29.3284 4.67157 30 5.5 30 H28.5 C29.3284 30 30 29.3284 30 28.5 V14.5 L17 4 Z
    path.moveTo(17 * scaleX, 4 * scaleY);
    path.lineTo(4 * scaleX, 14.5 * scaleY);
    path.lineTo(4 * scaleX, 28.5 * scaleY);
    path.cubicTo(4 * scaleX, 29.3284 * scaleY, 4.67157 * scaleX, 30 * scaleY,
        5.5 * scaleX, 30 * scaleY);
    path.lineTo(28.5 * scaleX, 30 * scaleY);
    path.cubicTo(29.3284 * scaleX, 30 * scaleY, 30 * scaleX, 29.3284 * scaleY,
        30 * scaleX, 28.5 * scaleY);
    path.lineTo(30 * scaleX, 14.5 * scaleY);
    path.lineTo(17 * scaleX, 4 * scaleY);
    path.close();

    canvas.drawPath(path, paint);

    // Draw "KI" text inside logo
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'KI',
        style: TextStyle(
          fontFamily: 'Syne',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1B211C),
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 + (2 * scaleY),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
