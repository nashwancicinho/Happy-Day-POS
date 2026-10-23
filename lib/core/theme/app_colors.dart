import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static Color primary = const Color(0xFFFF9800);
  static bool isDark = false;

  static Color get background => isDark ? const Color(0xFF111827) : const Color(0xFFF5F5F5);

  static Color get surface => isDark ? const Color(0xFF1F2937) : Colors.white;

  static const Color success = Color(0xFF4CAF50);

  static const Color danger = Color(0xFFE53935);

  static const Color warning = Color(0xFFFFC107);

  static const Color info = Color(0xFF2196F3);

  static Color get text => isDark ? Colors.white : const Color(0xFF111827);

  static Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static Color get border => isDark ? const Color(0xFF374151) : const Color(0xFFE0E0E0);
}