import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _videoEnded = false;
  bool _fadeOutVideo = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset('assets/video1.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setVolume(0.0); // Mute for web autoplay
        _videoController.play().catchError((error) {
          debugPrint("Video play error: \$error");
          // If video fails to play, skip to end
          setState(() {
            _videoEnded = true;
            _fadeOutVideo = true;
          });
        });
      }).catchError((error) {
        debugPrint("Video init error: \$error");
        setState(() {
          _videoEnded = true;
          _fadeOutVideo = true;
        });
      });

    _videoController.addListener(() {
      if (_videoController.value.isInitialized &&
          _videoController.value.position >= _videoController.value.duration &&
          !_videoController.value.isPlaying &&
          !_videoEnded) {
        setState(() {
          _videoEnded = true;
        });

        // Delay the video fade out so the logo appears on top of the house first
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _fadeOutVideo = true;
            });
          }
        });

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
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Video Player with smooth fade out to white background
          if (_videoController.value.isInitialized)
            AnimatedOpacity(
              opacity: _fadeOutVideo ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),

          if (_videoEnded)
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
