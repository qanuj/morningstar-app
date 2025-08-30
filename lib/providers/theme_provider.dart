import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  late SharedPreferences _prefs;

  AppThemeMode get themeMode => _themeMode;

  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get themeModeText {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  IconData get themeModeIcon {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getString('theme_mode') ?? 'system';
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == savedTheme,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  Future<void> cycleThemeMode() async {
    final currentIndex = AppThemeMode.values.indexOf(_themeMode);
    final nextIndex = (currentIndex + 1) % AppThemeMode.values.length;
    await setThemeMode(AppThemeMode.values[nextIndex]);
  }
}