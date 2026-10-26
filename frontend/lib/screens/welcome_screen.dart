import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import '../core/providers/app_config_provider.dart';
import 'auth_screen.dart';
import 'shell_screen.dart';

/// High-fidelity Welcome Screen based on stitch_kanavu_illam_home_screen/kanavu_illam_welcome_screen
/// Automatically detects existing logged-in session and seamlessly routes to ShellScreen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      if (email != null && email.trim().isNotEmpty) {
        // User is already logged in! Display the poetic brand splash for 1.2s, then enter Home
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          final userId = prefs.getString('user_id');
          final userName =
              prefs.getString('user_name') ?? email.split('@').first;
          final userPhone = prefs.getString('user_phone') ?? '';

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ShellScreen(
                userData: {
                  'id': userId,
                  'email': email,
                  'user_metadata': {
                    'name': userName,
                    'phone': userPhone,
                  },
                },
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('[WelcomeScreen] Auto-login check note: $e');
    }

    if (mounted) {
      setState(() => _isCheckingSession = false);
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
    final isTamil = config.isTamil;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B212F), Color(0xFF0F1319)],
                )
              : AppColors.pageGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              children: [
                // UPPER SECTION: Centered Logo + Poetic Tagline
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Centered Brand Logo
                          Image.asset(
                            'assets/images/logo.png',
                            width: 240,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 140,
                                height: 140,
                                decoration: const BoxDecoration(
                                  color: AppColors.badgeSlate,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.home_rounded,
                                  size: 64,
                                  color: AppColors.amberHighlight,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Poetic Serif Tagline (Cormorant Garamond italic)
                          Text(
                            isTamil
                                ? 'கனவு விதைத்த நிலத்தில்'
                                : 'Kanavu vidhaitha nilaththil',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 29,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? const Color(0xFFBDC7DB)
                                  : AppColors.steelBinder,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            isTamil ? 'இல்லம் எழும்' : 'Illam ezhum',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 29,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: AppColors.amberDeep,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // LOWER SECTION: Primary Amber CTA or Smooth Loading Indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _isCheckingSession
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.amberDefault,
                                ),
                              ),
                            ),
                          ),
                        )
                      : AppDecor.primaryPillButton(
                          label: config.tr('Get Started', 'தொடங்குக'),
                          icon: Icons.arrow_forward_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(isLogin: true),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
