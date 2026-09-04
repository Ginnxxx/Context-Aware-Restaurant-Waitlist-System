import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF17211B);
  static const forest = Color(0xFF173F35);
  static const sage = Color(0xFFBBD4C6);
  static const mint = Color(0xFFEAF4EE);
  static const cream = Color(0xFFF8F5ED);
  static const coral = Color(0xFFFF7359);
  static const amber = Color(0xFFF4B942);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFF68736D);
  static const line = Color(0xFFDDE5DF);
}

abstract final class QueueLessTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.forest,
      onPrimary: AppColors.white,
      secondary: AppColors.coral,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      error: Color(0xFFB3261E),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Arial',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 54,
          height: .98,
          fontWeight: FontWeight.w800,
          letterSpacing: -2.4,
          color: AppColors.ink,
        ),
        displaySmall: const TextStyle(
          fontSize: 36,
          height: 1.02,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: AppColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontSize: 26,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
          color: AppColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: AppColors.muted,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.muted,
        ),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
