import 'package:flutter/material.dart';

/// Color palette for Evim reflecting a modern, clean Mediterranean and Turkish aesthetic
class AppColors {
  AppColors._();

  // Primary brand colors (#82C8E5 Sky/Ice Blue)
  static const Color primary = Color(0xFF82C8E5);
  static const Color primaryLight = Color(0xFFBCE3F3);
  static const Color primaryDark = Color(0xFF5BA4C5);
  static const Color onPrimary = Color(0xFF0F172A); // Dark text/icons for WCAG readability on #82C8E5

  // Secondary & Accents
  static const Color terracotta = Color(0xFFD9534F); // Anatolian Terracotta / Tile Red
  static const Color turquoise = Color(0xFF00A896); // Aegean Turquoise
  static const Color warmAmber = Color(0xFFF39C12); // Golden Honey / Çay Amber
  static const Color oliveGreen = Color(0xFF2E7D32); // Olive Green / Success
  static const Color slateNavy = Color(0xFF1E293B); // Slate Navy
  static const Color error = terracotta;
  static const Color accent = turquoise;
  static const Color success = oliveGreen;

  // Background & Surface Constants (Clean slate-tinted off-white modern palette)
  static const Color background = Color(0xFFF8FAFC); // Clean slate-tinted off-white
  static const Color surface = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color cardBackground = Colors.white;

  // Typography & Borders for Light Background
  static const Color textPrimary = Color(0xFF0F172A); // Deep Navy/Charcoal for crisp contrast
  static const Color textSecondary = Color(0xFF64748B); // Slate subtext
  static const Color border = Color(0xFFE2E8F0); // Light slate borders / dividers
  static const Color divider = Color(0xFFE2E8F0);

  // Backward-compatibility aliases
  static const Color backgroundLight = background;
  static const Color surfaceLight = surface;
  static const Color borderLight = border;
  static const Color textPrimaryLight = textPrimary;
  static const Color textSecondaryLight = textSecondary;

  // Dark mode neutrals
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Turkish Supermarket Brand Colors for Tagging
  static const Color bim = Color(0xFF004B93);
  static const Color a101 = Color(0xFF00A0E2);
  static const Color sok = Color(0xFFFED100);
  static const Color sokText = Color(0xFF1A1A1A);
  static const Color migros = Color(0xFFFF5C00);
  static const Color bazaar = Color(0xFF8E44AD); // Local Pazaryeri
}
