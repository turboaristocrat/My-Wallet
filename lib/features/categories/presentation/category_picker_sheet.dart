import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../transactions/data/transaction_repository.dart';
import 'manage_categories_dialog.dart';

class CategoryPickerSheet extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  final ValueChanged<Category> onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    this.initialCategoryId,
    required this.onCategorySelected,
  });

  static Future<Category?> show(
    BuildContext context, {
    String? initialCategoryId,
  }) async {
    Category? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryPickerSheet(
        initialCategoryId: initialCategoryId,
        onCategorySelected: (cat) {
          selected = cat;
          Navigator.of(ctx).pop();
        },
      ),
    );
    return selected;
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  Category? _selectedParent;
  String _searchQuery = '';
  bool _isSearching = false;

  static const Map<String, IconData> _categoryIcons = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_basket': Icons.shopping_basket_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'directions_car': Icons.directions_car_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'movie': Icons.movie_rounded,
    'medical_services': Icons.medical_services_rounded,
    'school': Icons.school_rounded,
    'flight': Icons.flight_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'payments': Icons.payments_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'savings': Icons.savings_rounded,
    'home': Icons.home_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'computer': Icons.computer_rounded,
    'coffee': Icons.local_cafe_rounded,
    'wine_bar': Icons.wine_bar_rounded,
    'category': Icons.category_rounded,
  };

  IconData _getIcon(String iconName) {
    return _categoryIcons[iconName] ?? Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: categoriesAsync.when(
        data: (allCategories) {
          if (_selectedParent != null) {
            return _buildSubcategoryView(isDark, allCategories);
          }
          return _buildParentCategoryView(isDark, allCategories);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Error loading categories')),
      ),
    );
  }

  // --- Step 1: Parent Categories View (media_1789475281354.png) ---
  Widget _buildParentCategoryView(bool isDark, List<Category> allCategories) {
    final parents = allCategories.where((c) => c.parentId == null).toList();
    final filtered = _searchQuery.isEmpty
        ? parents
        : parents
            .where((p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top App Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              if (_isSearching)
                Expanded(
                  child: TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchQuery = '';
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Manage Categories',
                onPressed: () => ManageCategoriesDialog.show(context),
              ),
            ],
          ),
        ),

        // Section Title: ALL CATEGORIES
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
          child: Text(
            'ALL CATEGORIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),

        // Categories List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 72,
              color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
            ),
            itemBuilder: (ctx, idx) {
              final cat = filtered[idx];
              final subs = allCategories
                  .where((c) => c.parentId == cat.id)
                  .toList();
              final color = Color(int.tryParse(cat.colorHex) ?? 0xFF008080);
              final iconData = _getIcon(cat.iconName);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: Icon(iconData, color: Colors.white, size: 20),
                ),
                title: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                trailing: subs.isNotEmpty
                    ? Icon(Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)
                    : null,
                onTap: () {
                  if (subs.isNotEmpty) {
                    setState(() => _selectedParent = cat);
                  } else {
                    widget.onCategorySelected(cat);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Step 2: Subcategories View (media_1789475287507.png) ---
  Widget _buildSubcategoryView(bool isDark, List<Category> allCategories) {
    final parent = _selectedParent!;
    final parentColor =
        Color(int.tryParse(parent.colorHex) ?? 0xFF008080);
    final parentIcon = _getIcon(parent.iconName);
    final subs =
        allCategories.where((c) => c.parentId == parent.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top App Bar with Back
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _selectedParent = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parent.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Manage Categories',
                onPressed: () => ManageCategoriesDialog.show(context),
              ),
            ],
          ),
        ),

        // Section Title: GENERAL
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
          child: Text(
            'GENERAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),

        // Parent Category itself
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: parentColor,
            child: Icon(parentIcon, color: Colors.white, size: 20),
          ),
          title: Text(
            parent.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          onTap: () => widget.onCategorySelected(parent),
        ),

        // Section Title: SUBCATEGORIES
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUBCATEGORIES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              InkWell(
                onTap: () => ManageCategoriesDialog.show(context),
                child: const Text(
                  '+ Add Subcategory',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Subcategories List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: subs.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 72,
              color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
            ),
            itemBuilder: (ctx, idx) {
              final sub = subs[idx];
              final subColor =
                  Color(int.tryParse(sub.colorHex) ?? parentColor.toARGB32());
              final subIcon = _getIcon(sub.iconName);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: subColor,
                  child: Icon(subIcon, color: Colors.white, size: 20),
                ),
                title: Text(
                  sub.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () => widget.onCategorySelected(sub),
              );
            },
          ),
        ),
      ],
    );
  }
}
