// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF054C78); // Deep Blue (was 0xFF2196F3)
  static const Color primaryDark =
      Color(0xFF00365B); // Darker Deep Blue (was 0xFF1976D2)
  static const Color primaryLight =
      Color(0xFF00AEEF); // Bright Cyan (was 0xFF64B5F6)

  // Accent Colors
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentLight = Color(0xFF4DD0E1);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF054C78); // Matches Primary

  // Order Status Colors
  static const Color orderBooked = Color(0xFF054C78); // Matches Primary
  static const Color orderApproved = Color(0xFF4CAF50); // Green
  static const Color orderPending = Color(0xFFFFA726); // Orange
  static const Color orderRejected = Color(0xFFF44336); // Red

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textWhite = Colors.white;

  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFFBDBDBD);

  // Icon Colors
  static const Color iconPrimary = Color(0xFF757575);
  static const Color iconSecondary = Color(0xFFBDBDBD);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dashboard Card Colors
  static const Color cardPurple = Color(0xFF9C27B0);
  static const Color cardTeal = Color(0xFF009688);
  static const Color cardIndigo = Color(0xFF3F51B5);
  static const Color cardOrange = Color(0xFFFF9800);

  // Login 2025 Design Colors
  static const Color loginGradientStart = Color(0xFF054C78); // Deep Blue
  static const Color loginGradientEnd = Color(0xFF00AEEF); // Bright Cyan
  static const Color loginCardLight =
      Color(0xCCFFFFFF); // Semi-transparent white
  static const Color loginButtonGradientStart = Color(0xFFE0E0E0);
  static const Color loginButtonGradientEnd = Color(0xFFBDBDBD);
}
