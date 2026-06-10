import 'package:flutter/material.dart';

/// Central color palette matching the React/Tailwind design.
class AppColors {
  AppColors._();

  // Green shades
  static const green50  = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green400 = Color(0xFF4ADE80);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);

  // Dark-mode surfaces (gray shades)
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  // Text / icon colours
  static const textDarkPrimary   = Color(0xFFFFFFFF);
  static const textDarkSecondary = Color(0xFF9CA3AF);
  static const textLightPrimary  = Color(0xFF111827);
  static const textLightSecondary = Color(0xFF6B7280);

  // Border colours
  static const borderDark  = Color(0xFF374151);
  static const borderLight = Color(0xFFE5E7EB);

  // Tier colours (for player avatars / badges)
  static const bronzeStart   = Color(0xFFB45309);
  static const bronzeEnd     = Color(0xFFF59E0B);
  static const silverStart   = Color(0xFF94A3B8);
  static const silverEnd     = Color(0xFFCBD5E1);
  static const goldStart     = Color(0xFFEAB308);
  static const goldEnd       = Color(0xFFF59E0B);
  static const platinumStart = Color(0xFF22D3EE);
  static const platinumEnd   = Color(0xFF2DD4BF);
  static const diamondStart  = Color(0xFF8B5CF6);
  static const diamondEnd    = Color(0xFFA78BFA);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green500,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Roboto',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green500,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.gray800,
    fontFamily: 'Roboto',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
