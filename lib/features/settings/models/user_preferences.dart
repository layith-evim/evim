import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences model for notification toggles, theme, and language
class UserPreferences {
  final bool notifyBills;
  final bool notifyResidency;
  final bool notifyPantry;
  final String language; // 'ar', 'tr', 'en'
  final String themeMode; // 'light', 'dark', 'system'

  const UserPreferences({
    this.notifyBills = true,
    this.notifyResidency = true,
    this.notifyPantry = true,
    this.language = 'ar',
    this.themeMode = 'light',
  });

  static const String prefsKey = 'evim_user_preferences';

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      notifyBills: json['notify_bills'] as bool? ?? true,
      notifyResidency: json['notify_residency'] as bool? ?? true,
      notifyPantry: json['notify_pantry'] as bool? ?? true,
      language: json['language'] as String? ?? 'ar',
      themeMode: json['theme_mode'] as String? ?? 'light',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notify_bills': notifyBills,
      'notify_residency': notifyResidency,
      'notify_pantry': notifyPantry,
      'language': language,
      'theme_mode': themeMode,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  UserPreferences copyWith({
    bool? notifyBills,
    bool? notifyResidency,
    bool? notifyPantry,
    String? language,
    String? themeMode,
  }) {
    return UserPreferences(
      notifyBills: notifyBills ?? this.notifyBills,
      notifyResidency: notifyResidency ?? this.notifyResidency,
      notifyPantry: notifyPantry ?? this.notifyPantry,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Loads stored preferences from SharedPreferences
  static Future<UserPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(prefsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        return UserPreferences.fromJson(map);
      }
    } catch (_) {
      // Fallback to default preferences
    }
    return const UserPreferences();
  }

  /// Saves current preferences to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(toMap());
      await prefs.setString(prefsKey, jsonString);
    } catch (_) {}
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          runtimeType == other.runtimeType &&
          notifyBills == other.notifyBills &&
          notifyResidency == other.notifyResidency &&
          notifyPantry == other.notifyPantry &&
          language == other.language &&
          themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(
        notifyBills,
        notifyResidency,
        notifyPantry,
        language,
        themeMode,
      );
}
