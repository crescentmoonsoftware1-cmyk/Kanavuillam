import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to AuthScreen after the slow zoom out animation and a brief pause
    // Zoom out: 4000ms, Hold: 1000ms -> Total 5000ms
    Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 900),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Logo slowly zooms out (from slightly larger) and fixes in the center
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 500, // The normal, fixed size
              fit: BoxFit.contain,
            )
                .animate()
                .fadeIn(
                  duration: 2000.ms, // Fade in slowly
                )
                .scale(
                  begin: const Offset(1.3, 1.3), // Start slightly larger
                  end: const Offset(1.0, 1.0), // End at normal size
                  duration: 4000.ms, // Zoom out slowly
                  curve: Curves.easeOutCubic, // Smooth deceleration
                ),
          ),
        ],
      ),
    );
  }
}
