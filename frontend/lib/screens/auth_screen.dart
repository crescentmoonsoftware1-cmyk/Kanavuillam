import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/custom_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../services/api_service.dart';
import '../utils/legal_texts.dart';
import 'shell_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, this.isLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  late bool _isLogin;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _termsAccepted = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth(AppConfigProvider config) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_isLogin && !_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            config.tr(
              'Please accept Terms & Conditions to continue.',
              'தொடர விதிமுறைகளை ஒப்புக்கொள்ளவும்.',
            ),
          ),
          backgroundColor: AppColors.error,
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        final user = response['user'] as Map<String, dynamic>?;
        final email =
            (user?['email'] as String?) ?? _emailController.text.trim();
        final meta = user?['user_metadata'] as Map<String, dynamic>?;
        final name = (meta?['name'] as String?) ??
            (meta?['full_name'] as String?) ??
            _nameController.text.trim();
        final phone = (meta?['phone'] as String?) ?? '';

        await prefs.setString('user_email', email);
        if (name.isNotEmpty) await prefs.setString('user_name', name);
        if (phone.isNotEmpty) await prefs.setString('user_phone', phone);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ShellScreen(userData: response['user']),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response?['error'] ??
                    config.tr(
                      'Authentication failed. Please check credentials.',
                      'அங்கீகாரம் தோல்வியடைந்தது. விவரங்களைச் சரிபார்க்கவும்.',
                    ),
              ),
              backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
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

  Future<void> _signInWithGoogle(AppConfigProvider config) async {
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        final user = response['user'] as Map<String, dynamic>?;
        final email = (user?['email'] as String?) ?? googleUser.email;
        final meta = user?['user_metadata'] as Map<String, dynamic>?;
        final name = (meta?['name'] as String?) ??
            (meta?['full_name'] as String?) ??
            googleUser.displayName ??
            email.split('@').first;

        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ShellScreen(userData: response['user']),
            ),
          );
        }
      } else {
        throw Exception(
          response?['error'] ??
              config.tr(
                'Google Authentication failed on server',
                'Google உள்நுழைவு சர்வரில் தோல்வியடைந்தது',
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
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

  void _showTermsDialog(BuildContext context, AppConfigProvider config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: config.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: config.borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    config.tr(
                      'Terms & Conditions',
                      'விதிமுறைகள் மற்றும் நிபந்தனைகள்',
                    ),
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: config.primaryTextColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: config.secondaryTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: config.borderColor, height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 8, bottom: 16),
                  child: Text(
                    LegalTexts.termsAndConditions,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.6,
                      color: config.secondaryTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final isDark = config.isDarkMode;
    final bgColor = config.bgColor;
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  // Top Brand Emblem Section
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(52, 52),
                                painter: _SmallLogoPainter(
                                  color: primaryTextColor,
                                ),
                              ),
                              Positioned(
                                bottom: 7.5,
                                child: Text(
                                  'KI',
                                  style: GoogleFonts.syne(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kanavu Illam',
                          style: GoogleFonts.syne(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: primaryTextColor,
                            letterSpacing: -0.24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Elevated Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 20.0),
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: config.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Title
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Text(
                            config.tr(
                              _isLogin ? 'Welcome back' : 'Create account',
                              _isLogin ? 'மீண்டும் வருக' : 'கணக்கு தொடங்குங்கள்',
                            ),
                            style: GoogleFonts.syne(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                              letterSpacing: -0.24,
                              height: 1.1,
                            ),
                          ),
                        ),

                        // Form Inputs
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Full Name (Only on Sign Up)
                              if (!_isLogin) ...[
                                CustomTextField(
                                  controller: _nameController,
                                  hintText: config.tr('Full Name', 'முழு பெயர்'),
                                  prefixIcon: Icons.badge_outlined,
                                  keyboardType: TextInputType.name,
                                  textInputAction: TextInputAction.next,
                                  fillColor: isDark ? const Color(0xFF1E232B) : Colors.white,
                                  borderColor: isDark ? const Color(0xFF2C323D) : const Color(0xFFE2E2E2),
                                  textColor: primaryTextColor,
                                  hintColor: secondaryTextColor,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return config.tr(
                                        'Please enter your name',
                                        'உங்கள் பெயரை உள்ளிடவும்',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Email or Phone
                              CustomTextField(
                                controller: _emailController,
                                hintText: config.tr(
                                  _isLogin ? 'Email or Phone' : 'Email address',
                                  _isLogin ? 'மின்னஞ்சல் அல்லது தொலைபேசி' : 'மின்னஞ்சல் முகவரி',
                                ),
                                prefixIcon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                fillColor: isDark ? const Color(0xFF1E232B) : Colors.white,
                                borderColor: isDark ? const Color(0xFF2C323D) : const Color(0xFFE2E2E2),
                                textColor: primaryTextColor,
                                hintColor: secondaryTextColor,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return config.tr(
                                      _isLogin
                                          ? 'Please enter email or phone'
                                          : 'Please enter email address',
                                      _isLogin
                                          ? 'மின்னஞ்சல் அல்லது தொலைபேசியை உள்ளிடவும்'
                                          : 'மின்னஞ்சல் முகவரியை உள்ளிடவும்',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Password
                              CustomTextField(
                                controller: _passwordController,
                                hintText: config.tr('Password', 'கடவுச்சொல்'),
                                prefixIcon: Icons.lock_outline,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                fillColor: isDark ? const Color(0xFF1E232B) : Colors.white,
                                borderColor: isDark ? const Color(0xFF2C323D) : const Color(0xFFE2E2E2),
                                textColor: primaryTextColor,
                                hintColor: secondaryTextColor,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return config.tr(
                                      'Please enter password',
                                      'கடவுச்சொல்லை உள்ளிடவும்',
                                    );
                                  }
                                  if (val.length < 6) {
                                    return config.tr(
                                      'Password must be at least 6 characters',
                                      'குறைந்தது 6 எழுத்துக்கள் இருக்க வேண்டும்',
                                    );
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        // Forgot Password Link (Sign in only)
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 8.0, bottom: 4.0),
                              child: InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        config.tr(
                                          'Password reset instructions sent to your email.',
                                          'கடவுச்சொல் மீட்டமைப்பு வழிமுறைகள் உங்கள் மின்னஞ்சலுக்கு அனுப்பப்பட்டன.',
                                        ),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Text(
                                  config.tr(
                                    'Forgot Password?',
                                    'கடவுச்சொல் மறந்துவிட்டதா?',
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Terms & Conditions Checkbox (Sign Up only)
                        if (!_isLogin)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _termsAccepted = !_termsAccepted;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _termsAccepted
                                          ? (isDark
                                              ? Colors.white
                                              : AppColors.primary)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _termsAccepted
                                            ? (isDark
                                                ? Colors.white
                                                : AppColors.primary)
                                            : config.borderColor,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: _termsAccepted
                                        ? Icon(
                                            Icons.check,
                                            size: 15,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  config.tr('I agree to ', 'ஒப்புக்கொள்கிறேன்: '),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _showTermsDialog(context, config),
                                  child: Text(
                                    config.tr('Terms', 'விதிமுறைகள்'),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Primary Action Button (Sign in / Register)
                        PrimaryButton(
                          text: config.tr(
                            _isLogin ? 'Sign in' : 'Register',
                            _isLogin ? 'உள்நுழைக' : 'பதிவு செய்',
                          ),
                          isLoading: _isLoading,
                          onTap: () => _handleAuth(config),
                        ),

                        // Divider with "or"
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Divider(
                                color: config.borderColor,
                                thickness: 1,
                                height: 1,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                ),
                                color: cardColor,
                                child: Text(
                                  config.tr('or', 'அல்லது'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Continue with Google Button
                        Center(
                          child: InkWell(
                            onTap: () => _signInWithGoogle(config),
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1D2128) : Colors.white,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: config.borderColor, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Image.asset(
                                      'assets/images/search.png',
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const CustomPaint(
                                        painter: GoogleGLogoPainter(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    config.tr(
                                      'Continue with Google',
                                      'Google மூலம் தொடரவும்',
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Switcher: "New here? Sign up" or "Already have an account? Sign in"
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          config.tr(
                            _isLogin ? 'New here? ' : 'Already have an account? ',
                            _isLogin ? 'புதியவரா? ' : 'ஏற்கனவே கணக்கு உள்ளதா? ',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _formKey.currentState?.reset();
                            });
                          },
                          child: Text(
                            config.tr(
                              _isLogin ? 'Sign up' : 'Sign in',
                              _isLogin ? 'பதிவு செய்' : 'உள்நுழைக',
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}


// Logo Painter for Header Emblem
class _SmallLogoPainter extends CustomPainter {
  final Color color;
  _SmallLogoPainter({this.color = AppColors.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    final strokeW = 3.2 * s;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(6 * s, 20 * s);
    path.lineTo(24 * s, 5 * s);
    path.lineTo(42 * s, 20 * s);
    path.lineTo(42 * s, 43 * s);
    path.lineTo(6 * s, 43 * s);
    path.close();
    canvas.drawPath(path, paint);

    final doorRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(16.5 * s, 24 * s, 15 * s, 19 * s),
      topLeft: Radius.circular(2.5 * s),
      topRight: Radius.circular(2.5 * s),
    );
    canvas.drawRRect(doorRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SmallLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Official Multi-Color Google G Logo
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

/// Standalone route alias for Login Screen
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const AuthScreen(isLogin: true);
}

/// Standalone route alias for Create Account Screen
class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) => const AuthScreen(isLogin: false);
}
