import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const PlanXApp());
}

class PlanXApp extends StatelessWidget {
  const PlanXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nirai – AI Floor Plan Analyzer',
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
      home: const AuthScreen(),
    );
  }
}
