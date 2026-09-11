import 'package:flutter/material.dart';

/// Color palette for Evim reflecting a warm Mediterranean and Turkish aesthetic
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFF0F4C81); // Classic Bosphorus Navy
  static const Color primaryLight = Color(0xFFBCE3F3);
  static const Color primaryDark = Color(0xFF092E50);

  // Secondary & Accents
  static const Color terracotta = Color(0xFFD9534F); // Anatolian Terracotta / Tile Red
  static const Color turquoise = Color(0xFF00A896); // Aegean Turquoise
  static const Color warmAmber = Color(0xFFF39C12); // Golden Honey / Çay Amber
  static const Color oliveGreen = Color(0xFF2E7D32); // Olive Green / Success
  static const Color error = terracotta;
  static const Color accent = turquoise;
  static const Color success = oliveGreen;

  // Neutral tones
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Dark mode neutrals
  static const Color backgroundDark = Color(0xFF121820);
  static const Color surfaceDark = Color(0xFF1E2632);
  static const Color borderDark = Color(0xFF2D3748);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Turkish Supermarket Brand Colors for Tagging
  static const Color bim = Color(0xFF004B93);
  static const Color a101 = Color(0xFF00A0E2);
  static const Color sok = Color(0xFFFED100);
  static const Color sokText = Color(0xFF1A1A1A);
  static const Color migros = Color(0xFFFF5C00);
  static const Color bazaar = Color(0xFF8E44AD); // Local Pazaryeri
}
