import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'payment_success_screen.dart';

class UpiProcessingScreen extends StatefulWidget {
  final double amount;
  final VoidCallback? onFinish;

  const UpiProcessingScreen({super.key, required this.amount, this.onFinish});

  @override
  State<UpiProcessingScreen> createState() => _UpiProcessingScreenState();
}

class _UpiProcessingScreenState extends State<UpiProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _simulateProcessing();
  }

  void _simulateProcessing() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
              amount: widget.amount, onFinish: widget.onFinish),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Processing Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          _buildSecurityBadge(),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProcessingCircle(),
              const SizedBox(height: 48),
              const Text(
                'Opening UPI App...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              const Text(
                'Please complete the payment\nin your UPI application',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 60),
              _buildStatusList(),
              const SizedBox(height: 60),
              _buildCancelButton(),
              const SizedBox(height: 40),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: Color(0xFF22D3EE), size: 14),
          SizedBox(width: 6),
          Text('100% Secure',
              style: TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildProcessingCircle() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
            backgroundColor: Colors.white.withValues(alpha: 0.05),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .rotate(duration: 2.seconds),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Center(
            child: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/UPI-Logo.png/640px-UPI-Logo.png',
              height: 30,
              errorBuilder: (c, e, s) =>
                  const Icon(Icons.payment, color: Colors.white, size: 40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusList() {
    return Column(
      children: [
        _statusItem('Do not close this screen', true),
        _statusItem('You will be redirected automatically', true),
        _statusItem('Payment status will be updated instantly', true),
      ],
    );
  }

  Widget _statusItem(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: active ? Colors.green : Colors.white10, size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                  color: active ? Colors.white70 : Colors.white24,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color.fromARGB(255, 210, 207, 207)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('Cancel Payment',
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Secured by',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10)),
        const SizedBox(width: 8),
        const Icon(Icons.bolt, color: Colors.white24, size: 14),
        const Text('Razorpay',
            style: TextStyle(
                color: Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic)),
      ],
    );
  }
}
