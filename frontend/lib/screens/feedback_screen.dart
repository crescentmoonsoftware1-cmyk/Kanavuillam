import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'shell_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const FeedbackScreen({super.key, this.userData});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _submitted = false;

  void _submitFeedback() {
    if (_rating == 0 && _feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating or feedback first.')),
      );
      return;
    }
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you for your feedback!')),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    const Text(
                      'Report Downloaded Successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 40),
                    if (!_submitted) ...[
                      const Text(
                        'How was your experience?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 40,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                          );
                        }),
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Share your feedback with us (optional)...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitFeedback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Submit Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ).animate().fadeIn(delay: 700.ms),
                    ] else ...[
                      const Text(
                        'Thank you! Your feedback helps us improve Kanavu illam.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                      ).animate().fadeIn(),
                    ]
                  ],
                ),
              ),
            ),
            // Bottom Exit Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exitToHome,
                  icon: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444)),
                  label: const Text('Exit to Home', style: TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
