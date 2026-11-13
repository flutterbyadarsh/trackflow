
import 'package:flutter/material.dart';

const Color purple = Color(0xFF7C3AED);

// Dropdown Builder
Widget buildDropdown({
required BuildContext context,
required String value,
required List<String> items,
required ValueChanged<String?> onChanged,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  return DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    borderRadius: BorderRadius.circular(16),
    dropdownColor: colors.surface,
    style: theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurface,
    ),
    iconEnabledColor: colors.onSurfaceVariant,
    decoration: InputDecoration(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colors.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: purple,
          width: 1.5,
        ),
      ),
    ),

    items: items.map((item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(
          item,
          style: TextStyle(
            color: colors.onSurface,
          ),
        ),
      );
    }).toList(),

    onChanged: onChanged,
  );
}