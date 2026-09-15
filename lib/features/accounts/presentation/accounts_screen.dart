import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../data/account_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import 'edit_account_dialog.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const AccountsScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  void _openAddAccountSheet() {
    final nameCtrl = TextEditingController();
    final maskCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    final limitCtrl = TextEditingController();
    String selectedType = 'savings';
    Color selectedColor = AppColors.accountAccents.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Name
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText: 'e.g. HDFC Salary, ICICI Coral',
                      prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightBackground,
                      border: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Account Type Selector Chips
                  Text(
                    'Account Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeChip('savings', 'Savings Bank', Icons.account_balance_rounded, selectedType, (v) => setSheetState(() => selectedType = v), isDark),
                        const SizedBox(width: 8),
                        _buildTypeChip('current', 'Current A/C', Icons.business_center_rounded, selectedType, (v) => setSheetState(() => selectedType = v), isDark),
                        const SizedBox(width: 8),
                        _buildTypeChip('credit_card', 'Credit Card', Icons.credit_card_rounded, selectedType, (v) => setSheetState(() => selectedType = v), isDark),
                        const SizedBox(width: 8),
                        _buildTypeChip('cash', 'Cash Wallet', Icons.payments_rounded, selectedType, (v) => setSheetState(() => selectedType = v), isDark),
                        const SizedBox(width: 8),
                        _buildTypeChip('wallet', 'Digital Wallet', Icons.wallet_rounded, selectedType, (v) => setSheetState(() => selectedType = v), isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Last 4 Digits & Initial Balance
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: maskCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Last 4 Digits',
                            hintText: '1234',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_rounded, size: 20),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightBackground,
                            border: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: balCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Balance (₹)',
                            prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightBackground,
                            border: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (selectedType == 'credit_card') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: limitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Credit Limit (₹)',
                        hintText: 'e.g. 100000',
                        prefixIcon: const Icon(Icons.credit_score_rounded, size: 20),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: AppStyles.roundedM,
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppStyles.roundedM,
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'Color Accent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: AppColors.accountAccents.map((c) {
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 34,
                          height: 34,
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
                                      blurRadius: 10,
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

                  // Save Button
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppStyles.roundedM,
                      gradient: AppColors.primaryGradient,
                      boxShadow: AppStyles.heroGlowShadow,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
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
                      child: const Text(
                        'Save Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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

  Widget _buildTypeChip(
    String typeValue,
    String label,
    IconData icon,
    String currentSelected,
    ValueChanged<String> onSelected,
    bool isDark,
  ) {
    final isSelected = currentSelected == typeValue;
    return GestureDetector(
      onTap: () => onSelected(typeValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          boxShadow: isSelected ? AppStyles.heroGlowShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
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
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Accounts & Cards',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              hideAmounts ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            tooltip: hideAmounts ? 'Show Amounts' : 'Hide Amounts',
            onPressed: () =>
                ref.read(hideAmountsProvider.notifier).state = !hideAmounts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Accounts Linked Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your bank accounts, credit cards, and cash wallets to see your full financial picture.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: AppStyles.roundedM,
                        gradient: AppColors.primaryGradient,
                        boxShadow: AppStyles.heroGlowShadow,
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: AppStyles.roundedM),
                        ),
                        onPressed: _openAddAccountSheet,
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text(
                          'Add Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Calculate Net Worth, Total Assets & Total Liabilities
          double totalAssets = 0.0;
          double totalLiabilities = 0.0;
          for (final a in accounts) {
            if (a.type == 'credit_card') {
              if (a.balance < 0) {
                totalLiabilities += a.balance.abs();
              } else {
                totalAssets += a.balance;
              }
            } else {
              if (a.balance >= 0) {
                totalAssets += a.balance;
              } else {
                totalLiabilities += a.balance.abs();
              }
            }
          }
          final netWorth = totalAssets - totalLiabilities;

          // Group by Type
          final bankAccs = accounts
              .where((a) => a.type == 'savings' || a.type == 'current')
              .toList();
          final creditAccs =
              accounts.where((a) => a.type == 'credit_card').toList();
          final walletAccs =
              accounts.where((a) => a.type == 'cash' || a.type == 'wallet').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              // Hero Net Worth Banner Card
              _buildNetWorthBanner(
                netWorth: netWorth,
                assets: totalAssets,
                liabilities: totalLiabilities,
                hideAmounts: hideAmounts,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              if (bankAccs.isNotEmpty)
                _buildSection(
                  title: 'Bank Accounts',
                  icon: Icons.account_balance_rounded,
                  accs: bankAccs,
                  isDark: isDark,
                  hideAmounts: hideAmounts,
                ),
              if (creditAccs.isNotEmpty)
                _buildSection(
                  title: 'Credit Cards',
                  icon: Icons.credit_card_rounded,
                  accs: creditAccs,
                  isDark: isDark,
                  hideAmounts: hideAmounts,
                  isCredit: true,
                ),
              if (walletAccs.isNotEmpty)
                _buildSection(
                  title: 'Cash & Digital Wallets',
                  icon: Icons.wallet_rounded,
                  accs: walletAccs,
                  isDark: isDark,
                  hideAmounts: hideAmounts,
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const SizedBox(),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: AppStyles.heroGlowShadow,
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: _openAddAccountSheet,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  // Hero Net Worth Banner
  Widget _buildNetWorthBanner({
    required double netWorth,
    required double assets,
    required double liabilities,
    required bool hideAmounts,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppStyles.roundedL,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: isDark ? AppStyles.heroGlowShadow : AppStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'TOTAL NET WORTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(netWorth, hideAmount: hideAmounts),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Total Assets Pill
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.income.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assets',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(assets, hideAmount: hideAmounts),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Total Liabilities Pill
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.expense.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Liabilities',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(liabilities, hideAmount: hideAmounts),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Account> accs,
    required bool isDark,
    required bool hideAmounts,
    bool isCredit = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${accs.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...accs.map((a) {
          final colorInt = int.tryParse(a.colorHex) ?? 0xFF8B5CF6;
          final accentColor = Color(colorInt);

          // Credit Card progress usage
          double? usageRatio;
          if (isCredit && a.creditLimit != null && a.creditLimit! > 0) {
            final used = a.balance < 0 ? a.balance.abs() : 0.0;
            usageRatio = (used / a.creditLimit!).clamp(0.0, 1.0);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppStyles.roundedL,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: AppStyles.softShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppStyles.roundedL,
                onTap: () => _showAccountTransactionsSheet(context, a),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isCredit
                                  ? Icons.credit_card_rounded
                                  : (a.type == 'cash'
                                      ? Icons.payments_rounded
                                      : (a.type == 'wallet'
                                          ? Icons.account_balance_wallet_rounded
                                          : Icons.account_balance_rounded)),
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  a.accountNumberMask != null
                                      ? '•••• ${a.accountNumberMask}'
                                      : a.type.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
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
                                  letterSpacing: -0.3,
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (usageRatio != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Credit Used: ${(usageRatio * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              'Available: ${CurrencyFormatter.format((a.creditLimit! - (a.balance < 0 ? a.balance.abs() : 0.0)).clamp(0, a.creditLimit!), showDecimals: false)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.income : AppColors.incomeGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: usageRatio,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? AppColors.darkSurface
                                : AppColors.lightDivider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              usageRatio > 0.8 ? AppColors.expense : AppColors.income,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showAccountTransactionsSheet(BuildContext context, Account account) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorInt = int.tryParse(account.colorHex) ?? 0xFF8B5CF6;
    final accentColor = Color(colorInt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.40,
          maxChildSize: 0.95,
          builder: (sheetCtx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account Summary Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            account.type == 'credit_card'
                                ? Icons.credit_card_rounded
                                : (account.type == 'cash'
                                    ? Icons.payments_rounded
                                    : (account.type == 'wallet'
                                        ? Icons.account_balance_wallet_rounded
                                        : Icons.account_balance_rounded)),
                            color: accentColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account.accountNumberMask != null
                                    ? '•••• ${account.accountNumberMask} • ${account.type.toUpperCase()}'
                                    : account.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
                              CurrencyFormatter.format(account.balance),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: account.balance < 0
                                    ? AppColors.expense
                                    : (isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary),
                              ),
                            ),
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Account',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            EditAccountDialog.show(context, account);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => AddTransactionSheet(
                                  preselectedAccountId: account.id,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add Transaction',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              widget.onNavigate('/transactions');
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text(
                              'Full Ledger',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                  ),

                  // Transactions List for this Account
                  Expanded(
                    child: Consumer(
                      builder: (c, ref, _) {
                        final txnsAsync = ref.watch(
                          accountTransactionsStreamProvider(account.id),
                        );

                        return txnsAsync.when(
                          data: (txns) {
                            if (txns.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 40,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No Transactions Yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Transactions logged for this account will appear here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final dateFormat = DateFormat('dd MMM, hh:mm a');

                            return ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              itemCount: txns.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: isDark
                                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                                    : AppColors.lightBorder.withValues(alpha: 0.5),
                              ),
                              itemBuilder: (ctx, i) {
                                final txn = txns[i];
                                final isIncome = txn.type == 'income';
                                final isTransfer = txn.type == 'transfer';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => AddTransactionSheet(
                                        initialTransaction: txn,
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isIncome
                                        ? AppColors.income.withValues(alpha: 0.15)
                                        : (isTransfer
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : AppColors.expense.withValues(alpha: 0.15)),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward_rounded
                                          : (isTransfer
                                              ? Icons.swap_horiz_rounded
                                              : Icons.arrow_upward_rounded),
                                      size: 18,
                                      color: isIncome
                                          ? AppColors.income
                                          : (isTransfer
                                              ? AppColors.primary
                                              : AppColors.expense),
                                    ),
                                  ),
                                  title: Text(
                                    txn.merchantName ?? txn.note ?? 'Transaction',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    dateFormat.format(txn.transactionDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  trailing: Text(
                                    '${isIncome ? '+' : (isTransfer ? '' : '-')}${CurrencyFormatter.format(txn.amount)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isIncome
                                          ? AppColors.income
                                          : (isTransfer
                                              ? AppColors.primary
                                              : AppColors.expense),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (_, _) => const SizedBox(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

