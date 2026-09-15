import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/presentation/manage_categories_dialog.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../tags/presentation/manage_tags_dialog.dart';
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
  bool _isSearchExpanded = false;
  bool _showRunningBalance = true;

  // Period navigation (Year & Month filter matching media_1789475207786.png)
  int? _selectedYear = DateTime.now().year;
  int? _selectedMonth; // null = entire year

  final Map<String, IconData> _categoryIcons = const {
    'restaurant': Icons.restaurant_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'directions_car': Icons.directions_car_rounded,
    'confirmation_number': Icons.confirmation_number_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'school': Icons.school_rounded,
    'payments': Icons.payments_rounded,
    'work': Icons.work_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'fastfood': Icons.fastfood_rounded,
    'flight': Icons.flight_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'pets': Icons.pets_rounded,
    'home': Icons.home_rounded,
    'phone_android': Icons.phone_android_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'category': Icons.category_rounded,
  };

  IconData _getIcon(String? iconName) {
    return _categoryIcons[iconName ?? 'category'] ?? Icons.category_rounded;
  }

  (DateTime?, DateTime?) _calculateDateRange() {
    if (_selectedYear == null) return (null, null);
    if (_selectedMonth != null) {
      final start = DateTime(_selectedYear!, _selectedMonth!, 1);
      final nextMonth = _selectedMonth! == 12
          ? DateTime(_selectedYear! + 1, 1, 1)
          : DateTime(_selectedYear!, _selectedMonth! + 1, 1);
      final end = nextMonth.subtract(const Duration(milliseconds: 1));
      return (start, end);
    } else {
      final start = DateTime(_selectedYear!, 1, 1);
      final end = DateTime(_selectedYear!, 12, 31, 23, 59, 59, 999);
      return (start, end);
    }
  }

  Map<String, double> _computeRunningBalances(
    List<Transaction> txnsDesc,
    List<Account> accounts,
  ) {
    final accountBalances = {for (final a in accounts) a.id: a.balance};
    double running = _selectedAccountId != null
        ? (accountBalances[_selectedAccountId] ?? 0.0)
        : accounts.fold(0.0, (sum, a) => sum + a.balance);

    final Map<String, double> result = {};
    for (final t in txnsDesc) {
      result[t.id] = running;
      if (t.type == 'expense') {
        running += t.amount;
      } else if (t.type == 'income') {
        running -= t.amount;
      } else if (t.type == 'transfer') {
        if (_selectedAccountId != null) {
          if (t.accountId == _selectedAccountId) {
            running += t.amount;
          } else if (t.toAccountId == _selectedAccountId) {
            running -= t.amount;
          }
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final repo = ref.watch(transactionRepositoryProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final allTagsAsync = ref.watch(tagsStreamProvider);
    final allTxnTagsAsync = ref.watch(allTransactionTagsStreamProvider);

    final accounts = accountsAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];
    final tags = allTagsAsync.value ?? [];
    final txnTags = allTxnTagsAsync.value ?? [];

    final categoryMap = {for (final c in categories) c.id: c};
    final accountMap = {for (final a in accounts) a.id: a};
    final tagMap = {for (final t in tags) t.id: t};

    final Map<String, List<Tag>> tagsByTxnId = {};
    for (final tt in txnTags) {
      final t = tagMap[tt.tagId];
      if (t != null) {
        tagsByTxnId.putIfAbsent(tt.transactionId, () => []).add(t);
      }
    }

    final (startDate, endDate) = _calculateDateRange();

    final transactionsStream = repo.watchFilteredTransactions(
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      type: _selectedType,
      startDate: startDate,
      endDate: endDate,
      searchQuery: _searchQuery,
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF7F9FC),
      drawer: AppSideDrawer(
        currentRoute: '/transactions',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkCard : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (scaffoldContext) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),
        title: _isSearchExpanded
            ? Container(
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search note or payee...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              )
            : const Text(
                'Records',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) _searchQuery = '';
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (val) {
              if (val == 'toggle_balance') {
                setState(() => _showRunningBalance = !_showRunningBalance);
              } else if (val == 'categories') {
                showDialog(
                  context: context,
                  builder: (_) => const ManageCategoriesDialog(),
                );
              } else if (val == 'tags') {
                showDialog(
                  context: context,
                  builder: (_) => const ManageTagsDialog(),
                );
              } else if (val == 'all_time') {
                setState(() {
                  _selectedYear = null;
                  _selectedMonth = null;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_balance',
                child: Row(
                  children: [
                    Icon(
                      _showRunningBalance
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text('Show Running Balance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Manage Categories'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tags',
                child: Row(
                  children: [
                    Icon(Icons.label_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Manage Tags'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'all_time',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Show All Records (All Time)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter Chips Strip
              Container(
                color: isDark ? AppColors.darkCard : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Expense', 'expense', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Income', 'income', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip('Transfer', 'transfer', isDark),
                      const SizedBox(width: 10),

                      // Account Filter Dropdown Pill
                      PopupMenuButton<String?>(
                        initialValue: _selectedAccountId,
                        onSelected: (val) =>
                            setState(() => _selectedAccountId = val),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedAccountId != null
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedAccountId != null
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedAccountId != null
                                    ? (accountMap[_selectedAccountId]?.name ??
                                        'Account')
                                    : 'Account',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedAccountId != null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedAccountId != null
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
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
                      const SizedBox(width: 6),

                      // Category Filter Dropdown Pill
                      PopupMenuButton<String?>(
                        initialValue: _selectedCategoryId,
                        onSelected: (val) =>
                            setState(() => _selectedCategoryId = val),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedCategoryId != null
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedCategoryId != null
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCategoryId != null
                                    ? (categoryMap[_selectedCategoryId]?.name ??
                                        'Category')
                                    : 'Category',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedCategoryId != null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedCategoryId != null
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
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
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
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
                              'No records found',
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
                              'Tap + below to record a new transaction',
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

                    final runningBalances =
                        _computeRunningBalances(txns, accounts);

                    // Group by Year -> Month
                    final Map<int, Map<String, List<Transaction>>> hierarchy = {};
                    for (final t in txns) {
                      final year = t.transactionDate.year;
                      final monthKey = DateFormat('MMM yyyy')
                          .format(t.transactionDate)
                          .toUpperCase();
                      hierarchy.putIfAbsent(year, () => {});
                      hierarchy[year]!.putIfAbsent(monthKey, () => []).add(t);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                      itemCount: hierarchy.keys.length,
                      itemBuilder: (context, yearIdx) {
                        final year = hierarchy.keys.elementAt(yearIdx);
                        final monthsMap = hierarchy[year]!;

                        // Calculate Year Expenses / Sum
                        double yearExpense = 0.0;
                        for (final mList in monthsMap.values) {
                          for (final t in mList) {
                            if (t.type == 'expense') yearExpense += t.amount;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Year Header Row (media_1789475207786.png)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              color: isDark
                                  ? AppColors.darkBackground
                                  : const Color(0xFFF1F5F9),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    year.toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Î£ ${CurrencyFormatter.format(yearExpense, hideAmount: hideAmounts)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Month Sections
                            ...monthsMap.entries.map((monthEntry) {
                              final monthKey = monthEntry.key;
                              final monthTxns = monthEntry.value;

                              // Calculate Month Balance & Expense
                              double monthBalance = 0.0;
                              double monthExpense = 0.0;
                              for (final t in monthTxns) {
                                if (t.type == 'expense') {
                                  monthExpense += t.amount;
                                  monthBalance -= t.amount;
                                } else if (t.type == 'income') {
                                  monthBalance += t.amount;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 2. Month Sub-Header Row (media_1789475207786.png)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface.withValues(alpha: 0.6)
                                          : Colors.white,
                                      border: Border(
                                        top: BorderSide(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : const Color(0xFFE2E8F0),
                                          width: 0.6,
                                        ),
                                        bottom: BorderSide(
                                          color: isDark
                                              ? AppColors.darkBorder
                                              : const Color(0xFFE2E8F0),
                                          width: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          monthKey,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Balance ${CurrencyFormatter.format(monthBalance, hideAmount: hideAmounts, showSign: true)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: monthBalance >= 0
                                                ? AppColors.income
                                                : AppColors.expense,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Î£ ${CurrencyFormatter.format(monthExpense, hideAmount: hideAmounts)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3. Transactions List in Month
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: monthTxns.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      indent: 74,
                                      color: isDark
                                          ? AppColors.darkBorder.withValues(alpha: 0.5)
                                          : const Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (context, idx) {
                                      final t = monthTxns[idx];
                                      final cat = categoryMap[t.categoryId];
                                      final acc = accountMap[t.accountId];
                                      final toAcc = t.toAccountId != null
                                          ? accountMap[t.toAccountId]
                                          : null;
                                      final tagsList =
                                          tagsByTxnId[t.id] ?? [];
                                      final runBal = runningBalances[t.id];

                                      return _buildRecordRow(
                                        context: context,
                                        isDark: isDark,
                                        hideAmounts: hideAmounts,
                                        transaction: t,
                                        category: cat,
                                        account: acc,
                                        toAccount: toAcc,
                                        tags: tagsList,
                                        runningBalance: runBal,
                                      );
                                    },
                                  ),
                                ],
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

          // Floating Bottom Filter Bar & Controls (media_1789475207786.png)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDateNavigationPill(isDark),
              ],
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
            borderRadius: BorderRadius.circular(20),
          ),
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

  // --- Record Row (media_1789475207786.png) ---
  Widget _buildRecordRow({
    required BuildContext context,
    required bool isDark,
    required bool hideAmounts,
    required Transaction transaction,
    required Category? category,
    required Account? account,
    required Account? toAccount,
    required List<Tag> tags,
    required double? runningBalance,
  }) {
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';

    final Color amountColor = isExpense
        ? AppColors.expense
        : (isIncome ? AppColors.income : AppColors.transfer);

    final catColor = category != null
        ? Color(int.tryParse(category.colorHex) ?? 0xFF008080)
        : (isExpense
            ? AppColors.expense
            : (isIncome ? AppColors.income : AppColors.transfer));

    final catIcon = category != null
        ? _getIcon(category.iconName)
        : (isExpense
            ? Icons.shopping_bag_outlined
            : (isIncome
                ? Icons.account_balance_wallet_outlined
                : Icons.swap_horiz_rounded));

    // Status badge icon & color
    final (statusIcon, statusColor) = switch (transaction.status) {
      'cleared' => (Icons.check_rounded, const Color(0xFF10B981)),
      'pending' => (Icons.access_time_filled_rounded, Colors.orange),
      'reconciled' => (Icons.verified_rounded, Colors.blue),
      _ => (Icons.check_rounded, const Color(0xFF10B981)),
    };

    // Subtitle text: Account name or transfer flow
    final String accountText = isTransfer
        ? '${account?.name ?? "Source"} â†’ ${toAccount?.name ?? "Target"}'
        : (account?.name ?? 'Cash');

    // Title: Category name or Note/Merchant
    final String titleText = transaction.merchantName != null &&
            transaction.merchantName!.trim().isNotEmpty
        ? transaction.merchantName!
        : (category?.name ??
            (isTransfer ? 'Transfer' : transaction.type.toUpperCase()));

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => AddTransactionSheet(
            initialTransaction: transaction,
          ),
        );
      },
      onLongPress: () => _showQuickActionSheet(context, transaction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Category Avatar with Cleared/Status Badge (media_1789475207786.png)
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: catColor.withValues(alpha: 0.15),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Center Column: Title, Account, Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            '#${t.name}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Column: Amount, Running Balance, Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(
                    isExpense ? -transaction.amount : transaction.amount,
                    hideAmount: hideAmounts,
                    showSign: isExpense || isIncome,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                if (_showRunningBalance && runningBalance != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '(${CurrencyFormatter.format(runningBalance, hideAmount: hideAmounts)})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy').format(transaction.transactionDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Floating Bottom Navigation Pill (media_1789475207786.png) ---
  Widget _buildDateNavigationPill(bool isDark) {
    final String label = _selectedYear == null
        ? 'All Time'
        : (_selectedMonth == null
            ? '$_selectedYear'
            : '${DateFormat('MMM').format(DateTime(2026, _selectedMonth!))} $_selectedYear');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous Button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                if (_selectedYear == null) {
                  _selectedYear = DateTime.now().year;
                  return;
                }
                if (_selectedMonth != null) {
                  if (_selectedMonth! > 1) {
                    _selectedMonth = _selectedMonth! - 1;
                  } else {
                    _selectedMonth = 12;
                    _selectedYear = _selectedYear! - 1;
                  }
                } else {
                  _selectedYear = _selectedYear! - 1;
                }
              });
            },
          ),
          Container(
            height: 20,
            width: 1,
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),

          // Period Label with Dropdown Arrow
          InkWell(
            onTap: () => _showPeriodPickerDialog(isDark),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 20,
            width: 1,
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),

          // Next Button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                if (_selectedYear == null) {
                  _selectedYear = DateTime.now().year;
                  return;
                }
                if (_selectedMonth != null) {
                  if (_selectedMonth! < 12) {
                    _selectedMonth = _selectedMonth! + 1;
                  } else {
                    _selectedMonth = 1;
                    _selectedYear = _selectedYear! + 1;
                  }
                } else {
                  _selectedYear = _selectedYear! + 1;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  void _showPeriodPickerDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentYear = DateTime.now().year;
        final years = List.generate(7, (i) => currentYear - 3 + i);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Period',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = null;
                          _selectedMonth = null;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('All Time'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'YEAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: years.map((y) {
                    final isSel = _selectedYear == y && _selectedMonth == null;
                    return ChoiceChip(
                      label: Text(y.toString()),
                      selected: isSel,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedYear = y;
                            _selectedMonth = null;
                          });
                          Navigator.pop(ctx);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'MONTH (${_selectedYear ?? currentYear})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(12, (i) {
                    final monthNum = i + 1;
                    final monthName = DateFormat('MMM')
                        .format(DateTime(2026, monthNum));
                    final isSel = _selectedMonth == monthNum;
                    return ChoiceChip(
                      label: Text(monthName),
                      selected: isSel,
                      onSelected: (selected) {
                        setState(() {
                          _selectedYear ??= currentYear;
                          _selectedMonth = selected ? monthNum : null;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickActionSheet(BuildContext context, Transaction transaction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Edit Transaction'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => AddTransactionSheet(
                    initialTransaction: transaction,
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
              title: const Text(
                'Delete Transaction',
                style: TextStyle(color: AppColors.expense),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Transaction?'),
                    content: const Text(
                        'This will delete the record and automatically restore the account balance.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(transactionRepositoryProvider)
                      .deleteTransaction(transaction.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction deleted')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
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