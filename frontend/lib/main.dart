import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PlanXApp());
}

class PlanXApp extends StatelessWidget {
  const PlanXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanavu illam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C896),
          surface: Color(0xFF132237),
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFCDD6E0)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFCDD6E0)),
        ),
      ),
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: BouncingScrollWrapper.builder(context, child!),
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: const SplashScreen(),
    );
  }
}
