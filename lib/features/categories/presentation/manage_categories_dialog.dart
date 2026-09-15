import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../transactions/data/transaction_repository.dart';

class ManageCategoriesDialog extends ConsumerStatefulWidget {
  const ManageCategoriesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ManageCategoriesDialog(),
    );
  }

  @override
  ConsumerState<ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends ConsumerState<ManageCategoriesDialog> {
  String? _expandedParentId;

  static const List<Map<String, dynamic>> _iconChoices = [
    {'name': 'restaurant', 'icon': Icons.restaurant_rounded, 'label': 'Dining'},
    {'name': 'shopping_basket', 'icon': Icons.shopping_basket_rounded, 'label': 'Groceries'},
    {'name': 'directions_car', 'icon': Icons.directions_car_rounded, 'label': 'Transport'},
    {'name': 'receipt_long', 'icon': Icons.receipt_long_rounded, 'label': 'Bills'},
    {'name': 'shopping_bag', 'icon': Icons.shopping_bag_rounded, 'label': 'Shopping'},
    {'name': 'movie', 'icon': Icons.movie_rounded, 'label': 'Entertainment'},
    {'name': 'medical_services', 'icon': Icons.medical_services_rounded, 'label': 'Health'},
    {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Education'},
    {'name': 'flight', 'icon': Icons.flight_rounded, 'label': 'Travel'},
    {'name': 'fitness_center', 'icon': Icons.fitness_center_rounded, 'label': 'Fitness'},
    {'name': 'payments', 'icon': Icons.payments_rounded, 'label': 'Salary'},
    {'name': 'trending_up', 'icon': Icons.trending_up_rounded, 'label': 'Investments'},
    {'name': 'card_giftcard', 'icon': Icons.card_giftcard_rounded, 'label': 'Gift'},
    {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Savings'},
    {'name': 'category', 'icon': Icons.category_rounded, 'label': 'Other'},
  ];

  static const List<Color> _colorChoices = [
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
  ];

  IconData _resolveIcon(String iconName) {
    for (final item in _iconChoices) {
      if (item['name'] == iconName) return item['icon'] as IconData;
    }
    return Icons.category_rounded;
  }

  void _showAddCategoryModal({String? parentId, Category? editingCategory}) {
    final isEditing = editingCategory != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? editingCategory.name : '');
    String selectedIcon = isEditing ? editingCategory.iconName : 'category';
    Color selectedColor = isEditing
        ? Color(int.tryParse(editingCategory.colorHex) ?? 0xFF008080)
        : (parentId != null ? const Color(0xFF3B82F6) : _colorChoices.first);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isSubcategory = parentId != null || (isEditing && editingCategory.parentId != null);

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEditing
                  ? 'Edit ${isSubcategory ? 'Subcategory' : 'Category'}'
                  : (isSubcategory ? 'Add Subcategory' : 'Add Category'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: '${isSubcategory ? 'Subcategory' : 'Category'} Name',
                        hintText: isSubcategory ? 'e.g. Snacks, Fuel, Metro' : 'e.g. Lifestyle',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Icon Selector
                    const Text('Select Icon',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _iconChoices.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (c, idx) {
                          final item = _iconChoices[idx];
                          final isSelected = selectedIcon == item['name'];
                          return InkWell(
                            onTap: () =>
                                setDialogState(() => selectedIcon = item['name']),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightBackground),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                                ),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : AppColors.lightTextPrimary),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Color Selector
                    const Text('Select Color',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorChoices.map((c) {
                        final isSelected = selectedColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final colorHex =
                      '0x${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
                  final repo = ref.read(transactionRepositoryProvider);

                  if (isEditing) {
                    await repo.updateCategory(
                      id: editingCategory.id,
                      name: name,
                      iconName: selectedIcon,
                      colorHex: colorHex,
                      parentId: editingCategory.parentId,
                    );
                  } else {
                    await repo.createCategory(
                      name: name,
                      iconName: selectedIcon,
                      colorHex: colorHex,
                      parentId: parentId,
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(isEditing ? 'Save Changes' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? Transactions using this category will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(transactionRepositoryProvider).deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCategoriesAsync = ref.watch(categoriesStreamProvider);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories & Subcategories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage expense & income classifications',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Add Category Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                side: const BorderSide(color: AppColors.primary),
              ),
              onPressed: () => _showAddCategoryModal(),
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              label: const Text(
                'New Parent Category',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            // List of Categories
            Expanded(
              child: allCategoriesAsync.when(
                data: (categories) {
                  final parentCategories =
                      categories.where((c) => c.parentId == null).toList();

                  if (parentCategories.isEmpty) {
                    return Center(
                      child: Text(
                        'No categories found. Create one above!',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: parentCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final parent = parentCategories[i];
                      final subcategories = categories
                          .where((c) => c.parentId == parent.id)
                          .toList();
                      final isExpanded = _expandedParentId == parent.id;
                      final color = Color(int.tryParse(parent.colorHex) ?? 0xFF008080);
                      final iconData = _resolveIcon(parent.iconName);

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightBackground,
                          borderRadius: AppStyles.roundedM,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: color.withValues(alpha: 0.18),
                                child: Icon(iconData, color: color, size: 20),
                              ),
                              title: Text(
                                parent.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${subcategories.length} subcategories',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded,
                                        size: 20, color: AppColors.primary),
                                    tooltip: 'Add Subcategory',
                                    onPressed: () =>
                                        _showAddCategoryModal(parentId: parent.id),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showAddCategoryModal(editingCategory: parent);
                                      } else if (val == 'delete') {
                                        _deleteCategory(parent);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete',
                                              style: TextStyle(color: AppColors.expense))),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _expandedParentId =
                                            isExpanded ? null : parent.id;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Expanded Subcategories List
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              if (subcategories.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Text(
                                        'No subcategories yet. ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showAddCategoryModal(
                                            parentId: parent.id),
                                        child: const Text(
                                          '+ Add one',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...subcategories.map((sub) {
                                  final subColor = Color(int.tryParse(sub.colorHex) ??
                                      0xFF3B82F6);
                                  final subIcon = _resolveIcon(sub.iconName);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isDark
                                              ? AppColors.darkBorder.withValues(alpha: 0.5)
                                              : AppColors.lightBorder.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 14),
                                        Icon(Icons.subdirectory_arrow_right_rounded,
                                            size: 16,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary),
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              subColor.withValues(alpha: 0.2),
                                          child: Icon(subIcon,
                                              color: subColor, size: 14),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            sub.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 16),
                                          onPressed: () => _showAddCategoryModal(
                                              parentId: parent.id,
                                              editingCategory: sub),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              size: 16, color: AppColors.expense),
                                          onPressed: () => _deleteCategory(sub),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
