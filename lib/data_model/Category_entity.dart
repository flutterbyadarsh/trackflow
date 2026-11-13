import 'package:flutter/material.dart';

class CategoryEntity {
  final String id;
  final String name;
  final int taskCount;

  final IconData icon;
  final Color color;
  final Color backgroundColor;

  // Integer values for storing category details
  final int categoryColor;
  final int categoryBackgroundColor;
  final int categoryIcon;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.taskCount,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.categoryColor,
    required this.categoryBackgroundColor,
    required this.categoryIcon,
  });
}