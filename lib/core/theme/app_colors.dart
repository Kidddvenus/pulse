import 'package:flutter/material.dart';

class AppColors {
  // Light Theme Base
  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color glassBgLight = Color(0xBFFFFFFF); // ~75% white
  static const Color glassBorderLight = Color(0x80FFFFFF); // ~50% white
  static const Color inputBgLight = Color(0xE6FFFFFF); // ~90% white

  // Auroras - Light Mode
  static const Color aurora1Light = Color(0xFFFF9A9E);
  static const Color aurora2Light = Color(0xFFFECFEF);
  static const Color aurora3Light = Color(0xFFA1C4FD);
  static const Color aurora4Light = Color(0xFFC2E9FB);

  // Dark Theme Base - Deep Navy
  static const Color bgDark = Color(0xFF090E17);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color glassBgDark = Color(0x661E293B); // Translucent navy
  static const Color glassBorderDark = Color(0x1A00E5FF); // Subtle cyan border
  static const Color inputBgDark = Color(0xCC0F172A);

  // Auroras - Dark Mode
  static const Color aurora1Dark = Color(0xFF1E1B4B); // Deep purple/navy
  static const Color aurora2Dark = Color(0xFF064E3B); // Deep green
  static const Color aurora3Dark = Color(0xFF042F2E); // Deep teal
  static const Color aurora4Dark = Color(0xFF312E81); // Indigo

  // Shared Brand Colors
  static const Color primary = Color(0xFF00E5FF); // Cyan
  static const Color primaryHover = Color(0xFF00B8D4);
  static const Color success = Color(0xFF00E676); // Bright Green
  static const Color danger = Color(0xFFFF4081); // Pink/Red
  static const Color warning = Color(0xFFFFD740);

  // Gradients for Quick Actions
  static const Gradient blueGradient = LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF00E5FF)]);
  static const Gradient pinkGradient = LinearGradient(colors: [Color(0xFFED1E79), Color(0xFFC084FC)]);
  static const Gradient greenGradient = LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B8D4)]);
}
