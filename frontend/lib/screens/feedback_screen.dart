import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'shell_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const FeedbackScreen({super.key, this.userData});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 4; // Default 4 stars matching mockup
  final TextEditingController _feedbackController = TextEditingController();
  bool _submitted = false;

  void _submitFeedback() {
    if (_rating == 0 && _feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please provide a rating or feedback first.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1B212F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _submitted = true);
  }

  void _exitToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => ShellScreen(userData: widget.userData),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE9EEF4),
              Color(0xFFD8DFE9),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── 1. Top 96px Badge (#2E3744 circle with #FBA73B amber ring) ──
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1B212F).withValues(alpha: 0.18),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 46,
                                ),
                              ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 20),

                              // ── 2. Title & Subtitle ──────────────────────────────
                              Text(
                                'Report Downloaded Successfully!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF18191D),
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                ),
                              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                              const SizedBox(height: 6),

                              Text(
                                'How was your experience?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8E94A0),
                                ),
                              ).animate().fadeIn(delay: 250.ms),
                              const SizedBox(height: 20),

                              if (!_submitted) ...[
                                // ── 3. 5 Outlined Stars filling with Amber #E58A18 ────
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
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: AnimatedScale(
                                          scale: isSelected ? 1.08 : 1.0,
                                          duration: const Duration(milliseconds: 180),
                                          child: Icon(
                                            isSelected
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: isSelected
                                                ? const Color(0xFFE58A18)
                                                : const Color(0xFF94A3B8),
                                            size: 34,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ).animate().fadeIn(delay: 350.ms),
                                const SizedBox(height: 22),

                                // ── 4. Feedback Multiline Text Card ──────────────────
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCFDFF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _feedbackController,
                                    maxLines: 3,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF18191D),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Share your feedback with us (optional)...',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.08),
                                const SizedBox(height: 26),

                                // ── 5. Primary Action Button: Submit Feedback ─────────
                                InkWell(
                                  onTap: _submitFeedback,
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    height: 56,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFBA73B),
                                          Color(0xFFE58A18),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE58A18).withValues(alpha: 0.35),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Submit Feedback',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E252D),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 550.ms),
                                const SizedBox(height: 12),
                              ] else ...[
                                // ── 4b. Thank You Confirmation Card ───────────────────
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCFDFF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Color(0xFFE58A18),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Thank you! Your feedback helps us improve Kanavu illam.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF18191D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn().scale(curve: Curves.easeOutBack),
                                const SizedBox(height: 24),
                              ],

                              // ── 6. Secondary Action Button: Exit to Home ─────────
                              InkWell(
                                onTap: _exitToHome,
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCFDFF),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.home_rounded,
                                        size: 20,
                                        color: Color(0xFF18191D),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Exit to Home',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF18191D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: 600.ms),
                            ],
                          ),
                        ),
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
}
