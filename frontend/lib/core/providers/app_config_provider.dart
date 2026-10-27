import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class AppConfigProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isTamil = false;
  bool _isInitialized = false;

  AppConfigProvider() {
    _loadPreferences();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isTamil => _isTamil;
  bool get isInitialized => _isInitialized;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('app_is_dark_mode') ?? false;
      _isTamil = prefs.getBool('app_is_tamil') ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading AppConfigProvider prefs: $e');
    }
  }

  void toggleTheme() {
    setTheme(!_isDarkMode);
  }

  void setTheme(bool isDark) {
    if (_isDarkMode == isDark && _isInitialized) return;
    _isDarkMode = isDark;
    notifyListeners();
    _saveThemePref(isDark);
  }

  Future<void> _saveThemePref(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_is_dark_mode', isDark);
    } catch (_) {}
  }

  void toggleLanguage() {
    setTamil(!_isTamil);
  }

  void setTamil(bool isTamil) {
    if (_isTamil == isTamil && _isInitialized) return;
    _isTamil = isTamil;
    notifyListeners();
    _saveLangPref(isTamil);
  }

  Future<void> _saveLangPref(bool isTamil) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_is_tamil', isTamil);
    } catch (_) {}
  }

  // Dynamic Theme Colors
  Color get bgColor => _isDarkMode ? const Color(0xFF11141A) : AppColors.background;
  Color get cardColor => _isDarkMode ? const Color(0xFF1A202C) : AppColors.card;
  Color get elevatedCardColor => _isDarkMode ? const Color(0xFF222938) : const Color(0xFFF1F5F9);
  Color get primaryTextColor => _isDarkMode ? Colors.white : AppColors.deepInk;
  Color get secondaryTextColor => _isDarkMode ? const Color(0xFF94A3B8) : AppColors.quietGrey;
  Color get readingTextColor => _isDarkMode ? const Color(0xFFCBD5E1) : AppColors.readingSlate;
  Color get borderColor => _isDarkMode ? const Color(0xFF2D3748) : AppColors.cardBorder;
  Color get surfacePillColor => _isDarkMode ? const Color(0xFF242C3D) : AppColors.innerPanel;
  Color get splashColor => _isDarkMode 
      ? Colors.white.withValues(alpha: 0.08) 
      : AppColors.amber.withValues(alpha: 0.08);

  LinearGradient get canvasGradient => _isDarkMode
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141923), Color(0xFF0C0E14)],
        )
      : AppColors.canvasGradient;

  // Localization helper
  String tr(String en, String ta) => _isTamil ? ta : en;
}
