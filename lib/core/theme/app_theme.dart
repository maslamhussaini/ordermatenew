// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ordermate/core/theme/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme(String? fontFamily, [String? themeColor]) {
    final primary = _getThemeColor(themeColor);

    // Skin-specific overrides
    Color? surfaceSeed;
    VisualDensity visualDensity = VisualDensity.standard;
    double borderRadius = 8.0;

    if (themeColor == 'ledger') {
      surfaceSeed = const Color(0xFFF8FAFC);
    } else if (themeColor == 'mint') {
      surfaceSeed = const Color(0xFFE0F2F1); // Soft mint background
    } else if (themeColor == 'slate') {
      visualDensity = VisualDensity.compact;
      borderRadius = 0.0;
    }

    var baseTheme = ThemeData(
      useMaterial3: true,
      visualDensity: visualDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: surfaceSeed, // Will use default if null, or skin override
      ),
      scaffoldBackgroundColor: themeColor == 'mint'
          ? const Color(0xFFE0F2F1)
          : (surfaceSeed ?? AppColors.background),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: themeColor == 'mint' ? Colors.transparent : primary,
        foregroundColor: themeColor == 'mint' ? primary : Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius == 0 ? 0 : 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        filled: true,
        fillColor: themeColor == 'slate' ? Colors.grey[200] : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );

    return _applyFont(baseTheme, fontFamily);
  }

  static ThemeData darkTheme(String? fontFamily, [String? themeColor]) {
    final primary = _getThemeColor(themeColor);

    // Skin-specific overrides for Dark Mode
    Color? scaffoldOverride;
    Color? cardOverride;
    VisualDensity visualDensity = VisualDensity.standard;
    double borderRadius = 8.0;

    if (themeColor == 'audit') {
      // Midnight Audit - Pure Black
      scaffoldOverride = Colors.black;
      cardOverride = const Color(0xFF1E1E1E);
    } else if (themeColor == 'slate') {
      visualDensity = VisualDensity.compact;
      borderRadius = 0.0;
    }

    var baseTheme = ThemeData(
      useMaterial3: true,
      visualDensity: visualDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        surface: scaffoldOverride ?? const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: scaffoldOverride ?? const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: scaffoldOverride ?? const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardOverride ?? const Color(0xFF1E1E1E),
        surfaceTintColor:
            Colors.transparent, // Disable tint to keep pure dark grey
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius == 0 ? 0 : 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: themeColor == 'audit' ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: primary),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        hintStyle: const TextStyle(color: Color(0xFF757575)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xB3FFFFFF), // 70% white
      ),
    );

    return _applyFont(baseTheme, fontFamily);
  }

  static Color _getThemeColor(String? colorName) {
    switch (colorName) {
      case 'crimson':
        return const Color(0xFFD32F2F);
      case 'emerald':
        return const Color(0xFF2E7D32);
      case 'sunset':
        return const Color(0xFFED6C02);
      case 'royal':
        return const Color(0xFF7B1FA2);
      case 'midnight':
        return const Color(0xFF37474F);
      // New Skins
      case 'ledger':
        return const Color(0xFF103766); // Professional Navy
      case 'audit':
        return const Color(0xFF00E676); // Success Green
      case 'mint':
        return const Color(0xFF00A36C); // Mint Green
      case 'glass':
        return const Color(0xFF00BCD4); // Cyan (for glass effect base)
      case 'slate':
        return const Color(0xFF455A64); // Slate Gray

      case 'classic':
      default:
        return const Color(0xFF054C78);
    }
  }

  static ThemeData _applyFont(ThemeData theme, String? fontFamily) {
    final isDark = theme.brightness == Brightness.dark;

    final baseTextTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xB3FFFFFF) : AppColors.textSecondary,
      ),
    );

    if (fontFamily == null || fontFamily == 'Poppins') {
      return theme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
      );
    }

    TextTheme newTextTheme;
    switch (fontFamily) {
      case 'Roboto':
        newTextTheme = GoogleFonts.robotoTextTheme(baseTextTheme);
        break;
      case 'Open Sans':
        newTextTheme = GoogleFonts.openSansTextTheme(baseTextTheme);
        break;
      case 'Lato':
        newTextTheme = GoogleFonts.latoTextTheme(baseTextTheme);
        break;
      case 'Inter':
        newTextTheme = GoogleFonts.interTextTheme(baseTextTheme);
        break;
      case 'Montserrat':
        newTextTheme = GoogleFonts.montserratTextTheme(baseTextTheme);
        break;
      case 'Nunito':
        newTextTheme = GoogleFonts.nunitoTextTheme(baseTextTheme);
        break;
      default:
        newTextTheme = GoogleFonts.poppinsTextTheme(baseTextTheme);
    }

    return theme.copyWith(textTheme: newTextTheme);
  }
}
