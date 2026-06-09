import 'package:flutter/material.dart';

/// Centralized app color palette and theme configuration.
class AppColors {
  AppColors._();

  // Core
  static const Color primary = Color(0xFFD7F454);
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0x8A000000); // Colors.black54
  static const Color navBarBg = Colors.black;

  // Semantic / Status
  static const Color telegramBlue = Color(0xFF0088CC);
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.orange;
  static const Color success = Colors.green;

  // Auth (Dark Theme)
  static const Color authBackground = Color(0xFF0D0D0D);
  static const Color authSurface = Color(0xFF1A1A1A);
  static const Color authBorder = Color(0xFF2A2A2A);
  static const Color authBorderFocus = Color(0xFF3A3A3A);
}

/// Centralized shadow styles.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> button = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
