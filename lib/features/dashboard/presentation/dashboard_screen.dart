import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../transactions/data/transaction_repository.dart';
import '../data/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onOpenAddTransaction;
  final ValueChanged<String> onNavigate;

  const DashboardScreen({
    super.key,
    required this.onOpenAddTransaction,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyFlowAsync = ref.watch(monthlyFlowProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final recentTxnsAsync = ref.watch(recentTransactionsStreamProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/dashboard',
        onNavigate: onNavigate,
      ),
      appBar: AppBar(
        title: const Text('My Wallet'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => onNavigate('/inbox'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Customize Dashboard',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Widget Customization coming in Phase 2')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeAccountsStreamProvider);
          ref.invalidate(monthlyFlowProvider);
          ref.invalidate(recentTransactionsStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Good day 👋',
                style: AppStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Financial Overview',
                style: AppStyles.displayMedium.copyWith(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Total Net Balance Hero Card (Deep Emerald Teal)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryDarkest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppStyles.roundedL,
                  boxShadow: AppStyles.heroGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Net Balance',
                      style: AppStyles.labelSmall.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(
                        totalBalance,
                        hideAmount: hideAmounts,
                      ),
                      style: AppStyles.displayLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Active Overview',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Income & Expense Quick Cards
              monthlyFlowAsync.when(
                data: (flow) => Row(
                  children: [
                    Expanded(
                      child: _buildFlowCard(
                        title: 'Income',
                        amount: flow.income,
                        color: AppColors.income,
                        bgColor: isDark
                            ? AppColors.darkCard
                            : AppColors.incomeContainer.withValues(alpha: 0.5),
                        icon: Icons.arrow_upward_rounded,
                        isDark: isDark,
                        hideAmount: hideAmounts,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFlowCard(
                        title: 'Expense',
                        amount: flow.expense,
                        color: AppColors.expense,
                        bgColor: isDark
                            ? AppColors.darkCard
                            : AppColors.expenseContainer.withValues(alpha: 0.5),
                        icon: Icons.arrow_downward_rounded,
                        isDark: isDark,
                        hideAmount: hideAmounts,
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // 3. Accounts Section (2-Column Large Cards Grid)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Accounts',
                    style: AppStyles.titleMedium.copyWith(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate('/accounts'),
                    child: const Text(
                      'See all',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return _buildEmptyAccountsBanner(context, isDark);
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: accounts.length > 4 ? 4 : accounts.length,
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      final colorInt = int.tryParse(acc.colorHex) ?? 0xFF008080;
                      final accentColor = Color(colorInt);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: AppStyles.roundedM,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          boxShadow: AppStyles.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    acc.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              acc.accountNumberMask != null
                                  ? '•••• ${acc.accountNumberMask}'
                                  : acc.type.toUpperCase(),
                              style: AppStyles.labelSmall.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                acc.balance,
                                hideAmount: hideAmounts,
                              ),
                              style: AppStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary,
                              ),
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
              const SizedBox(height: 24),

              // 4. Monthly Cash Flow Wave Chart Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppStyles.roundedL,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  boxShadow: AppStyles.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cash Flow Trend',
                          style: AppStyles.titleMedium.copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'This Month',
                          style: AppStyles.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 30),
                                FlSpot(1, 45),
                                FlSpot(2, 38),
                                FlSpot(3, 58),
                                FlSpot(4, 52),
                                FlSpot(5, 75),
                              ],
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.3),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Recent Transactions Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AppStyles.titleMedium.copyWith(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate('/transactions'),
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              recentTxnsAsync.when(
                data: (txns) {
                  if (txns.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No transactions yet. Tap + to add one!',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: txns.map((t) {
                      final isExpense = t.type == 'expense';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
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
                                  : AppColors.incomeContainer,
                              child: Icon(
                                isExpense
                                    ? Icons.shopping_bag_outlined
                                    : Icons.account_balance_wallet_outlined,
                                color: isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.merchantName ?? t.type.toUpperCase(),
                                    style: AppStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  if (t.note != null && t.note!.isNotEmpty)
                                    Text(
                                      t.note!,
                                      style: AppStyles.labelSmall.copyWith(
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
                                    : AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox(),
              ),

              const SizedBox(height: 80), // bottom space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: onOpenAddTransaction,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildFlowCard({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
    required bool isDark,
    required bool hideAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppStyles.roundedM,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount, hideAmount: hideAmount),
            style: AppStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountsBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppStyles.roundedM,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_rounded,
              color: AppColors.primaryLight, size: 36),
          const SizedBox(height: 8),
          const Text(
            'No accounts found',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your bank accounts, credit cards, or cash to start tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => onNavigate('/accounts'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Account'),
          ),
        ],
      ),
    );
  }
}
