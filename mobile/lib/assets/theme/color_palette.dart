import 'package:flutter/material.dart';

class AppColors {
  // Main Theme Colors
  static const Color brass = Color(0xFFD9A760);
  static const Color accent = Color(0xFF565656);

  //Buttons colors
  static const Color buttonBackground = Color(0xFF2c3e50); // Leather Brown
  static const Color buttonBorder = Color(0xFF202020); // Burnished Gold
  static const Color buttonText = Color(0xFFC0C0C0); // Button text color

  // Neutral Colors
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF1A1A1A);
  static const Color mediumGray = Color(0xFF808080);
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color white = Color(0xFFFFFFFF);

  // Alpha Variants (commonly used opacities)
  static const Color whiteDivider = Color.fromARGB(25, 255, 255, 255);
  static const Color whiteMedium = Color.fromARGB(128, 255, 255, 255);
  static const Color whiteHigh = Color.fromARGB(230, 255, 255, 255);

  // Additional alpha variants found in codebase
  static const Color whiteAlpha128 = Color.fromARGB(128, 255, 255, 255);
  static const Color whiteAlpha77 = Color.fromARGB(77, 255, 255, 255);
  static const Color whiteAlpha26 = Color.fromARGB(26, 255, 255, 255);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Theme Accent Colors
  static const Color accentHighlight = Color(0xFFFF9800);

  // Brand Colors
  static const Color primaryCyan = Color(0xFF62FBF2);
  static const Color primaryMagenta = Color(0xFFF158FF);
  static const Color secondaryPurple = Color(0xFF845EC2);
  static const Color secondaryPink = Color(0xFFD65DB1);
}
