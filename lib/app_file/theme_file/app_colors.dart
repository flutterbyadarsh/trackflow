
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Core Lavender Colors
  static const Color backgroundprimary = Color(0xFFE9DDF7);
  static const Color primary = Color(0xFF8061B2);
  static const Color primaryDark = Color(0xFFB69AE8);
  static const Color secondary = Color(0xFFA78BCE);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Light Lavender Theme
  static const Color lightBackground = Color(0xFFF5F0FA);
  static const Color lightSurface = Color(0xFFFCFAFF);
  static const Color lightSurfaceVariant = Color(0xFFEEE6F7);
  static const Color lightText = Color(0xFF302641);
  static const Color lightTextSecondary = Color(0xFF756A83);
  static const Color lightBorder = Color(0xFFE5D9F0);

  // Dark Theme (preserved)
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);

  // Theme-aware color getters
  static Color textGrey(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color textDark(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color fieldFill(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  // Branded Gradients
  static const Gradient buttonGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const Gradient backgroundGradient = LinearGradient(
    colors: [lightBackground, backgroundprimary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Color primaryLight = Colors.white;
}

// Category Colors
class AppColors1 {
  AppColors1._();

  static const Color background = Color(0xFFF5F0FA);
  static const Color primary = Color(0xFF8061B2);
  static const Color textPrimary = Color(0xFF302641);
  static const Color textSecondary = Color(0xFF756A83);
  static const Color cardColor = Color(0xFFFCFAFF);
  static const Color border = Color(0xFFE5D9F0);
  static const Color softPurple = Color(0xFFEEE6F7);

  // Theme-aware alternatives
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color cardOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color softPurpleOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
}
