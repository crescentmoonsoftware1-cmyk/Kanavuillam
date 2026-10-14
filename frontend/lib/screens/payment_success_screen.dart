import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';

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
  double _progress = 0.88;

  @override
  void initState() {
    super.initState();
    // Simulate progression
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _progress = 1.0);
      }
    });
  }

  void _handleStartGeneration() {
    setState(() => _isGenerating = true);
    widget.onFinish?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }
    final isTamil = config.isTamil;

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. HEADER ROW ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.canvasGradientTop,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              isTamil ? 'பணம் செலுத்திய ரசீது' : 'Payment Receipt',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 36), // Balance the back button
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── 2. SCROLLABLE CARDS ──────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // Card 1: Success Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x141B212F),
                                    blurRadius: 32,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // 72px circle with check and amber ring
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.badgeSlate,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.amberHighlight, width: 2.0),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isTamil ? 'பணம் வெற்றிகரமாக பெறப்பட்டது' : 'Payment Successful',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${widget.amount.toInt()}.00',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.inkPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                                  const SizedBox(height: 14),

                                  // Receipt Rows
                                  _buildReceiptRow(
                                    label: isTamil ? 'பரிவர்த்தனை எண்' : 'Transaction ID',
                                    value: 'TXN-98421804',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildReceiptRow(
                                    label: isTamil ? 'தேதி & நேரம்' : 'Date & Time',
                                    value: formattedDate,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildReceiptRow(
                                    label: isTamil ? 'முறை' : 'Method',
                                    value: 'UPI (Google Pay)',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Card 2: Architecture Pipeline
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18.0),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x141B212F),
                                    blurRadius: 32,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isTamil ? 'கட்டிடக்கலை பகுப்பாய்வு' : 'Architecture Pipeline',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${(_progress * 100).toInt()}%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Amber Progress Bar
                                  Container(
                                    width: double.infinity,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _progress.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.amberGradient,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // 5 Checklist steps
                                  _buildPipelineStep(
                                    title: isTamil
                                        ? 'சுவர்கள் மற்றும் அளவுகள் ஆய்வு'
                                        : 'Reading walls & CAD dimensions',
                                    isDone: true,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPipelineStep(
                                    title: isTamil
                                        ? '3D வில்லா மாதிரி உருவாக்கம்'
                                        : 'Synthesising 3D Villa geometry',
                                    isDone: true,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPipelineStep(
                                    title: isTamil
                                        ? 'வாஸ்து திசைகள் கணக்கீடு'
                                        : 'Computing Vastu directional score',
                                    isDone: true,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPipelineStep(
                                    title: isTamil
                                        ? 'கட்டுமான செலவு & BOQ கணக்கீடு'
                                        : 'Generating BOQ & Cost estimation',
                                    isDone: _progress >= 1.0,
                                    isActive: _progress < 1.0,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildPipelineStep(
                                    title: isTamil
                                        ? 'கட்டமைப்பு பாதுகாப்பு சரிபார்ப்பு'
                                        : 'Validating IS Code structural safety',
                                    isDone: _progress >= 1.0,
                                    isActive: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── 3. BOTTOM CTA BUTTON ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AppDecor.primaryPillButton(
                        label: isTamil ? '3D வில்லா & அறிக்கைகளை பார்க்கவும்' : 'VIEW 3D VILLA & REPORTS',
                        onTap: _handleStartGeneration,
                        isLoading: _isGenerating,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.inkQuiet,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineStep({
    required String title,
    required bool isDone,
    bool isActive = false,
  }) {
    return Row(
      children: [
        if (isDone)
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.badgeSlate,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 13,
              color: Colors.white,
            ),
          )
        else if (isActive)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.amberDefault),
            ),
          )
        else
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8DFE9), width: 2),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isDone || isActive ? FontWeight.w600 : FontWeight.w400,
              color: isDone || isActive ? AppColors.inkPrimary : AppColors.inkQuiet,
            ),
          ),
        ),
      ],
    );
  }
}
