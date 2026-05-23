import 'package:flutter/material.dart';

/// Dunkles Farbschema – passend zur Web-/HA-Variante (Lila + Gold-Akzent).
class AppColors {
  static const bg = Color(0xFF0D0D1A);
  static const card = Color(0xFF1A1A2E);
  static const cardHover = Color(0xFF22223F);
  static const input = Color(0xFF12121F);
  static const primary = Color(0xFF7C6FF7);
  static const primaryHover = Color(0xFF9A90FF);
  static const accent = Color(0xFFFFD700); // Karaoke-Cursor
  static const success = Color(0xFF4CAF8A);
  static const error = Color(0xFFF44C6F);
  static const text = Color(0xFFF0F0F5);
  static const textSecondary = Color(0xFF8888AA);
  static const border = Color(0x14FFFFFF);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.card,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}
