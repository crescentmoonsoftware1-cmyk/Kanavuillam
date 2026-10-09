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

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isLogin && !_agreedToLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms to continue.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final endpoint = _isLogin ? '/auth/login' : '/auth/signup';
      final body = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        if (!_isLogin) 'name': _nameController.text.trim(),
      };

      final response = await ApiService.post(endpoint, body);

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => UserDetailsScreen(userData: response['user']),
            ),
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

      final googleUser = await googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
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
              builder: (_) => UserDetailsScreen(userData: response['user']),
            ),
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
      backgroundColor: const Color(0xFFF6F1DC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          fontFamily: 'Syne',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B211C),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF1B211C)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFD9D2B0), height: 1),
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
                fontFamily: 'Syne',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B211C),
              ),
            ),
          );
        } else if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 20),
            child: Text(
              line.replaceFirst('## ', ''),
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B211C),
              ),
            ),
          );
        } else if (line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(fontSize: 16, color: Color(0xFF1F2A21))),
                Expanded(
                  child: Text(
                    line.replaceFirst('* ', ''),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF6B6A52),
                      height: 1.5,
                    ),
                  ),
                ),
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
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF6B6A52),
                height: 1.5,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  // Custom Input Field with exact styling matching design system
  Widget _buildCustomInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isFocused = focusNode.hasFocus;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8EA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? const Color(0xFF1F2A21) : const Color(0xFFD9D2B0),
          width: isFocused ? 1.5 : 1.0,
        ),
        boxShadow: isFocused
            ? const [
                BoxShadow(
                  color: Color(0x40F2CB4B), // Golden focus ring
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF1B211C),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF6B6A52),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: const Color(0xFF7C7A3C),
              size: 20,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF7C7A3C),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    // Dynamic top zone height so sheet has ample space to fit everything in 1 viewport
    final topZoneHeight = (screenHeight * 0.30).clamp(180.0, 260.0);
    final isCompact = screenHeight < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1DC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: Top Sunrise City Background & Branding
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topZoneHeight + 35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Sunrise Image
                Image.asset(
                  'assets/images/welcome_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDbdKPAYD3ZGh7eXLnPY3hqTzoPD4M6FXa0CNiZcZLAwDoTbwxfO4Punj0-mvvh3ktPnO1X5J0CsFv5QzvNBpHoZvlIobPYVOVKoxaOV3FWJFIZzSYOecfyxtCDF-SIcZw0HEQlm9MzZDz0fRuPmta_mpDiBi0YPvfgayaPZf2Kx_sK1q2cgCvUJRL8VuZH-3mFqzN56erEcYl5UXyYCfwUXxkNED3vklF9djIyGb12oA26T44_V-Nmhg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFE8DDA8)),
                    );
                  },
                ),

                // Warm Gradient Fade into Bottom Sheet
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.4, 0.8, 1.0],
                      colors: [
                        Colors.transparent,
                        Color(0x22E8DDA8),
                        Color(0x99F6F1DC),
                        Color(0xFFF6F1DC),
                      ],
                    ),
                  ),
                ),

                // Top Centered Brand Logo
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: isCompact ? 80 : 95,
                        fit: BoxFit.contain,
                      ).animate().fadeIn(duration: 500.ms).scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.0, 1.0),
                          duration: 500.ms),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LAYER 2: Bottom Sheet Container (Starts right below Top Zone & fills to bottom)
          Positioned(
            top: topZoneHeight - 20,
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F1DC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: Color(0x99D9D2B0), width: 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x141B211C),
                    blurRadius: 32,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(24, isCompact ? 14 : 20, 24, 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: isCompact
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Main Form Content Group
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sheet Title: Welcome back / Create account
                                      Text(
                                        _isLogin
                                            ? 'Welcome back'
                                            : 'Create account',
                                        style: const TextStyle(
                                          fontFamily: 'Syne',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1B211C),
                                          letterSpacing: -0.3,
                                        ),
                                      ).animate().fadeIn(duration: 400.ms),

                                      SizedBox(height: isCompact ? 10 : 14),

                                      // Form Inputs
                                      Column(
                                        children: [
                                          // Full Name Field (Sign Up Only)
                                          if (!_isLogin) ...[
                                            _buildCustomInputField(
                                              controller: _nameController,
                                              focusNode: _nameFocusNode,
                                              hintText: 'Full name',
                                              prefixIcon: Icons.badge_outlined,
                                              keyboardType: TextInputType.name,
                                            ),
                                            SizedBox(
                                                height: isCompact ? 8 : 10),
                                          ],

                                          // Email Address Field
                                          _buildCustomInputField(
                                            controller: _emailController,
                                            focusNode: _emailFocusNode,
                                            hintText: _isLogin
                                                ? 'alex.morgan@gmail.com'
                                                : 'Email address',
                                            prefixIcon:
                                                Icons.mail_outline_rounded,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                          ),

                                          SizedBox(height: isCompact ? 8 : 10),

                                          // Password Field
                                          _buildCustomInputField(
                                            controller: _passwordController,
                                            focusNode: _passwordFocusNode,
                                            hintText: 'Password',
                                            prefixIcon:
                                                Icons.lock_outline_rounded,
                                            isPassword: true,
                                          ),
                                        ],
                                      ),

                                      // Middle Options: Forgot Password (Login) or Terms Checkbox (Sign Up)
                                      if (_isLogin) ...[
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: InkWell(
                                            onTap: () {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Password reset instructions sent to your email.'),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFF1F2A21),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: isCompact ? 10 : 14),
                                      ] else ...[
                                        SizedBox(height: isCompact ? 8 : 12),
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => setState(() =>
                                                  _agreedToLegal =
                                                      !_agreedToLegal),
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFBF8EA),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _agreedToLegal
                                                        ? const Color(
                                                            0xFF1F2A21)
                                                        : const Color(
                                                            0xFFD9D2B0),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: _agreedToLegal
                                                    ? const Icon(
                                                        Icons.check_rounded,
                                                        size: 14,
                                                        color:
                                                            Color(0xFF1F2A21),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Wrap(
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  const Text(
                                                    'I agree to ',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 13,
                                                      color: Color(0xFF1B211C),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () =>
                                                        _showLegalBottomSheet(
                                                            'Terms of Service',
                                                            LegalTexts
                                                                .termsAndConditions),
                                                    child: const Text(
                                                      'Terms',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF1B211C),
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: isCompact ? 10 : 14),
                                      ],

                                      // Primary Button: Sign in / Register
                                      SizedBox(
                                        width: double.infinity,
                                        height: isCompact ? 48 : 52,
                                        child: ElevatedButton(
                                          onPressed:
                                              _isLoading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1F2A21),
                                            foregroundColor:
                                                const Color(0xFFF6F1DC),
                                            elevation: 4,
                                            shadowColor:
                                                const Color(0x2E1F2A21),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(26),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Color(0xFFF6F1DC),
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Text(
                                                      _isLogin
                                                          ? 'Sign in'
                                                          : 'Register',
                                                      style: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFFF6F1DC),
                                                      ),
                                                    ),
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Container(
                                                        width: 30,
                                                        height: 30,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color:
                                                              Color(0xFFF6F1DC),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          size: 17,
                                                          color:
                                                              Color(0xFF1F2A21),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      SizedBox(height: isCompact ? 8 : 12),

                                      // Divider with "or"
                                      Row(
                                        children: const [
                                          Expanded(
                                            child: Divider(
                                                color: Color(0xFFD9D2B0),
                                                height: 1),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              'or',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 12,
                                                color: Color(0xFF6B6A52),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                                color: Color(0xFFD9D2B0),
                                                height: 1),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: isCompact ? 8 : 12),

                                      // Continue with Google Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: isCompact ? 46 : 48,
                                        child: OutlinedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _signInWithGoogle,
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFFBF8EA),
                                            side: const BorderSide(
                                                color: Color(0xFFD9D2B0),
                                                width: 1.0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              CustomPaint(
                                                size: Size(20, 20),
                                                painter: GoogleGLogoPainter(),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                'Continue with Google',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1B211C),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Footer Toggle Link (Anchored cleanly at bottom of page)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 4),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _isLogin
                                                ? 'New here?'
                                                : 'Have an account?',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              color: Color(0xFF6B6A52),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _isLogin = !_isLogin;
                                              });
                                            },
                                            child: Text(
                                              _isLogin ? 'Sign up' : 'Login',
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1F2A21),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Multi-Color Official Google 'G' Logo
class GoogleGLogoPainter extends CustomPainter {
  const GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;

    // Blue Path
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path();
    bluePath.moveTo(22.56 * scale, 12.25 * scale);
    bluePath.cubicTo(22.56 * scale, 11.47 * scale, 22.49 * scale, 10.72 * scale,
        22.36 * scale, 10.0 * scale);
    bluePath.lineTo(12.0 * scale, 10.0 * scale);
    bluePath.lineTo(12.0 * scale, 14.26 * scale);
    bluePath.lineTo(17.92 * scale, 14.26 * scale);
    bluePath.cubicTo(17.66 * scale, 15.63 * scale, 16.88 * scale, 16.79 * scale,
        15.71 * scale, 17.57 * scale);
    bluePath.lineTo(15.71 * scale, 20.34 * scale);
    bluePath.lineTo(19.28 * scale, 20.34 * scale);
    bluePath.cubicTo(21.36 * scale, 18.42 * scale, 22.56 * scale, 15.60 * scale,
        22.56 * scale, 12.25 * scale);
    canvas.drawPath(bluePath, bluePaint);

    // Green Path
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path();
    greenPath.moveTo(12.0 * scale, 23.0 * scale);
    greenPath.cubicTo(14.97 * scale, 23.0 * scale, 17.46 * scale, 22.02 * scale,
        19.28 * scale, 20.34 * scale);
    greenPath.lineTo(15.71 * scale, 17.57 * scale);
    greenPath.cubicTo(14.73 * scale, 18.23 * scale, 13.48 * scale,
        18.63 * scale, 12.0 * scale, 18.63 * scale);
    greenPath.cubicTo(9.14 * scale, 18.63 * scale, 6.71 * scale, 16.70 * scale,
        5.84 * scale, 14.10 * scale);
    greenPath.lineTo(2.18 * scale, 14.10 * scale);
    greenPath.lineTo(2.18 * scale, 16.94 * scale);
    greenPath.cubicTo(3.99 * scale, 20.53 * scale, 7.70 * scale, 23.0 * scale,
        12.0 * scale, 23.0 * scale);
    canvas.drawPath(greenPath, greenPaint);

    // Yellow Path
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path();
    yellowPath.moveTo(5.84 * scale, 14.10 * scale);
    yellowPath.cubicTo(5.62 * scale, 13.44 * scale, 5.49 * scale, 12.74 * scale,
        5.49 * scale, 12.0 * scale);
    yellowPath.cubicTo(5.49 * scale, 11.26 * scale, 5.62 * scale, 10.56 * scale,
        5.84 * scale, 9.90 * scale);
    yellowPath.lineTo(5.84 * scale, 7.06 * scale);
    yellowPath.lineTo(2.18 * scale, 7.06 * scale);
    yellowPath.cubicTo(1.43 * scale, 8.55 * scale, 1.0 * scale, 10.22 * scale,
        1.0 * scale, 12.0 * scale);
    yellowPath.cubicTo(1.0 * scale, 13.78 * scale, 1.43 * scale, 15.45 * scale,
        2.18 * scale, 16.94 * scale);
    yellowPath.lineTo(5.84 * scale, 14.10 * scale);
    canvas.drawPath(yellowPath, yellowPaint);

    // Red Path
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path();
    redPath.moveTo(12.0 * scale, 5.38 * scale);
    redPath.cubicTo(13.62 * scale, 5.38 * scale, 15.06 * scale, 5.94 * scale,
        16.21 * scale, 7.02 * scale);
    redPath.lineTo(19.36 * scale, 3.87 * scale);
    redPath.cubicTo(17.45 * scale, 2.09 * scale, 14.97 * scale, 1.0 * scale,
        12.0 * scale, 1.0 * scale);
    redPath.cubicTo(7.70 * scale, 1.0 * scale, 3.99 * scale, 3.47 * scale,
        2.18 * scale, 7.06 * scale);
    redPath.lineTo(5.84 * scale, 9.90 * scale);
    redPath.cubicTo(6.71 * scale, 7.30 * scale, 9.14 * scale, 5.38 * scale,
        12.0 * scale, 5.38 * scale);
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
