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
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: _isSearchExpanded
            ? Container(
                height: 40,
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: TextField(
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search merchant or note...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: Icon(
              _showRunningBalance
                  ? Icons.account_balance_wallet_rounded
                  : Icons.account_balance_wallet_outlined,
              color: _showRunningBalance
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterPill('All', 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Expense', 'expense', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Income', 'income', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Transfer', 'transfer', isDark),
                const SizedBox(width: 8),

                // Account Filter Dropdown Pill
                accountsAsync.maybeWhen(
                  data: (accounts) => PopupMenuButton<String?>(
                    initialValue: _selectedAccountId,
                    onSelected: (val) =>
                        setState(() => _selectedAccountId = val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedAccountId != null
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : (isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedAccountId != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedAccountId != null
                                ? accounts
                                    .firstWhere(
                                        (a) => a.id == _selectedAccountId,
                                        orElse: () => accounts.first)
                                    .name
                                : 'Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedAccountId != null
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                              fontWeight: _selectedAccountId != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: _selectedAccountId != null
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ],
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId != null
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : (isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedCategoryId != null
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategoryId != null
                                ? categories
                                    .firstWhere(
                                        (c) => c.id == _selectedCategoryId,
                                        orElse: () => categories.first)
                                    .name
                                : 'Category',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedCategoryId != null
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                              fontWeight: _selectedCategoryId != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: _selectedCategoryId != null
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ],
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
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
          ),

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
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 56,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 13,
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
                        // Date Header with Day Total Pill
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateKey,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (dayTotal < 0
                                          ? AppColors.expense
                                          : AppColors.income)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  CurrencyFormatter.format(
                                    dayTotal,
                                    hideAmount: hideAmounts,
                                    showSign: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: dayTotal < 0
                                        ? AppColors.expense
                                        : AppColors.income,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transaction Cards
                        ...dayTxns.map((t) {
                          final isExpense = t.type == 'expense';
                          final isIncome = t.type == 'income';
                          final color = isExpense
                              ? AppColors.expense
                              : (isIncome
                                  ? AppColors.income
                                  : AppColors.transfer);
                          final icon = isExpense
                              ? Icons.shopping_bag_outlined
                              : (isIncome
                                  ? Icons.account_balance_wallet_outlined
                                  : Icons.swap_horiz_rounded);

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
                                boxShadow: AppStyles.softShadow,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        color.withValues(alpha: 0.15),
                                    child: Icon(icon, color: color, size: 18),
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
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.darkSurface
                                                    : AppColors.lightBackground,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark
                                                      ? AppColors.darkBorder
                                                      : AppColors.lightBorder,
                                                  width: 0.6,
                                                ),
                                              ),
                                              child: Text(
                                                t.paymentType.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? AppColors.darkTextTertiary
                                                      : AppColors.lightTextSecondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('hh:mm a')
                                                  .format(t.transactionDate),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppColors.darkTextSecondary
                                                    : AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: color,
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
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
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
          boxShadow: isSelected ? AppStyles.heroGlowShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
