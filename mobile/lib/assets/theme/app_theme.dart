import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/assets/theme/text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryCyan,
      secondary: AppColors.primaryMagenta,
      surface: AppColors.black,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      error: AppColors.error,
      onError: AppColors.white,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.black,

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      elevation: 0,
      titleTextStyle: AppTextStyles.headlineMedium,
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    ),

    // Font Family
    fontFamily: AppTextStyles.fontFamily,

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonBackground,
        foregroundColor: AppColors.buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorder, width: 3),
        ),
        elevation: 5,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.buttonText,
        side: const BorderSide(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorder, width: 3),
        ),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.buttonText,
        backgroundColor: AppColors.buttonBackground,
        textStyle: AppTextStyles.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorder, width: 3),
        ),
      ),
    ),

    // Card Theme
    cardTheme: const CardThemeData(
      color: AppColors.darkGray,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: AppColors.darkGray,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.mediumGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.warning, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      hintStyle: AppTextStyles.bodyMedium,
      labelStyle: AppTextStyles.labelLarge,
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: AppColors.white, size: 24),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.black,
      selectedItemColor: AppColors.primaryCyan,
      unselectedItemColor: AppColors.mediumGray,
      type: BottomNavigationBarType.fixed,
    ),

    // Tab Bar Theme
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accentHighlight,
      unselectedLabelColor: AppColors.white,
      labelStyle: AppTextStyles.labelMedium,
      unselectedLabelStyle: AppTextStyles.labelMedium,
      indicatorColor: AppColors.accentHighlight,
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: AppColors.whiteDivider,
      thickness: 1,
    ),

    // Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.darkGray,
      titleTextStyle: AppTextStyles.headlineSmall,
      contentTextStyle: AppTextStyles.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.darkGray,
      elevation: 0,
      contentTextStyle: AppTextStyles.bodyMedium,
      actionTextColor: AppColors.primaryCyan,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
