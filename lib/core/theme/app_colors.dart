import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color background = Color(0xFF121212);
  static const Color surfaceCard = Color(0xFF1E1E2C);
  static const Color surfaceCardSecondary = Color(0xFF252538);
  static const Color surfaceElevated = Color(0xFF2A2A3E);
  static const Color primaryAccent = Color(0xFF6C5CE7); // Indigo Accent
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color secondaryAccent = Color(0xFF00CEC9); // Electric Cyan
  static const Color accentPink = Color(0xFFFD79A8);
  static const Color accentYellow = Color(0xFFFDCB6E);
  static const Color accentGreen = Color(0xFF00B894);
  static const Color accentOrange = Color(0xFFE17055);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0B2);
  static const Color textMuted = Color(0xFF6C6C80);

  // Functional / Status
  static const Color error = Color(0xFFFF7675);
  static const Color warning = Color(0xFFFAB1A0);
  static const Color success = Color(0xFF55EFC4);
  static const Color border = Color(0xFF33334A);
  static const Color borderLight = Color(0xFF454560);
  static const Color codeBackground = Color(0xFF161622);

  // Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF8E44AD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient voicePulseGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x336C5CE7), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
