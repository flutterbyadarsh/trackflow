
import 'package:flutter/material.dart';

/// All app colors in one place.
class AppColors {
  AppColors._();

  // Brand colors - same in both themes
  static const Color primary = Color(0xFF2E2BB5);
  static const Color primaryDark = Color(0xFF1F1D8F);
  static const Color primaryLight = Color(0xFF5B57E8);

  // Light theme background colors
  static const Color bgTop = Color(0xFFEAE5FF);
  static const Color bgBottom = Color(0xFFFAF9FF);

  // Light theme fallback colors
  static const Color lightFieldFill = Color(0xFFEEF0FB);
  static const Color lightBorder = Color(0xFFE0E3F5);
  static const Color lightTextDark = Color(0xFF14142B);
  static const Color lightTextGrey = Color(0xFF6B6B80);

  // Status colors
  static const Color success = Color(0xFF1B7F5C);
  static const Color warning = Color(0xFFF5A524);
  static const Color error = Color(0xFFD93025);

  // Theme-aware colors
  static Color fieldFill(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  static Color textDark(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textGrey(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  // Button gradient - same in both themes
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light mode background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [bgTop, bgBottom, Colors.white],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
