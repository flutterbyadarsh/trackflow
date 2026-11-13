import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Statemanage_riverpod/provider/category_provider.dart';

class TaskFilterChips extends ConsumerWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  const TaskFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);
    final colors = Theme.of(context).colorScheme;

    final filters = [
      'All',
      ...categories.map((category) => category.name),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;

          final categoryData = categories
              .where((category) => category.name == filter)
              .firstOrNull;

          final chipColor = filter == 'All'
              ? colors.primary
              : categoryData != null
              ? Color(categoryData.categoryColor)
              : colors.primary;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterSelected(filter);
                }
              },
              showCheckmark: false,

              // Theme-aware chip backgrounds
              backgroundColor: colors.surface,
              selectedColor: chipColor,

              // Text colors
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),

              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),

              shape: const StadiumBorder(),

              // Border helps distinguish unselected chips in dark mode
              side: isSelected
                  ? BorderSide.none
                  : BorderSide(
                color: colors.outlineVariant,
                width: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}