import 'package:flutter/material.dart';
import '../data_model/Category_entity.dart';

final List<CategoryEntity> dummyCategories = [
  CategoryEntity(
    id: 'study',
    name: 'Study',
    icon: Icons.menu_book_rounded,
    color: const Color(0xFF7C3AED),
    backgroundColor: const Color(0xFFEDE9FE),
    taskCount: 1,
    categoryColor: 0xFF7C3AED,
    categoryBackgroundColor: 0xFFEDE9FE,
    categoryIcon: Icons.menu_book_rounded.codePoint,
  ),

  CategoryEntity(
    id: 'work',
    name: 'Work',
    icon: Icons.work_rounded,
    color: const Color(0xFF0891B2),
    backgroundColor: const Color(0xFFCFFAFE),
    taskCount: 0,
    categoryColor: 0xFF0891B2,
    categoryBackgroundColor: 0xFFCFFAFE,
    categoryIcon: Icons.work_rounded.codePoint,
  ),

  CategoryEntity(
    id: 'personal',
    name: 'Personal',
    icon: Icons.person_rounded,
    color: const Color(0xFF4F46E5),
    backgroundColor: const Color(0xFFE0E7FF),
    taskCount: 0,
    categoryColor: 0xFF4F46E5,
    categoryBackgroundColor: 0xFFE0E7FF,
    categoryIcon: Icons.person_rounded.codePoint,
  ),
  CategoryEntity(
    id: 'other',
    name: 'Other',
    icon: Icons.other_houses_rounded,
    color: const Color(0xFFFBB560),
    backgroundColor: const Color(0xFFF3D7C8),
    taskCount: 0,
    categoryColor: 0xFFFBB560,
    categoryBackgroundColor: 0xFFF3D7C8,
    categoryIcon: Icons.other_houses_rounded.codePoint,
  ),
];