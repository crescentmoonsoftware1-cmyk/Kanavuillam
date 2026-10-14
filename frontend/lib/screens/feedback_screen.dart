import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
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

  void _submitFeedback(bool isTamil) {
    if (_rating == 0 && _feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTamil
                ? 'தயவுசெய்து மதிப்பீடு அல்லது கருத்தை வழங்கவும்.'
                : 'Please provide a rating or feedback first.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTamil
              ? 'உங்கள் கருத்துக்கு நன்றி!'
              : 'Thank you for your feedback!',
        ),
      ),
    );
  }

  void _exitToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) => ShellScreen(userData: widget.userData)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final isTamil = config.isTamil;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9EEF4), Color(0xFFD8DFE9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Large 96px #2E3744 Circle with check and amber ring #FBA73B
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
                    ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 20),

                    // 2. Title & Subtitle
                    Text(
                      isTamil
                          ? 'அறிக்கை வெற்றிகரமாக\nபதிவிறக்கப்பட்டது!'
                          : 'Report Downloaded\nSuccessfully!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18191D),
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ).animate().fadeIn(delay: 150.ms),

                    const SizedBox(height: 8),

                    Text(
                      isTamil
                          ? 'உங்கள் அனுபவம் எப்படி இருந்தது?'
                          : 'How was your experience?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8E94A0),
                      ),
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 20),

                    // 3. 5 Interactive Stars (#E58A18 when active, outlined #94A3B8 when inactive)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final bool isFilled = index < _rating;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              isFilled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFilled
                                  ? const Color(0xFFE58A18)
                                  : const Color(0xFF94A3B8),
                              size: 34,
                            ),
                          ),
                        );
                      }),
                    ).animate().fadeIn(delay: 350.ms).scale(curve: Curves.easeOut),

                    const SizedBox(height: 24),

                    // 4. Feedback Multiline Text Field Card & Actions
                    if (!_submitted) ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFDFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: TextField(
                          controller: _feedbackController,
                          maxLines: 3,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF18191D),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: isTamil
                                ? 'உங்கள் கருத்துக்களை பகிரவும் (விருப்பத்தேர்வு)...'
                                : 'Share your feedback with us (optional)...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 24),

                      // 5. Action Buttons (Submit Feedback & Exit to Home)
                      Column(
                        children: [
                          // Submit Feedback (Primary Yellow-Gold Gradient Pill)
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
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
                              child: ElevatedButton(
                                onPressed: () => _submitFeedback(isTamil),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                child: Text(
                                  isTamil ? 'கருத்துக்களை சமர்ப்பிக்கவும்' : 'Submit Feedback',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E252D),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 550.ms),

                          const SizedBox(height: 12),

                          // Exit to Home (Secondary White Capsule Pill)
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _exitToHome,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFFCFDFF),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                elevation: 1,
                                shadowColor: Colors.black.withValues(alpha: 0.04),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.home_outlined,
                                    size: 19,
                                    color: Color(0xFF18191D),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isTamil ? 'முகப்புக்குச் செல்' : 'Exit to Home',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF18191D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 650.ms),
                        ],
                      ),
                    ] else ...[
                      // Submitted Thank You Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFDFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              isTamil
                                  ? 'நன்றி! உங்கள் கருத்து கனவு இல்லத்தை மேம்படுத்த உதவும்.'
                                  : 'Thank you! Your feedback helps us improve Kanavu Illam.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF18191D),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _exitToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF18191D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.home_outlined,
                                size: 19,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTamil ? 'முகப்புக்குச் செல்' : 'Exit to Home',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
