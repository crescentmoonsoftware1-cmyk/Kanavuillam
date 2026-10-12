import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';

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
  double _progress = 0.65;

  @override
  void initState() {
    super.initState();
    // Simulate initial scan progression
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _progress = 0.88);
      }
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
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

    final isDark = config.isDarkMode;
    final bgColor = config.bgColor;
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;
    final borderColor = config.borderColor;
    final surfacePillColor = config.surfacePillColor;

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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: primaryTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          config.tr('Payment Receipt', 'பணம் செலுத்திய ரசீது'),
          style: GoogleFonts.syne(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  // 1. SUCCESS BADGE & AMOUNT
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          config.tr(
                            'Payment Successful',
                            'பணம் வெற்றிகரமாக பெறப்பட்டது',
                          ),
                          style: GoogleFonts.syne(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${widget.amount.toInt()}.00',
                          style: GoogleFonts.syne(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 16),

                        // Receipt Details
                        _buildReceiptRow(
                          label: config.tr('Transaction ID', 'பரிவர்த்தனை எண்'),
                          value: '#KI-ORD-89412',
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 10),
                        _buildReceiptRow(
                          label: config.tr('Date & Time', 'தேதி & நேரம்'),
                          value: formattedDate,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 10),
                        _buildReceiptRow(
                          label: config.tr('Method', 'முறை'),
                          value: 'UPI / Direct',
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. LIVE AI PROCESSING PIPELINE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                config.tr(
                                  'Architecture Pipeline',
                                  'கட்டிடக்கலை பகுப்பாய்வு',
                                ),
                                style: GoogleFonts.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: surfacePillColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 14),

                        // Pipeline Steps
                        _buildPipelineStep(
                          title: config.tr(
                            'Reading walls & CAD dimensions',
                            'சுவர்கள் மற்றும் அளவுகள் ஆய்வு',
                          ),
                          isDone: true,
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildPipelineStep(
                          title: config.tr(
                            'Synthesizing 3D Villa Geometry',
                            '3D வில்லா மாதிரி உருவாக்கம்',
                          ),
                          isDone: true,
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildPipelineStep(
                          title: config.tr(
                            'Computing Vastu directional score',
                            'வாஸ்து திசைகள் கணக்கீடு',
                          ),
                          isDone: _progress >= 0.8,
                          isActive: _progress < 0.8,
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildPipelineStep(
                          title: config.tr(
                            'Generating BOQ & Cost estimation',
                            'கட்டுமான செலவு & BOQ கணக்கீடு',
                          ),
                          isDone: _progress >= 1.0,
                          isActive: _progress >= 0.8 && _progress < 1.0,
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildPipelineStep(
                          title: config.tr(
                            'Validating IS Code structural safety',
                            'கட்டமைப்பு பாதுகாப்பு சரிபார்ப்பு',
                          ),
                          isDone: _progress >= 1.0,
                          isActive: false,
                          config: config,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. ACTION TRIGGER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _handleStartGeneration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.white : AppColors.primary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isGenerating) ...[
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              _isGenerating
                                  ? config.tr('Opening Model...',
                                      'மாதிரி திறக்கிறது...')
                                  : config.tr(
                                      'VIEW 3D VILLA & REPORTS',
                                      '3D வில்லா & அறிக்கைகளை பார்க்கவும்',
                                    ),
                              style: GoogleFonts.inter(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isGenerating) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
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
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPipelineStep({
    required String title,
    required bool isDone,
    bool isActive = false,
    required AppConfigProvider config,
  }) {
    final isDark = config.isDarkMode;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDone
                ? (isDark ? Colors.white : AppColors.primary)
                : (isActive ? config.surfacePillColor : Colors.transparent),
            shape: BoxShape.circle,
            border: isDone || isActive
                ? null
                : Border.all(color: config.borderColor, width: 1.5),
          ),
          child: isDone
              ? Icon(
                  Icons.check,
                  size: 13,
                  color: isDark ? Colors.black : Colors.white,
                )
              : (isActive
                  ? Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    )
                  : null),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight:
                  isDone || isActive ? FontWeight.w600 : FontWeight.w400,
              color: isDone || isActive
                  ? config.primaryTextColor
                  : config.secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }
}
