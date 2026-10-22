import 'package:flutter/material.dart';

/// Colours from docs/04-design-guidelines.md.
class AppColors {
  static const navy = Color(0xFF0E2A47);
  static const navyLight = Color(0xFF143A62);
  static const navyDeep = Color(0xFF123256);
  static const navyChip = Color(0xFF183B63);
  static const onNavyMuted = Color(0xFFB9CCE0);
  static const ringTrack = Color(0xFF2A5282);
  static const ringFill = Color(0xFF6CB4F5);

  static const primary = Color(0xFF0B5CAD);
  static const background = Color(0xFFF4F6F8);
  static const surface = Colors.white;
  static const ink = Color(0xFF16212C);
  static const muted = Color(0xFF4A5866);
  static const line = Color(0xFFD5DBE1);
  static const lineSoft = Color(0xFFE3E8ED);
  static const thumbBackground = Color(0xFFEAF0F6);
  static const success = Color(0xFF2E9E6B);

  static const pdf = Color(0xFFB3261E);
  static const docx = Color(0xFF1F4E9C);
  static const image = Color(0xFF0F6B63);
  static const otherFile = Color(0xFF4A5866);

  static const waitingBackground = Color(0xFFFFF0D1);
  static const waitingText = Color(0xFF6B4200);
  static const printedBackground = Color(0xFFE3F1EA);
  static const printedText = Color(0xFF14573A);
  static const failedBackground = Color(0xFFFBE3E3);
  static const failedText = Color(0xFF7A1F1F);
}

class AppTheme {
  /// Width from which screens switch to the printer-panel layout.
  static const double panelBreakpoint = 760;

  static ThemeData build({String? fontFamily}) => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        snackBarTheme:
            const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF8A97A4)),
          ),
        ),
      );

  static final ThemeData light = build();

  // Kept for code that referenced the old name.
  static ThemeData get lightTheme => light;
}
