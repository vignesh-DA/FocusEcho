import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0A0E1A);
  static const surface = Color(0xFF111827);
  static const card = Color(0xFF1A2235);
  static const accentBlue = Color(0xFF00C2FF);
  static const accentGreen = Color(0xFF00FF88);
  static const accentRed = Color(0xFFFF4444);
  static const accentYellow = Color(0xFFFFD700);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B9CB6);
  static const border = Color(0xFF1E2D45);
}

class AppTextStyles {
  static TextStyle displayLarge = GoogleFonts.spaceGrotesk(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w700,
    fontSize: 32,
  );
  static TextStyle displayMedium = GoogleFonts.spaceGrotesk(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 24,
  );
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );
  static TextStyle bodyMedium = GoogleFonts.dmSans(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );
  static TextStyle bodySmall = GoogleFonts.dmSans(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
    fontSize: 12,
  );
}

class AppDecorations {
  static BoxDecoration glassmorphismCard() {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
      backgroundBlendMode: BlendMode.srcOver,
    );
  }

  static BoxDecoration neonCard({Color glowColor = AppColors.accentBlue}) {
    return glassmorphismCard().copyWith(
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.3),
          blurRadius: 0,
          spreadRadius: 0,
        ),
        const BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
      ],
    );
  }

  static BoxDecoration accentButton(Color color) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.85), color],
      ),
    );
  }
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        secondary: AppColors.accentGreen,
        error: AppColors.accentRed,
        surface: AppColors.surface,
      ),
      cardColor: AppColors.card,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
      ),
    );
  }
}

BackdropFilter subtleBlur({required Widget child}) {
  return BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: child);
}
