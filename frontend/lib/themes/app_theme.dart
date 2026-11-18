import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AuraColors.lightBg,
      primaryColor: AuraColors.primaryGreen,
      colorScheme: const ColorScheme.light(
        primary: AuraColors.primaryGreen,
        secondary: AuraColors.accentCotto,
        surface: AuraColors.lightSurface,
        error: AuraColors.accentCotto,
      ),
      cardColor: AuraColors.lightCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AuraColors.textMain),
        bodyMedium: TextStyle(color: AuraColors.textMuted),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraColors.darkBg,
      primaryColor: AuraColors.primaryGreenDark,
      colorScheme: const ColorScheme.dark(
        primary: AuraColors.primaryGreenDark,
        secondary: AuraColors.accentCottoDark,
        surface: AuraColors.darkSurface,
        error: AuraColors.accentCottoDark,
      ),
      cardColor: AuraColors.darkCard,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AuraColors.textMainDark),
        bodyMedium: TextStyle(color: AuraColors.textMutedDark),
      ),
    );
  }
}