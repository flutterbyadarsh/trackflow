
import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;

  const ProgressCard({
    super.key,
    required this.completedTasks,
    required this.totalTasks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const successColor = Color(0xFF00A878);

    final double progress = totalTasks <= 0
        ? 0.0
        : (completedTasks / totalTasks).clamp(0.0, 1.0).toDouble();

    final int percentage = (progress * 100).round();

    final String status = percentage == 100
        ? 'ALL DONE!'
        : percentage >= 50
        ? 'ON TRACK'
        : 'KEEP GOING';

    final String thought = percentage == 100
        ? 'Amazing work! You completed every task today.'
        : percentage >= 50
        ? 'Every step you take today brings you closer to your best tomorrow!'
        : 'Small steps every day lead to big achievements. Keep moving!';

    return Hero(
      tag: 'progress-card',
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF25243A)
                : colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF45415F)
                  : colors.outlineVariant.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(
                  alpha: isDark ? 0.20 : 0.07,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Summary
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: progress,
                          ),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                colors.surfaceContainerHighest,
                                valueColor:
                                const AlwaysStoppedAnimation(
                                  successColor,
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          '$percentage%',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Progress",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completedTasks of $totalTasks tasks',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 11,
                              color: successColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: successColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Motivational Message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF35314F)
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF514A70)
                        : colors.primary.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        thought,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFE5E0FF)
                              : colors.onPrimaryContainer,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 70,
                                color: isDark
                                    ? const Color(0xFF746AAB)
                                    : const Color(0xFFDFD8F8),
                              ),
                            ),
                            const Positioned(
                              right: 2,
                              top: 0,
                              child: Icon(
                                Icons.flag_rounded,
                                size: 36,
                                color: successColor,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 12,
                              child: Icon(
                                Icons.directions_run_rounded,
                                size: 66,
                                color: isDark
                                    ? const Color(0xFFB8A8FF)
                                    : const Color(0xFFB5B7BA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
