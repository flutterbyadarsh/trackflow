
import 'package:flutter/material.dart';
import '../../../app_file/theme_file/app_colors.dart';

/// Theme-aware gradient background with soft glowing circles.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundGradient = isDark
        ? const LinearGradient(
      colors: [
        Color(0xFF0B1220),
        Color(0xFF111827),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    )
        : AppColors.backgroundGradient;

    final glowColor = isDark
        ? AppColors.primaryDark
        : AppColors.primary;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: backgroundGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _glow(
              220,
              isDark ? AppColors.primaryDark : Colors.white,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _glow(260, glowColor),
          ),
          child,
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
