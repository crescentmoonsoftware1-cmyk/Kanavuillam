import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppConfigProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isTamil = false;

  bool get isDarkMode => _isDarkMode;
  bool get isTamil => _isTamil;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  void toggleLanguage() {
    _isTamil = !_isTamil;
    notifyListeners();
  }

  void setTamil(bool isTamil) {
    _isTamil = isTamil;
    notifyListeners();
  }

  // Dynamic Theme Colors
  Color get bgColor => _isDarkMode ? const Color(0xFF111317) : AppColors.background;
  Color get cardColor => _isDarkMode ? const Color(0xFF1D2128) : Colors.white;
  Color get primaryTextColor => _isDarkMode ? Colors.white : AppColors.primary;
  Color get secondaryTextColor => _isDarkMode ? const Color(0xFF9EACB9) : AppColors.textTertiary;
  Color get borderColor => _isDarkMode ? const Color(0xFF2C323D) : AppColors.border;
  Color get surfacePillColor => _isDarkMode ? const Color(0xFF282E38) : AppColors.surfaceTertiary;
  Color get splashColor => _isDarkMode 
      ? Colors.white.withValues(alpha: 0.08) 
      : AppColors.primary.withValues(alpha: 0.06);

  // Localization helper
  String tr(String en, String ta) => _isTamil ? ta : en;
}
