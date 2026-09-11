import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StateNotifier managing the active application ThemeMode (light, dark, system)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String prefsKey = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(prefsKey);
      if (savedMode != null) {
        switch (savedMode) {
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'light':
            state = ThemeMode.light;
            break;
          case 'system':
            state = ThemeMode.system;
            break;
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {}
  }
}

/// Provider for app-wide ThemeMode
final themeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
