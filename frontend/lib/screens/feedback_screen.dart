import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import 'shell_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const FeedbackScreen({super.key, this.userData});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 4;
  final TextEditingController _feedbackController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! Your feedback helps us improve Kanavu Illam.'),
        backgroundColor: Color(0xFF1B212F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exitToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => ShellScreen(userData: widget.userData)),
      (route) => false,
    );
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
    final isDark = config.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // 1. Large 96px #2E3744 circle with check and amber ring #FBA73B
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3744),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFBA73B),
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E1B212F),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 20),

                    // 2. Title & Subtitle
                    Text(
                      isTamil
                          ? 'அறிக்கை வெற்றிகரமாக பதிவிறக்கப்பட்டது!'
                          : 'Report Downloaded Successfully!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF18191D),
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 6),

                    Text(
                      isTamil ? 'உங்கள் அனுபவம் எப்படி இருந்தது?' : 'How was your experience?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 20),

                    // 3. 5 Stars (selected amber #E58A18, unselected #94A3B8)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final isSelected = index < _rating;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isSelected ? const Color(0xFFE58A18) : const Color(0xFF94A3B8),
                              size: 34,
                            ),
                          ),
                        );
                      }),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 20),

                    // 4. Feedback Multiline Text Field Card
                    if (!_submitted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _feedbackController,
                          maxLines: 3,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF18191D),
                          ),
                          decoration: InputDecoration(
                            hintText: isTamil
                                ? 'உங்கள் கருத்துக்களை எங்களுடன் பகிரவும் (விருப்பத்தேர்வு)...'
                                : 'Share your feedback with us (optional)...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          isTamil
                              ? 'நன்றி! உங்கள் கருத்து கனவு இல்லத்தை மேம்படுத்த உதவுகிறது.'
                              : 'Thank you! Your feedback helps us improve Kanavu Illam.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ).animate().fadeIn(),

                    const Spacer(),

                    // 5. Action Buttons (Submit Feedback & Exit to Home)
                    Column(
                      children: [
                        if (!_submitted) ...[
                          GestureDetector(
                            onTap: _submitFeedback,
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFBA73B), Color(0xFFE58A18)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x59E58A18),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  isTamil ? 'கருத்தை சமர்ப்பிக்கவும்' : 'Submit Feedback',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E252D),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Exit to Home Pill Button
                        GestureDetector(
                          onTap: _exitToHome,
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_outlined,
                                  size: 18,
                                  color: isDark ? Colors.white : const Color(0xFF18191D),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isTamil ? 'முகப்புக்குச் செல்லவும்' : 'Exit to Home',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF18191D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
