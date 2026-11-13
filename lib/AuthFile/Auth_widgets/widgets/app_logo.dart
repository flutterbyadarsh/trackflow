import 'package:flutter/material.dart';
import '../../../app_file/theme_file/app_colors.dart';


/// TrackFlow app icon: white rounded square + wave/chart icon + chhota badge.
class AppLogo extends StatelessWidget {
  final double size;
  final IconData badgeIcon;
  final Color badgeColor;

  const AppLogo({
    super.key,
    this.size = 84,
    this.badgeIcon = Icons.check_rounded,
    this.badgeColor = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.3;
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ShaderMask(
              shaderCallback: (r) => AppColors.buttonGradient.createShader(r),
              child: Icon(Icons.insights_rounded,
                  size: size * 0.5, color: Colors.white),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(badgeIcon, size: badge * 0.6, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
