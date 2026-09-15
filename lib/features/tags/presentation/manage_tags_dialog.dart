import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../transactions/data/transaction_repository.dart';

class ManageTagsDialog extends ConsumerStatefulWidget {
  const ManageTagsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ManageTagsDialog(),
    );
  }

  @override
  ConsumerState<ManageTagsDialog> createState() => _ManageTagsDialogState();
}

class _ManageTagsDialogState extends ConsumerState<ManageTagsDialog> {
  static const List<Color> _tagColors = [
    Color(0xFF26B2AB),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFF6366F1),
  ];

  void _showAddOrEditTagModal({Tag? editingTag}) {
    final isEditing = editingTag != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? editingTag.name : '');
    Color selectedColor = isEditing
        ? Color(int.tryParse(editingTag.colorHex) ?? 0xFF26B2AB)
        : _tagColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEditing ? 'Edit Tag' : 'Create New Tag',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Tag Name',
                    hintText: 'e.g. Travel, Personal, Reimbursement, Tax',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tag Color',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagColors.map((c) {
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
                    await repo.updateTag(
                      id: editingTag.id,
                      name: name,
                      colorHex: colorHex,
                    );
                  } else {
                    await repo.createTag(
                      name: name,
                      colorHex: colorHex,
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text('Are you sure you want to delete "#${tag.name}"?'),
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
      await ref.read(transactionRepositoryProvider).deleteTag(tag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagsAsync = ref.watch(tagsStreamProvider);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                      'Manage Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Custom labels to filter and analyze expenses',
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

            // Add Tag Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                side: const BorderSide(color: AppColors.primary),
              ),
              onPressed: () => _showAddOrEditTagModal(),
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              label: const Text(
                'Create New Tag',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),

            // List of Tags
            Expanded(
              child: tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_outline_rounded,
                              size: 40,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          const SizedBox(height: 10),
                          Text(
                            'No tags created yet',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: tags.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final tag = tags[i];
                      final color = Color(int.tryParse(tag.colorHex) ?? 0xFF26B2AB);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
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
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '#${tag.name}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () =>
                                  _showAddOrEditTagModal(editingTag: tag),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.expense),
                              onPressed: () => _deleteTag(tag),
                            ),
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
