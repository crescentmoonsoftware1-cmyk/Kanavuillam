import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final double amount;
  final VoidCallback? onFinish;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    this.onFinish,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HouseConstructionLoader(size: 220),
              const SizedBox(height: 32),
              const Text(
                'Loading your home...',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF475569),
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .scaleXY(
                        begin: 0.5,
                        end: 1.5,
                        duration: 400.ms,
                        curve: Curves.easeInOut,
                        delay: (index * 100).ms,
                      )
                      .then()
                      .scaleXY(
                        begin: 1.5,
                        end: 0.5,
                        duration: 400.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[now.month - 1];
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    final formattedDate = '${now.day} $month ${now.year}, $hour:$minute $ampm';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Animation & Confetti Effect
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4ADE80),
                    size: 80,
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  // Confetti Dots (Simulated)
                  ...List.generate(
                      12,
                      (index) => Positioned(
                            top: 60 + (30 * (index % 2 == 0 ? 1 : -1)),
                            left: 60 + (30 * (index > 6 ? 1 : -1)),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.orangeAccent,
                                  shape: BoxShape.circle),
                            )
                                .animate()
                                .slide(
                                    duration: 1.seconds,
                                    begin: Offset.zero,
                                    end: Offset(index.toDouble() - 6,
                                        index.toDouble() - 6))
                                .fadeOut(),
                          )),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Payment Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 8),

              Text(
                '₹${widget.amount.toInt()} Paid Successfully',
                style: const TextStyle(
                  color: Color(0xFF2979FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 32),

              // Transaction Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    _detailRow('Payment ID', '#PXN78451236'),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    _detailRow('Date & Time', formattedDate),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    _detailRow('Payment Method', 'UPI'),
                    const Divider(color: Color(0xFFE2E8F0), height: 24),
                    _detailRow('Amount', '₹${widget.amount.toInt()}',
                        isTotal: true),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // Generation Status

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGenerating
                      ? null
                      : () {
                          setState(() => _isGenerating = true);
                          debugPrint(
                              'SUCCESS_SCREEN: Generate button clicked, calling onFinish');
                          widget.onFinish?.call();
                          // Give a delay for the animation to play before popping
                          Future.delayed(const Duration(milliseconds: 2500),
                              () {
                            if (mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            }
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGenerating)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else ...[
                        const Text(
                          'START AI GENERATION',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.auto_awesome_rounded, size: 20),
                      ],
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms),

              const SizedBox(height: 16),
              Text(
                'You will receive an email confirmation shortly',
                style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 11),
              ).animate().fadeIn(delay: 1200.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? const Color(0xFF2979FF) : const Color(0xFF1E293B),
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    );
  }
}

// ─── Custom 8-Step House Construction Animation ────────────────────────────

class HouseConstructionLoader extends StatefulWidget {
  final double size;
  const HouseConstructionLoader({super.key, this.size = 200});

  @override
  State<HouseConstructionLoader> createState() => _HouseConstructionLoaderState();
}

class _HouseConstructionLoaderState extends State<HouseConstructionLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), // 6 seconds per full build cycle
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: HouseConstructionPainter(progress: _controller.value * 8.0),
        );
      },
    );
  }
}

class HouseConstructionPainter extends CustomPainter {
  final double progress;
  HouseConstructionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Helper to calculate completion of each of the 8 steps (0.0 to 1.0)
    double step(double stepNum) => (progress - stepNum).clamp(0.0, 1.0);

    // Common coordinates
    final bottomY = h - 40;
    final topY = bottomY - 60;
    
    // Background Sky Gradient
    final Rect bgRect = Rect.fromLTRB(0, 0, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(20)), 
      Paint()..color = const Color(0xFFF0F9FF));
    
    // Ground
    canvas.drawRect(Rect.fromLTRB(0, bottomY + 10, w, h), Paint()..color = const Color(0xFFD4D4D8));

    // 1. Foundation (Concrete Base)
    if (progress > 0) {
      final p = step(0);
      final baseRect = Rect.fromCenter(
          center: Offset(w/2, bottomY + 5), width: w * 0.7 * p, height: 10 * p);
      canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2)), 
          Paint()..color = const Color(0xFF94A3B8));
    }

    // 2. Structure (RCC Pillars & Beams)
    if (progress > 1) {
      final p = step(1);
      final pillarPaint = Paint()..color = const Color(0xFF64748B);
      // 4 Pillars
      for (int i = 0; i < 4; i++) {
        double x = w * 0.2 + (w * 0.6 / 3) * i;
        canvas.drawRect(Rect.fromLTRB(x - 4, topY + (60 * (1-p)), x + 4, bottomY), pillarPaint);
      }
      // Top Beam
      canvas.drawRect(Rect.fromLTRB(w * 0.18, topY - 8, w * 0.82, topY), pillarPaint);
    }

    // 3. Walls (Red Bricks)
    if (progress > 2) {
      final p = step(2);
      final wallPaint = Paint()..color = const Color(0xFFD97757);
      // Animating walls growing upwards
      canvas.drawRect(Rect.fromLTRB(w * 0.2, topY + (60 * (1-p)), w * 0.8, bottomY), wallPaint);
      
      // Brick texture lines (subtle)
      final brickLine = Paint()..color = Colors.black12..strokeWidth = 1;
      for (int i = 1; i < 5; i++) {
        double y = bottomY - (i * 12);
        if (y > topY + (60 * (1-p))) {
           canvas.drawLine(Offset(w * 0.2, y), Offset(w * 0.8, y), brickLine);
        }
      }
    }

    // 4. Roof Truss (Wooden Frame)
    if (progress > 3) {
      final p = step(3);
      final trussPaint = Paint()..color = const Color(0xFFD97757).withValues(alpha: 0.8)..strokeWidth = 3..style = PaintingStyle.stroke;
      final roofPeak = topY - 45 * p;
      
      Path path = Path();
      path.moveTo(w * 0.15, topY);
      path.lineTo(w * 0.5, roofPeak);
      path.lineTo(w * 0.85, topY);
      path.close();
      canvas.drawPath(path, trussPaint);
      
      // Inner truss supports
      canvas.drawLine(Offset(w * 0.5, roofPeak), Offset(w * 0.5, topY), trussPaint);
    }

    // 5. Roofing (Terracotta Roof Tiles)
    if (progress > 4) {
      final p = step(4);
      final roofPaint = Paint()..color = const Color(0xFFB91C1C)..style = PaintingStyle.fill;
      final roofPeak = topY - 50;
      
      Path path = Path();
      path.moveTo(w * 0.1, topY + 5);
      path.lineTo(w * 0.5, roofPeak);
      path.lineTo(w * 0.9, topY + 5);
      path.close();
      
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, topY - 60 * p, w, topY + 10));
      canvas.drawPath(path, roofPaint);
      canvas.restore();
    }

    // 6. Plastering & Openings (White Walls, Doors, Windows)
    if (progress > 5) {
      final p = step(5);
      // White Plaster fade in
      final plasterPaint = Paint()..color = Colors.white.withValues(alpha: p);
      canvas.drawRect(Rect.fromLTRB(w * 0.2, topY, w * 0.8, bottomY), plasterPaint);
      
      // Door
      canvas.drawRect(Rect.fromLTRB(w * 0.45, bottomY - 35 * p, w * 0.55, bottomY), 
          Paint()..color = const Color(0xFF78350F).withValues(alpha: p));
          
      // Windows
      final winPaint = Paint()..color = const Color(0xFFBAE6FD).withValues(alpha: p);
      final winBorder = Paint()..color = const Color(0xFF475569).withValues(alpha: p)..style = PaintingStyle.stroke..strokeWidth=2;
      
      // Left Window
      canvas.drawRect(Rect.fromLTRB(w * 0.28, topY + 15, w * 0.38, topY + 35 * p), winPaint);
      canvas.drawRect(Rect.fromLTRB(w * 0.28, topY + 15, w * 0.38, topY + 35 * p), winBorder);
      
      // Right Window
      canvas.drawRect(Rect.fromLTRB(w * 0.62, topY + 15, w * 0.72, topY + 35 * p), winPaint);
      canvas.drawRect(Rect.fromLTRB(w * 0.62, topY + 15, w * 0.72, topY + 35 * p), winBorder);
    }

    // 7. Finishing (Steps & Garden)
    if (progress > 6) {
      final p = step(6);
      // Entrance Steps
      canvas.drawRect(Rect.fromLTRB(w * 0.42, bottomY, w * 0.58, bottomY + 6 * p), Paint()..color = const Color(0xFFCBD5E1));
      canvas.drawRect(Rect.fromLTRB(w * 0.40, bottomY + 6, w * 0.60, bottomY + 12 * p), Paint()..color = const Color(0xFF94A3B8));
      
      // Garden bushes
      final plantPaint = Paint()..color = const Color(0xFF16A34A);
      canvas.drawCircle(Offset(w * 0.25, bottomY), 10 * p, plantPaint);
      canvas.drawCircle(Offset(w * 0.32, bottomY + 2), 8 * p, plantPaint);
      canvas.drawCircle(Offset(w * 0.75, bottomY), 10 * p, plantPaint);
      canvas.drawCircle(Offset(w * 0.68, bottomY + 2), 8 * p, plantPaint);
    }

    // 8. Completed Home (Sun & Shine)
    if (progress > 7) {
      final p = step(7);
      // Sun
      canvas.drawCircle(Offset(w * 0.85, h * 0.15), 18 * p, Paint()..color = const Color(0xFFFBBF24).withValues(alpha: p));
      
      // Shine/Glow Effect
      final Rect glowRect = Rect.fromLTRB(0, 0, w, h);
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.3 * p), Colors.transparent],
        ).createShader(glowRect);
      canvas.drawRect(glowRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HouseConstructionPainter oldDelegate) => true;
}
