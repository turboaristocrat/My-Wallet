import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../data/transaction_repository.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const TransactionsScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _selectedType = 'all'; // 'all', 'expense', 'income', 'transfer'
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _showRunningBalance = false;
  bool _isSearchExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final repo = ref.watch(transactionRepositoryProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final transactionsStream = repo.watchFilteredTransactions(
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      type: _selectedType,
      searchQuery: _searchQuery,
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/transactions',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        title: _isSearchExpanded
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search merchant or note...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(
                _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: Icon(_showRunningBalance
                ? Icons.account_balance_wallet_rounded
                : Icons.account_balance_wallet_outlined),
            tooltip: 'Toggle Daily Running Balance',
            onPressed: () =>
                setState(() => _showRunningBalance = !_showRunningBalance),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Expense', 'expense'),
                const SizedBox(width: 8),
                _buildFilterChip('Income', 'income'),
                const SizedBox(width: 8),
                _buildFilterChip('Transfer', 'transfer'),
                const SizedBox(width: 8),

                // Account Filter Dropdown Pill
                accountsAsync.maybeWhen(
                  data: (accounts) => PopupMenuButton<String?>(
                    initialValue: _selectedAccountId,
                    onSelected: (val) =>
                        setState(() => _selectedAccountId = val),
                    child: Chip(
                      label: Text(
                        _selectedAccountId != null
                            ? accounts
                                .firstWhere(
                                    (a) => a.id == _selectedAccountId,
                                    orElse: () => accounts.first)
                                .name
                            : 'Account ▾',
                        style: TextStyle(
                          color: _selectedAccountId != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          fontWeight: _selectedAccountId != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      side: BorderSide(
                        color: _selectedAccountId != null
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: null,
                        child: Text('All Accounts'),
                      ),
                      ...accounts.map(
                        (a) => PopupMenuItem(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox(),
                ),
                const SizedBox(width: 8),

                // Category Filter Dropdown Pill
                categoriesAsync.maybeWhen(
                  data: (categories) => PopupMenuButton<String?>(
                    initialValue: _selectedCategoryId,
                    onSelected: (val) =>
                        setState(() => _selectedCategoryId = val),
                    child: Chip(
                      label: Text(
                        _selectedCategoryId != null
                            ? categories
                                .firstWhere(
                                    (c) => c.id == _selectedCategoryId,
                                    orElse: () => categories.first)
                                .name
                            : 'Category ▾',
                        style: TextStyle(
                          color: _selectedCategoryId != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                          fontWeight: _selectedCategoryId != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCard,
                      side: BorderSide(
                        color: _selectedCategoryId != null
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...categories.map(
                        (c) => PopupMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions Stream List
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final txns = snapshot.data ?? [];
                if (txns.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 56,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: AppStyles.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search or filters',
                          style: AppStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by formatted date
                final Map<String, List<Transaction>> grouped = {};
                for (final t in txns) {
                  final key = DateFormat('EEE, dd MMM yyyy')
                      .format(t.transactionDate);
                  grouped.putIfAbsent(key, () => []).add(t);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.elementAt(index);
                    final dayTxns = grouped[dateKey]!;

                    // Compute Day Total
                    double dayTotal = 0.0;
                    for (final t in dayTxns) {
                      if (t.type == 'expense') dayTotal -= t.amount;
                      if (t.type == 'income') dayTotal += t.amount;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header with Day Total
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateKey,
                                style: AppStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                  dayTotal,
                                  hideAmount: hideAmounts,
                                  showSign: true,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: dayTotal < 0
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transaction Cards
                        ...dayTxns.map((t) {
                          final isExpense = t.type == 'expense';
                          final isIncome = t.type == 'income';

                          return InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => AddTransactionSheet(
                                  initialTransaction: t,
                                ),
                              );
                            },
                            borderRadius: AppStyles.roundedM,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                                borderRadius: AppStyles.roundedM,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isExpense
                                        ? AppColors.expenseContainer
                                        : (isIncome
                                            ? AppColors.incomeContainer
                                            : AppColors.transferContainer),
                                    child: Icon(
                                      isExpense
                                          ? Icons.shopping_bag_outlined
                                          : (isIncome
                                              ? Icons.arrow_downward_rounded
                                              : Icons.swap_horiz_rounded),
                                      color: isExpense
                                          ? AppColors.expense
                                          : (isIncome
                                              ? AppColors.income
                                              : AppColors.transfer),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.merchantName ??
                                              t.type.toUpperCase(),
                                          style: AppStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('hh:mm a')
                                              .format(t.transactionDate),
                                          style:
                                              AppStyles.labelSmall.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      t.amount,
                                      hideAmount: hideAmounts,
                                      showSign: true,
                                    ),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isExpense
                                          ? AppColors.expense
                                          : (isIncome
                                              ? AppColors.income
                                              : AppColors.transfer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const AddTransactionSheet(),
          );
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedType = value);
      },
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );
  }
}
