
import 'package:flutter/material.dart';

import '../../data_model/Category_entity.dart';

class CategoryGrid extends StatelessWidget {
 final List<CategoryEntity> categories;
 final CategoryEntity selectedCategory;
 final ValueChanged<CategoryEntity> onCategorySelected;

 const CategoryGrid({
  super.key,
  required this.categories,
  required this.selectedCategory,
  required this.onCategorySelected,
 });

 @override
 Widget build(BuildContext context) {
  final colors = Theme
      .of(context)
      .colorScheme;
  final theme = Theme.of(context);

  const double itemHeight = 42;
  const double spacing = 8;

  final screenWidth = MediaQuery
      .sizeOf(context)
      .width;
  final double itemWidth = (screenWidth - 40 - spacing) / 2;

  return SizedBox(
   height: itemHeight * 2 + spacing,
   child: GridView.builder(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    padding: EdgeInsets.zero,
    itemCount: categories.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
     crossAxisCount: 2,
     crossAxisSpacing: spacing,
     mainAxisSpacing: spacing,
     mainAxisExtent: itemWidth,
    ),
    itemBuilder: (context, index) {
     final category = categories[index];

     final isSelected = selectedCategory.id == category.id;

     return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onCategorySelected(category),
      child: AnimatedContainer(
       duration: const Duration(milliseconds: 160),
       padding: const EdgeInsets.symmetric(horizontal: 8),
       decoration: BoxDecoration(
        color: isSelected
            ? category.color.withAlpha(23)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
         color: isSelected
             ? category.color
             : colors.outlineVariant,
         width: isSelected ? 1.6 : 1,
        ),
       ),
       child: Row(
        children: [
         Icon(
          category.icon,
          color: category.color,
          size: 18,
         ),

         const SizedBox(width: 6),

         Expanded(
          child: Text(
           category.name,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
           style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w500,
            color: colors.onSurface,
           ),
          ),
         ),
        ],
       ),
      ),
     );
    },
   ),
  );
 }
}
