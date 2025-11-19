import 'package:flutter/material.dart';
import 'package:mobile/assets/theme/color_palette.dart';
import 'package:mobile/assets/theme/text_styles.dart';

class AppTheme {
  //Dark Theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryCyan,
      secondary: AppColors.primaryMagenta,
      surface: AppColors.black,
      onPrimary: AppColors.lightGray,
      onSecondary: AppColors.lightGray,
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
    ).copyWith(
      titleTextStyle: AppTextStyles.headlineMedium.copyWith(
        color: AppColors.textDark,
      ),
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
    ).apply(bodyColor: AppColors.white, displayColor: AppColors.textDark),

    // Font Family
    fontFamily: AppTextStyles.fontFamily,

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonBackgroundDark,
        foregroundColor: AppColors.buttonTextDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderDark, width: 3),
        ),
        elevation: 5,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.buttonTextDark,
        side: const BorderSide(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderDark, width: 3),
        ),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.buttonTextDark,
        backgroundColor: AppColors.buttonBackgroundDark,
        textStyle: AppTextStyles.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderDark, width: 3),
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

    // Text Selection Theme
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textDark,
      selectionColor: AppColors.accentHighlightDark,
      selectionHandleColor: AppColors.accentHighlightDark,
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
      labelColor: AppColors.accentHighlightDark,
      unselectedLabelColor: AppColors.white,
      labelStyle: AppTextStyles.labelMedium,
      unselectedLabelStyle: AppTextStyles.labelMedium,
      indicatorColor: AppColors.accentHighlightDark,
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: AppColors.whiteDivider,
      thickness: 1,
    ),

    // Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.darkGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ).copyWith(
      titleTextStyle: AppTextStyles.headlineSmall.copyWith(
        color: AppColors.textDark,
      ),
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textDark,
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

  //Light Theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryCyan,
      secondary: AppColors.primaryMagenta,
      surface: AppColors.lightGray,
      onPrimary: AppColors.black,
      onSecondary: AppColors.black,
      error: AppColors.error,
      onError: AppColors.white,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.lightGray,

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightGray,
      foregroundColor: AppColors.black,
      elevation: 0,
      titleTextStyle: AppTextStyles.headlineMedium,
    ).copyWith(
      titleTextStyle: AppTextStyles.headlineMedium.copyWith(
        color: AppColors.textLight,
      ),
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
    ).apply(bodyColor: AppColors.textLight, displayColor: AppColors.textLight),

    // Font Family
    fontFamily: AppTextStyles.fontFamily,

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonBackgroundLight,
        foregroundColor: AppColors.buttonTextLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderLight, width: 2),
        ),
        elevation: 5,
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // swap for outlined/text buttons as well
        foregroundColor: AppColors.buttonTextLight,
        side: const BorderSide(color: AppColors.mediumGray),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderLight, width: 3),
        ),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.buttonTextLight,
        backgroundColor: AppColors.buttonBackgroundLight,
        textStyle: AppTextStyles.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: AppColors.buttonBorderLight, width: 3),
        ),
      ),
    ),

    // Card Theme
    cardTheme: const CardThemeData(
      color: AppColors.lightGray,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: AppColors.lightGray,
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
        borderSide: BorderSide(color: AppColors.accentHighlightLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      hintStyle: AppTextStyles.bodyMedium,
      labelStyle: AppTextStyles.labelLarge,
    ),

    // Text Selection Theme
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textLight,
      selectionColor: AppColors.accentHighlightLight,
      selectionHandleColor: AppColors.accentHighlightLight,
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: AppColors.black, size: 24),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightGray,
      selectedItemColor: AppColors.primaryCyan,
      unselectedItemColor: AppColors.mediumGray,
      type: BottomNavigationBarType.fixed,
    ),

    // Tab Bar Theme
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accentHighlightLight,
      unselectedLabelColor: AppColors.white,
      labelStyle: AppTextStyles.labelMedium,
      unselectedLabelStyle: AppTextStyles.labelMedium,
      indicatorColor: AppColors.accentHighlightLight,
    ),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: AppColors.mediumGray,
      thickness: 1,
    ),

    // Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.lightGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ).copyWith(
      titleTextStyle: AppTextStyles.headlineSmall.copyWith(
        color: AppColors.textLight,
      ),
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textLight,
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.lightGray,
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
