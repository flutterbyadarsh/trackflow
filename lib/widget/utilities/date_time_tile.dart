
import 'package:flutter/material.dart';

const Color purple = Color(0xFF7C3AED);

// Box Decoration
BoxDecoration _boxDecoration(BuildContext context) {
final colors = Theme.of(context).colorScheme;

return BoxDecoration(
color: colors.surface,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: colors.outlineVariant,
),
);
}

// Date and time tile
Widget dateTimeTile({
required BuildContext context,
required IconData icon,
required String label,
required String value,
required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: purple,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}