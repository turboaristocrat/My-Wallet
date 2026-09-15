import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../data/account_repository.dart';

class EditAccountDialog extends ConsumerStatefulWidget {
  final Account account;
  const EditAccountDialog({super.key, required this.account});

  static Future<void> show(BuildContext context, Account account) {
    return showDialog(
      context: context,
      builder: (_) => EditAccountDialog(account: account),
    );
  }

  @override
  ConsumerState<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<EditAccountDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _maskCtrl;
  late final TextEditingController _balCtrl;
  late final TextEditingController _limitCtrl;
  late String _selectedType;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.account.name);
    _maskCtrl = TextEditingController(text: widget.account.accountNumberMask ?? '');
    _balCtrl = TextEditingController(text: widget.account.balance.toStringAsFixed(2));
    _limitCtrl = TextEditingController(
      text: widget.account.creditLimit != null
          ? widget.account.creditLimit!.toStringAsFixed(0)
          : '',
    );
    _selectedType = widget.account.type;
    final colorInt = int.tryParse(widget.account.colorHex) ?? 0xFF008080;
    _selectedColor = Color(colorInt);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _maskCtrl.dispose();
    _balCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final bal = double.tryParse(_balCtrl.text);
    final limit = double.tryParse(_limitCtrl.text);
    final colorHex =
        '0x${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

    await ref.read(accountRepositoryProvider).updateAccount(
          id: widget.account.id,
          name: name,
          type: _selectedType,
          accountNumberMask: _maskCtrl.text.trim().isNotEmpty ? _maskCtrl.text.trim() : null,
          colorHex: colorHex,
          balance: bal,
          creditLimit: limit,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account updated successfully')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text('Are you sure you want to delete "${widget.account.name}"?'),
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
      await ref.read(accountRepositoryProvider).softDelete(widget.account.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name
              TextField(
                controller: _nameCtrl,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. HDFC Salary, Amex Platinum',
                  prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                ),
              ),
              const SizedBox(height: 14),

              // Type Selector
              Text(
                'Account Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('savings', 'Savings', Icons.savings_rounded, isDark),
                  _buildTypeChip('current', 'Current', Icons.business_center_rounded, isDark),
                  _buildTypeChip('credit_card', 'Credit Card', Icons.credit_card_rounded, isDark),
                  _buildTypeChip('cash', 'Cash', Icons.payments_rounded, isDark),
                  _buildTypeChip('wallet', 'Wallet', Icons.wallet_rounded, isDark),
                ],
              ),
              const SizedBox(height: 14),

              // Account Number Mask & Balance
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maskCtrl,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Last 4 Digits',
                        counterText: '',
                        prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _balCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Balance (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      ),
                    ),
                  ),
                ],
              ),

              if (_selectedType == 'credit_card') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Credit Limit (₹)',
                    hintText: 'e.g. 100000',
                    prefixIcon: const Icon(Icons.credit_score_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Color Selection
              Text(
                'Color Theme',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: AppColors.accountAccents.map((c) {
                  final isSelected = _selectedColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: const BorderSide(color: AppColors.expense),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                      ),
                      onPressed: _save,
                      child: const Text('Update Account', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, bool isDark) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : null),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      onSelected: (val) => setState(() => _selectedType = type),
    );
  }
}
