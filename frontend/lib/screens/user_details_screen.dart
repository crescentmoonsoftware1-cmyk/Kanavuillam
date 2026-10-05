import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const UserDetailsScreen({super.key, this.userData});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.userData?['name'] ?? '');
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitDetails() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details to proceed'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_address', _addressController.text.trim());

    if (widget.userData?['email'] != null) {
      await prefs.setString('user_email', widget.userData!['email']);
    }

    // Small delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => ShellScreen(userData: widget.userData)),
      );
    }
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFFCD34D), size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // 1. Architectural Luxury Villa Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/luxury_villa_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/architectural_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                );
              },
            ),
          ),

          // 2. Dark Scrim & Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.75),
                    const Color(0xFF090D16).withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),
          ),

          // 3. Ambient Gold Warm Glow Bulbs
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFCD34D).withValues(alpha: 0.12),
              ),
            ),
          ),

          // 4. Main Scrollable Content
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo Header
                      _buildHeaderSection(),
                      const SizedBox(height: 24),

                      // Glass Card Form
                      _buildGlassFormCard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // App Logo
        Container(
          height: 135,
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) {
              return const Icon(
                Icons.architecture_rounded,
                color: Color(0xFFFCD34D),
                size: 75,
              );
            },
          ),
        )
            .animate()
            .scale(duration: 500.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 12),

        // App Brand Name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFFCD34D),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFFFCD34D), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'KANAVU ILLAM',
              style: TextStyle(
                color: Color(0xFFFCD34D),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildGlassFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            color: Colors.white.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Complete Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'PROFILE SETUP',
                            style: TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 6),

                const Text(
                  'We need a few details to personalize your experience and generate accurate 3D & BOQ reports.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 24),

                // Name Input
                _buildGlassTextField(
                  controller: _nameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline_rounded,
                ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.08),

                // Phone Input
                _buildGlassTextField(
                  controller: _phoneController,
                  hint: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.08),

                // Location Input
                _buildGlassTextField(
                  controller: _addressController,
                  hint: 'Site location',
                  icon: Icons.location_on_outlined,
                ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.08),

                const SizedBox(height: 12),

                // Submit Action Button
                GestureDetector(
                  onTap: _isLoading ? null : _submitDetails,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFBBF24),
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Saving Details...',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF0F172A),
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Continue to App',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 19,
                                ),
                              ],
                            ),
                    ),
                  ),
                ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
