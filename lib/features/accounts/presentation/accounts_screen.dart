import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../data/account_repository.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const AccountsScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _openAddAccountDialog() {
    final nameCtrl = TextEditingController();
    final maskCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    final limitCtrl = TextEditingController();
    String selectedType = 'savings';
    Color selectedColor = AppColors.accountAccents.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Account'),
            shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedL),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. HDFC Salary, ICICI Card',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Account Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'savings', child: Text('Savings Bank')),
                      DropdownMenuItem(
                          value: 'current', child: Text('Current Account')),
                      DropdownMenuItem(
                          value: 'credit_card', child: Text('Credit Card')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
                      DropdownMenuItem(
                          value: 'wallet', child: Text('Digital Wallet')),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maskCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 Digits (Optional)',
                      hintText: '1234',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Initial Balance (₹)',
                    ),
                  ),
                  if (selectedType == 'credit_card') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Credit Limit (₹)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Color Accent',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AppColors.accountAccents.map((c) {
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: c,
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
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
                  if (nameCtrl.text.trim().isEmpty) return;
                  final bal = double.tryParse(balCtrl.text) ?? 0.0;
                  final limit = double.tryParse(limitCtrl.text);

                  await ref.read(accountRepositoryProvider).createAccount(
                        name: nameCtrl.text.trim(),
                        type: selectedType,
                        accountNumberMask: maskCtrl.text.trim().isNotEmpty
                            ? maskCtrl.text.trim()
                            : null,
                        colorHex:
                            '0x${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
                        initialBalance: bal,
                        creditLimit: limit,
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/accounts',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        title: const Text('Accounts'),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_rounded,
                      size: 60,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  const SizedBox(height: 12),
                  const Text('No accounts added yet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Tap + to create your first bank or card account'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _openAddAccountDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          // Group by Type
          final bankAccs = accounts
              .where((a) => a.type == 'savings' || a.type == 'current')
              .toList();
          final creditAccs =
              accounts.where((a) => a.type == 'credit_card').toList();
          final cashAccs = accounts.where((a) => a.type == 'cash').toList();
          final walletAccs =
              accounts.where((a) => a.type == 'wallet').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              if (bankAccs.isNotEmpty)
                _buildSection('Bank Accounts', bankAccs, isDark, hideAmounts),
              if (creditAccs.isNotEmpty)
                _buildSection('Credit Cards', creditAccs, isDark, hideAmounts),
              if (cashAccs.isNotEmpty)
                _buildSection('Cash Wallets', cashAccs, isDark, hideAmounts),
              if (walletAccs.isNotEmpty)
                _buildSection(
                    'Digital Wallets', walletAccs, isDark, hideAmounts),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const SizedBox(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: _openAddAccountDialog,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Account> accs,
    bool isDark,
    bool hideAmounts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            title,
            style: AppStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        ...accs.map((a) {
          final colorInt = int.tryParse(a.colorHex) ?? 0xFF008080;
          final accentColor = Color(colorInt);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppStyles.roundedM,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: AppStyles.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: AppStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.accountNumberMask != null
                            ? 'A/C •••• ${a.accountNumberMask}'
                            : a.type.toUpperCase(),
                        style: AppStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(
                        a.balance,
                        hideAmount: hideAmounts,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: a.balance < 0
                            ? AppColors.expense
                            : (isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                    if (a.creditLimit != null)
                      Text(
                        'Limit: ${CurrencyFormatter.format(a.creditLimit!, showDecimals: false)}',
                        style: AppStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
