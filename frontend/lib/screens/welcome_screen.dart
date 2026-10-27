import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import '../core/providers/app_config_provider.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'shell_screen.dart';

/// High-fidelity Welcome Screen based on stitch_kanavu_illam_home_screen/kanavu_illam_welcome_screen
/// Features smooth logo zoom & fade animation, followed by animated kural tagline.
/// Automatically detects existing logged-in session and seamlessly routes to ShellScreen,
/// or presents the Get Started action for new users.
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
    // Silently wake up backend from cold sleep early
    ApiService.warmupBackend();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      // Smooth, full entrance animation (3 seconds) so user can see logo & kural tagline
      await Future.delayed(const Duration(seconds: 3));

      if (email != null && email.trim().isNotEmpty) {
        if (mounted) {
          final userId = prefs.getString('user_id');
          final userName =
              prefs.getString('user_name') ?? email.split('@').first;
          final userPhone = prefs.getString('user_phone') ?? '';

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ShellScreen(
                userData: {
                  'id': userId,
                  'email': email,
                  'user_metadata': {
                    'name': userName,
                    'phone': userPhone,
                  },
                },
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
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
                // UPPER SECTION: Centered Animated Logo + Animated Poetic Kural Tagline
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 1. Centered Brand Logo with smooth Zoom & Fade animation
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
                          )
                              .animate()
                              .fadeIn(
                                duration: 1000.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .scale(
                                begin: const Offset(0.72, 0.72),
                                end: const Offset(1.0, 1.0),
                                duration: 1200.ms,
                                curve: Curves.easeOutBack,
                              ),

                          const SizedBox(height: 24),

                          // 2. Poetic Kural Tagline with smooth entrance animation
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                          )
                              .animate()
                              .fadeIn(
                                delay: 1000.ms,
                                duration: 1000.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .slideY(
                                begin: 0.35,
                                end: 0.0,
                                delay: 1000.ms,
                                duration: 1000.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),

                // LOWER SECTION: Primary Amber CTA for new users or subtle placeholder while checking
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 400),
                    crossFadeState: _isCheckingSession
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: const SizedBox(
                      height: 52,
                      width: double.infinity,
                    ),
                    secondChild: AppDecor.primaryPillButton(
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
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.25, end: 0.0),
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
