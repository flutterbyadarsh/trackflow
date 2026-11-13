
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(isDark: false);

  static ThemeData get dark => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    final surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final surfaceVariant = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    final text = isDark
        ? AppColors.darkText
        : AppColors.lightText;

    final secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final border = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    final primary = isDark
        ? AppColors.primaryDark
        : AppColors.primary;

    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,

      primary: primary,
      onPrimary: Colors.white,

      secondary: AppColors.secondary,
      onSecondary: Colors.white,

      error: AppColors.error,
      onError: Colors.white,

      surface: surface,
      onSurface: text,

      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: secondaryText,

      outline: border,
      outlineVariant: border,

      shadow: Colors.black,
      scrim: Colors.black54,

      inverseSurface:
      isDark ? AppColors.lightSurface : AppColors.darkSurface,

      onInverseSurface:
      isDark ? AppColors.lightText : AppColors.darkText,

      inversePrimary:
      isDark ? AppColors.primary : AppColors.primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,

      scaffoldBackgroundColor: background,

      textTheme: AppTypography.textTheme(text, secondaryText),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: border),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          side: BorderSide(color: border),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return TextStyle(
            fontSize: 12,
            fontWeight:
            selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? primary : secondaryText,
          );
        }),
      ),

      // Icons
      iconTheme: IconThemeData(color: text),

      // Dividers
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
      ),

      // SnackBar

// SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,

          backgroundColor: isDark
              ? AppColors.darkSurfaceVariant
              : const Color(0xFF8061B2),

          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          elevation: 4,

          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),

          actionTextColor: Colors.white,
          disabledActionTextColor: Colors.white70,
        ),



    );
  }
}
