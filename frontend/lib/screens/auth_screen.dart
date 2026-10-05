import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../utils/legal_texts.dart';
import 'user_details_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreedToLegal = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final endpoint = _isLogin ? '/auth/login' : '/auth/signup';
      final body = {
        'email': _emailController.text,
        'password': _passwordController.text,
        if (!_isLogin) 'name': _nameController.text,
      };

      final response = await ApiService.post(endpoint, body);

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => UserDetailsScreen(userData: response['user'])),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response?['error'] ?? 'Authentication failed'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize(
        serverClientId:
            '665187508900-rrg56qkkn3jqa6cjj0s8401qkk5b6vfo.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      final response = await ApiService.post('/auth/google/token', {
        'idToken': idToken,
        'email': googleUser.email,
        'name': googleUser.displayName,
      });

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => UserDetailsScreen(userData: response['user'])),
          );
        }
      } else {
        throw Exception(
            response?['error'] ?? 'Google Authentication failed on server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLegalBottomSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFCD34D),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: _buildSimpleMarkdownText(content),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleMarkdownText(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              line.replaceFirst('# ', ''),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFCD34D)),
            ),
          );
        } else if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 20),
            child: Text(
              line.replaceFirst('## ', ''),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          );
        } else if (line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(fontSize: 16, color: Color(0xFFFCD34D))),
                Expanded(
                    child: Text(line.replaceFirst('* ', ''),
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70, height: 1.5))),
              ],
            ),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: const TextStyle(
                  fontSize: 14, color: Colors.white70, height: 1.5),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
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
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFFCD34D), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFFCD34D),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
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
                color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
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
                      // Header: App Logo Badge + Title
                      _buildHeaderSection(),
                      const SizedBox(height: 24),

                      // Glassmorphic Auth Card
                      _buildGlassAuthCard(),
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
        // App Logo - Larger & Clean Without Orange Container Tint
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

        const SizedBox(height: 14),

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
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

        const SizedBox(height: 4),

        const Text(
          'AI-Powered Architectural Design',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildGlassAuthCard() {
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
                // Title Pill & Headline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isLogin ? 'WELCOME' : 'JOIN US',
                            style: const TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 9,
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

                Text(
                  _isLogin
                      ? 'Welcome back! Ready to build your dream home?'
                      : 'Join Kanavu Illam and explore AI floor plans!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 22),

                // Name input (for Sign Up)
                if (!_isLogin)
                  _buildGlassTextField(
                    controller: _nameController,
                    hint: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                // Email input
                _buildGlassTextField(
                  controller: _emailController,
                  hint: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                // Password input
                _buildGlassTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                // Forgot Password Link
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Password reset link sent to your email.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 380.ms),

                // Legal Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _agreedToLegal,
                        onChanged: (val) {
                          setState(() {
                            _agreedToLegal = val ?? false;
                          });
                        },
                        activeColor: const Color(0xFFFBBF24),
                        checkColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        children: [
                          const Text(
                            'I agree to the ',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => _showLegalBottomSheet(
                              'Terms & Conditions',
                              LegalTexts.termsAndConditions,
                            ),
                            child: const Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                color: Color(0xFFFCD34D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFFCD34D),
                              ),
                            ),
                          ),
                          const Text(
                            ' and ',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => _showLegalBottomSheet(
                              'Privacy Policy',
                              LegalTexts.privacyPolicy,
                            ),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: Color(0xFFFCD34D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFFCD34D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 22),

                // Action Button
                GestureDetector(
                  onTap: (_isLoading || !_agreedToLegal)
                      ? () {
                          if (!_agreedToLegal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please accept Terms & Conditions to proceed.',
                                ),
                                backgroundColor: Colors.amber,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _agreedToLegal
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFFBBF24),
                                Color(0xFFF59E0B),
                                Color(0xFFD97706),
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                const Color(0xFFFBBF24).withValues(alpha: 0.4),
                                const Color(0xFFD97706).withValues(alpha: 0.4),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: _agreedToLegal
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.40),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin ? 'Signing In...' : 'Signing Up...',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const SizedBox(
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
                              children: [
                                Text(
                                  _isLogin ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 19,
                                ),
                              ],
                            ),
                    ),
                  ),
                ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1),

                const SizedBox(height: 22),

                // OR Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.15),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.15),
                        thickness: 1,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 18),

                // Google Social Login Button
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (!_agreedToLegal) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please agree to the Terms & Conditions and Privacy Policy to continue.',
                            ),
                            backgroundColor: Colors.amber,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      _signInWithGoogle();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/search.png',
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Google Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 550.ms),

                const SizedBox(height: 20),

                // Toggle Login / Sign Up
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _emailController.clear();
                        _passwordController.clear();
                        _nameController.clear();
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        text: _isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: _isLogin ? 'Sign Up' : 'Sign In',
                            style: const TextStyle(
                              color: Color(0xFFFCD34D),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFFFCD34D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
