
import 'package:flutter/material.dart';

class TodaysCard extends StatefulWidget {
final String title;
final String time;
final Color categoryColor;
final bool isCompleted;
final VoidCallback? onTap;
final ValueChanged<bool>? onChanged;

final IconData categoryIcon;
final String categoryName;
final String priority;
final bool reminderEnabled;
final String reminderTime;

const TodaysCard({
super.key,
required this.title,
required this.time,
required this.categoryColor,
this.isCompleted = false,
this.onChanged,
this.onTap,
this.categoryIcon = Icons.category_rounded,
this.categoryName = '',
this.priority = 'Medium',
this.reminderEnabled = false,
this.reminderTime = '',
});

@override
State<TodaysCard> createState() => _TodaysCardState();
}

class _TodaysCardState extends State<TodaysCard> {
  late bool isCompleted;

  @override
  void initState() {
    super.initState();
    isCompleted = widget.isCompleted;
  }

  @override
  void didUpdateWidget(covariant TodaysCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isCompleted != widget.isCompleted) {
      isCompleted = widget.isCompleted;
    }
  }

  void toggleTask() {
    final newValue = !isCompleted;

    setState(() {
      isCompleted = newValue;
    });

    widget.onChanged?.call(newValue);
  }

  Color get priorityColor {
    switch (widget.priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isCompleted ? 0.78 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
// Category color vertical line
                  Container(
                    width: 4,
                    height: 66,
                    decoration: BoxDecoration(
                      color: widget.categoryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  const SizedBox(width: 12),

// Category icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      widget.categoryIcon,
                      color: widget.categoryColor,
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 12),

// Task information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
// Task title
                        Text(
                          widget.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationThickness: 1.5,
                          ),
                        ),

                        const SizedBox(height: 7),

// Time and reminder
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.time,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            if (widget.reminderEnabled)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 14,
                                    color: widget.categoryColor,
                                  ),
                                  if (widget.reminderTime.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.reminderTime,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: widget.categoryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 7),

// Priority badge and category name
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.priority,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: priorityColor,
                                ),
                              ),
                            ),

                            if (widget.categoryName.isNotEmpty)
                              Text(
                                widget.categoryName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

// Checkbox
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: toggleTask,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? widget.categoryColor
                                : Colors.transparent,
                            border: Border.all(
                              color: widget.categoryColor.withValues(
                                alpha: isCompleted ? 1.0 : 0.75,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


