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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/house.gif',
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
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

