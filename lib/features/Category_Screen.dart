
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackflow/features/add_category_screen.dart';

import '../Statemanage_riverpod/provider/category_provider.dart';
import '../data_model/Category_entity.dart';
import '../widget/utilities/category_card.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  static const Color purple = Color(0xFF7C3AED);

  // Delete category confirmation
  void _deleteCategory(CategoryEntity category) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Delete Category',
            style: TextStyle(color: colors.onSurface),
          ),
          content: Text(
            'Are you sure you want to delete "${category.name}"?',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);

                await ref
                    .read(categoryProvider.notifier)
                    .deleteCategory(category.id);

                if (!mounted) return;

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('${category.name} deleted'),
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,

      // AppBar
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ),

      // Body
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organize your tasks',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '${categories.length} categories',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              ...categories.map(
                    (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CategoryCard(
                    category: category,
                    onTap: () {},
                    onDelete: () {
                      _deleteCategory(category);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Add Category Button
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final CategoryEntity? newCategory =
                await Navigator.push<CategoryEntity>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCategoryScreen(),
                  ),
                );

                if (!context.mounted || newCategory == null) return;

                final currentCategories = ref.read(categoryProvider);

                final alreadyExists = currentCategories.any(
                      (category) =>
                  category.name.trim().toLowerCase() ==
                      newCategory.name.trim().toLowerCase(),
                );

                if (alreadyExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category already exists'),
                    ),
                  );
                  return;
                }

                await ref
                    .read(categoryProvider.notifier)
                    .addCategory(newCategory);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${newCategory.name} added successfully'),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
            ),
          ),

        ),


      ),
    );
  }
}
