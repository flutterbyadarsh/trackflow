
import 'package:flutter/material.dart';

import '../data_model/Category_entity.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  static const Color purple = Color(0xFF7C3AED);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  IconData selectedIcon = Icons.category_rounded;
  Color selectedColor = purple;

  final List<IconData> icons = [
    Icons.menu_book_rounded,
    Icons.work_rounded,
    Icons.person_rounded,
    Icons.favorite_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.fitness_center_rounded,
    Icons.shopping_bag_rounded,
    Icons.home_rounded,
    Icons.category_rounded,
    Icons.computer_rounded,
    Icons.music_note_rounded,
    Icons.flight_rounded,
  ];

  final List<Color> categoryColors = [
    const Color(0xFF7C3AED),
    const Color(0xFF2563EB),
    const Color(0xFF0891B2),
    const Color(0xFF16A34A),
    const Color(0xFFEF4444),
    const Color(0xFFF59E0B),
    const Color(0xFFDB2777),
    const Color(0xFF475569),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Save category and return it to CategoryScreen.
  void _saveCategory() {
    if (!_formKey.currentState!.validate()) return;

    final category = CategoryEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      icon: selectedIcon,
      color: selectedColor,
      taskCount: 0,
      backgroundColor: selectedColor.withAlpha(25),
      categoryColor: selectedColor.toARGB32(),
      categoryBackgroundColor: selectedColor.withAlpha(25).toARGB32(),
      categoryIcon: selectedIcon.codePoint,
    );

    Navigator.pop(context, category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,

      // App Bar
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colors.onSurface,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Add Category',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ),

      // Main Body
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading
                Text(
                  'Create a new category',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Choose a name, icon and color for your tasks.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 28),

                // Category Name
                Text(
                  'Category name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 10),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: colors.onSurface,
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category name';
                    }

                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. Reading',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.edit_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.error,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.error,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Choose Icon
                Text(
                  'Choose icon',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: icons.map((icon) {
                    final isSelected = selectedIcon == icon;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          selectedIcon = icon;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColor.withAlpha(25)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? selectedColor
                                : colors.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? selectedColor
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // Choose Color
                Text(
                  'Choose color',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: categoryColors.map((color) {
                    final isSelected = selectedColor == color;

                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                            color: colors.onSurface,
                            width: 3,
                          )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 21,
                        )
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // Category Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: selectedColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          selectedIcon,
                          color: selectedColor,
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          _nameController.text.trim().isEmpty
                              ? 'Category preview'
                              : _nameController.text.trim(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
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
      ),

      // Bottom Save Button
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
              onPressed: _saveCategory,
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Save Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
