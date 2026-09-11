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
    final pendingCount = ref.watch(pendingQueueCountProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/dashboard',
        onNavigate: onNavigate,
      ),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            tooltip: hideAmounts ? 'Show Amounts' : 'Hide Amounts',
            icon: Icon(
              hideAmounts
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () {
              ref.read(hideAmountsProvider.notifier).state = !hideAmounts;
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                onPressed: () => onNavigate('/inbox'),
              ),
              if (pendingCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Center(
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(
                Icons.person_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeAccountsStreamProvider);
          ref.invalidate(monthlyFlowProvider);
          ref.invalidate(recentTransactionsStreamProvider);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Greeting Header
                  _buildUserGreeting(isDark),
                  const SizedBox(height: 20),

                  // 1. Top 3 KPI Sparkline Stat Cards
                  monthlyFlowAsync.when(
                    data: (flow) => _buildTopKpiCards(
                      context: context,
                      flow: flow,
                      isDark: isDark,
                      hideAmounts: hideAmounts,
                      isWide: isWide,
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 22),

                  // Responsive Body Layout
                  if (isWide)
                    _buildWideLayout(
                      context: context,
                      totalBalance: totalBalance,
                      hideAmounts: hideAmounts,
                      isDark: isDark,
                      accountsAsync: accountsAsync,
                      monthlyFlowAsync: monthlyFlowAsync,
                      recentTxnsAsync: recentTxnsAsync,
                    )
                  else
                    _buildMobileLayout(
                      context: context,
                      totalBalance: totalBalance,
                      hideAmounts: hideAmounts,
                      isDark: isDark,
                      accountsAsync: accountsAsync,
                      monthlyFlowAsync: monthlyFlowAsync,
                      recentTxnsAsync: recentTxnsAsync,
                    ),

                  const SizedBox(height: 80), // bottom space for FAB
                ],
              ),
            );
          },
        ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: onOpenAddTransaction,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  // --- Header Greeting ---
  Widget _buildUserGreeting(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, Michaela! 👋',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Here is your financial overview for this month.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Top 3 KPI Sparkline Cards ---
  Widget _buildTopKpiCards({
    required BuildContext context,
    required MonthlyFlow flow,
    required bool isDark,
    required bool hideAmounts,
    required bool isWide,
  }) {
    final incomeVal = flow.income > 0 ? flow.income : 6558.67;
    final expenseVal = flow.expense > 0 ? flow.expense : 1420.05;
    final investmentVal = (flow.income - flow.expense) > 0
        ? (flow.income - flow.expense)
        : 950.35;

    final cards = [
      _buildSparklineCard(
        title: 'Income',
        amount: incomeVal,
        trend: '↗ +16%',
        accentColor: AppColors.income,
        spots: const [
          FlSpot(0, 10),
          FlSpot(1, 18),
          FlSpot(2, 12),
          FlSpot(3, 24),
          FlSpot(4, 19),
          FlSpot(5, 30),
          FlSpot(6, 25),
        ],
        isDark: isDark,
        hideAmount: hideAmounts,
      ),
      _buildSparklineCard(
        title: 'Expenses',
        amount: expenseVal,
        trend: '↘ -36%',
        accentColor: AppColors.expense,
        spots: const [
          FlSpot(0, 24),
          FlSpot(1, 19),
          FlSpot(2, 28),
          FlSpot(3, 16),
          FlSpot(4, 22),
          FlSpot(5, 14),
          FlSpot(6, 12),
        ],
        isDark: isDark,
        hideAmount: hideAmounts,
      ),
      _buildSparklineCard(
        title: 'Investment',
        amount: investmentVal,
        trend: '↗ +12%',
        accentColor: AppColors.investment,
        spots: const [
          FlSpot(0, 14),
          FlSpot(1, 16),
          FlSpot(2, 15),
          FlSpot(3, 22),
          FlSpot(4, 20),
          FlSpot(5, 27),
          FlSpot(6, 32),
        ],
        isDark: isDark,
        hideAmount: hideAmounts,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          SizedBox(width: 250, child: cards[0]),
          const SizedBox(width: 14),
          SizedBox(width: 250, child: cards[1]),
          const SizedBox(width: 14),
          SizedBox(width: 250, child: cards[2]),
        ],
      ),
    );
  }

  Widget _buildSparklineCard({
    required String title,
    required double amount,
    required String trend,
    required Color accentColor,
    required List<FlSpot> spots,
    required bool isDark,
    required bool hideAmount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppStyles.roundedL,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
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
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'this month',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(amount, hideAmount: hideAmount),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: accentColor,
                    barWidth: 2.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.35),
                          accentColor.withValues(alpha: 0.0),
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
    );
  }

  // --- Responsive Desktop Layout ---
  Widget _buildWideLayout({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmounts,
    required bool isDark,
    required AsyncValue<List<dynamic>> accountsAsync,
    required AsyncValue<MonthlyFlow> monthlyFlowAsync,
    required AsyncValue<List<dynamic>> recentTxnsAsync,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Charts & Transactions)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildRevenueAnalysisCard(isDark),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildExpensesDonutCard(
                      context: context,
                      totalExpense: monthlyFlowAsync.maybeWhen(
                        data: (f) => f.expense,
                        orElse: () => 1525.61,
                      ),
                      hideAmount: hideAmounts,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTransactionsSection(
                      context: context,
                      recentTxnsAsync: recentTxnsAsync,
                      hideAmounts: hideAmounts,
                      isDark: isDark,
                      onViewAll: () => onNavigate('/transactions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right Column (My cards & Quick actions)
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildMyCardsSection(
                context: context,
                totalBalance: totalBalance,
                hideAmount: hideAmounts,
                isDark: isDark,
                accountsAsync: accountsAsync,
                onAddCard: () => onNavigate('/accounts'),
              ),
              const SizedBox(height: 20),
              _buildQuickTransfersAndGoals(
                context: context,
                isDark: isDark,
                onNavigate: onNavigate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Responsive Mobile Layout ---
  Widget _buildMobileLayout({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmounts,
    required bool isDark,
    required AsyncValue<List<dynamic>> accountsAsync,
    required AsyncValue<MonthlyFlow> monthlyFlowAsync,
    required AsyncValue<List<dynamic>> recentTxnsAsync,
  }) {
    return Column(
      children: [
        // 1. My cards Floating Mesh Card
        _buildMyCardsSection(
          context: context,
          totalBalance: totalBalance,
          hideAmount: hideAmounts,
          isDark: isDark,
          accountsAsync: accountsAsync,
          onAddCard: () => onNavigate('/accounts'),
        ),
        const SizedBox(height: 22),

        // 2. Revenue analysis Dual Spline Wave Chart
        _buildRevenueAnalysisCard(isDark),
        const SizedBox(height: 22),

        // 3. Expenses Breakdown Donut Card
        _buildExpensesDonutCard(
          context: context,
          totalExpense: monthlyFlowAsync.maybeWhen(
            data: (f) => f.expense,
            orElse: () => 1525.61,
          ),
          hideAmount: hideAmounts,
          isDark: isDark,
        ),
        const SizedBox(height: 22),

        // 4. Recent Transactions
        _buildTransactionsSection(
          context: context,
          recentTxnsAsync: recentTxnsAsync,
          hideAmounts: hideAmounts,
          isDark: isDark,
          onViewAll: () => onNavigate('/transactions'),
        ),
        const SizedBox(height: 22),

        // 5. Quick Transfers & Goals
        _buildQuickTransfersAndGoals(
          context: context,
          isDark: isDark,
          onNavigate: onNavigate,
        ),
      ],
    );
  }

  // --- "My cards" Stacked Mesh Gradient Card ---
  Widget _buildMyCardsSection({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmount,
    required bool isDark,
    required AsyncValue<List<dynamic>> accountsAsync,
    required VoidCallback onAddCard,
  }) {
    final primaryAccount = accountsAsync.maybeWhen(
      data: (accs) => accs.isNotEmpty ? accs.first : null,
      orElse: () => null,
    );
    final cardHolder = primaryAccount != null ? primaryAccount.name : 'Michaela Evans';
    final cardNumber = primaryAccount?.accountNumberMask != null
        ? '•••• •••• •••• ${primaryAccount.accountNumberMask}'
        : '4654 5367 4055 0556';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My cards',
              style: AppStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            InkWell(
              onTap: onAddCard,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'add card +',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Background peeking card (sunset gradient)
            Positioned(
              right: 0,
              top: 14,
              bottom: -6,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradientSunset,
                  borderRadius: AppStyles.roundedL,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3DF43F5E),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            // Foreground primary card (Cyan-to-Purple Mesh Gradient)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradientCyanPurple,
                borderRadius: AppStyles.roundedL,
                boxShadow: AppStyles.heroGlowShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(
                              totalBalance > 0 ? totalBalance : 5089.56,
                              hideAmount: hideAmount,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'VISA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    cardNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cardHolder,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '05/28',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.contactless_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Pagination dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Revenue Analysis Dual Spline Wave Chart ---
  Widget _buildRevenueAnalysisCard(bool isDark) {
    return Container(
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
                'Revenue analysis',
                style: AppStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegendItem(
                    color: AppColors.income,
                    label: 'Income',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildLegendItem(
                    color: AppColors.expense,
                    label: 'Expenses',
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : AppColors.lightBorder,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          '₹${val.toInt()}k',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun',
                          'Jul',
                          'Aug',
                          'Sep',
                          'Oct',
                          'Nov',
                          'Dec'
                        ];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(
                            months[idx],
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextSecondary,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income Line (Cyan)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 10),
                      FlSpot(1, 14),
                      FlSpot(2, 8),
                      FlSpot(3, 15),
                      FlSpot(4, 12),
                      FlSpot(5, 18),
                      FlSpot(6, 11),
                      FlSpot(7, 14),
                      FlSpot(8, 9),
                      FlSpot(9, 13),
                      FlSpot(10, 10),
                      FlSpot(11, 16),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.income,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.income.withValues(alpha: 0.25),
                          AppColors.income.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Expenses Line (Pink)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 7),
                      FlSpot(1, 11),
                      FlSpot(2, 13),
                      FlSpot(3, 9),
                      FlSpot(4, 16),
                      FlSpot(5, 10),
                      FlSpot(6, 6),
                      FlSpot(7, 8),
                      FlSpot(8, 12),
                      FlSpot(9, 7),
                      FlSpot(10, 11),
                      FlSpot(11, 14),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.expense,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.expense.withValues(alpha: 0.2),
                          AppColors.expense.withValues(alpha: 0.0),
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
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  // --- Expenses Breakdown Donut Card ---
  Widget _buildExpensesDonutCard({
    required BuildContext context,
    required double totalExpense,
    required bool hideAmount,
    required bool isDark,
  }) {
    final displayAmount = totalExpense > 0 ? totalExpense : 1525.61;

    final categories = [
      _DonutCategory(
          name: 'Supermarkets',
          amount: 186.65,
          color: const Color(0xFF00D2FF)),
      _DonutCategory(
          name: 'Transfers', amount: 207.82, color: const Color(0xFF38BDF8)),
      _DonutCategory(
          name: 'Restaurants', amount: 197.25, color: const Color(0xFF8B5CF6)),
      _DonutCategory(
          name: 'Cash', amount: 340.00, color: const Color(0xFFEC4899)),
      _DonutCategory(
          name: 'Study', amount: 500.85, color: const Color(0xFFF43F5E)),
      _DonutCategory(
          name: 'Other', amount: 93.04, color: const Color(0xFFFB923C)),
    ];

    return Container(
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
                'Expenses',
                style: AppStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'last week',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Donut Chart with Center Total
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
                        sections: categories.map((cat) {
                          return PieChartSectionData(
                            value: cat.amount,
                            color: cat.color,
                            radius: 16,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCompact(displayAmount,
                          hideAmount: hideAmount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Category Legend Items
              Expanded(
                child: Column(
                  children: categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(cat.amount,
                                hideAmount: hideAmount),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'You have spent 16% less money this week than last week.',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Recent Transactions Widget ---
  Widget _buildTransactionsSection({
    required BuildContext context,
    required AsyncValue<List<dynamic>> recentTxnsAsync,
    required bool hideAmounts,
    required bool isDark,
    required VoidCallback onViewAll,
  }) {
    return Container(
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
                'Transactions',
                style: AppStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'today',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          recentTxnsAsync.when(
            data: (txns) {
              if (txns.isEmpty) {
                // Realistic preview matching reference design
                final sampleTxns = [
                  _SampleTxn(
                    name: 'Alex T.',
                    subtitle: 'Transfers',
                    amount: 300.00,
                    isExpense: false,
                    method: 'Debit card',
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFF38BDF8),
                  ),
                  _SampleTxn(
                    name: 'Uber',
                    subtitle: 'Taxi',
                    amount: 19.84,
                    isExpense: true,
                    method: 'Debit card',
                    icon: Icons.directions_car_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                  _SampleTxn(
                    name: 'Metro',
                    subtitle: 'Supermarkets',
                    amount: 85.29,
                    isExpense: true,
                    method: 'Debit card',
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFFFB923C),
                  ),
                  _SampleTxn(
                    name: 'Cashback',
                    subtitle: 'Rewards',
                    amount: 4.50,
                    isExpense: false,
                    method: 'Debit card',
                    icon: Icons.redeem_rounded,
                    iconColor: const Color(0xFF00D2FF),
                  ),
                ];
                return Column(
                  children: sampleTxns
                      .map((s) => _buildTransactionItem(
                            icon: s.icon,
                            iconColor: s.iconColor,
                            name: s.name,
                            subtitle: s.subtitle,
                            amount: s.amount,
                            isExpense: s.isExpense,
                            method: s.method,
                            isDark: isDark,
                            hideAmount: hideAmounts,
                          ))
                      .toList(),
                );
              }
              return Column(
                children: txns.map((t) {
                  final isExpense = t.type == 'expense';
                  return _buildTransactionItem(
                    icon: isExpense
                        ? Icons.shopping_bag_outlined
                        : Icons.account_balance_wallet_outlined,
                    iconColor: isExpense ? AppColors.expense : AppColors.income,
                    name: t.merchantName ?? (isExpense ? 'Expense' : 'Income'),
                    subtitle: t.note ?? (isExpense ? 'Payment' : 'Deposit'),
                    amount: t.amount,
                    isExpense: isExpense,
                    method: t.paymentType.toUpperCase(),
                    isDark: isDark,
                    hideAmount: hideAmounts,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(height: 10),
          // Pagination dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required String name,
    required String subtitle,
    required double amount,
    required bool isExpense,
    required String method,
    required bool isDark,
    required bool hideAmount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
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
                '${isExpense ? '-' : '+'}${CurrencyFormatter.format(amount, hideAmount: hideAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
              Text(
                method,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Quick Transfers & Goals ---
  Widget _buildQuickTransfersAndGoals({
    required BuildContext context,
    required bool isDark,
    required ValueChanged<String> onNavigate,
  }) {
    return Column(
      children: [
        // Quick Transaction Card
        Container(
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
                    'Quick Transaction',
                    style: AppStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () => onNavigate('/transactions'),
                    child: Text(
                      'add +',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildContactTile(
                initial: 'A',
                name: 'Alexander Abramson',
                accountMask: '•••• 1676',
                avatarColor: const Color(0xFF6366F1),
                isDark: isDark,
              ),
              _buildContactTile(
                initial: 'J',
                name: 'Julia Davidson',
                accountMask: '•••• 2675',
                avatarColor: const Color(0xFF00D2FF),
                isDark: isDark,
              ),
              _buildContactTile(
                initial: 'A',
                name: 'Andrew Evans',
                accountMask: '•••• 0987',
                avatarColor: const Color(0xFFEC4899),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Goals Card
        Container(
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
                    'Goals',
                    style: AppStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () => onNavigate('/budgets'),
                    child: Text(
                      'add goal +',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildGoalProgress(
                icon: Icons.flight_takeoff_rounded,
                title: 'Trip',
                saved: 10576,
                target: 20000,
                gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildGoalProgress(
                icon: Icons.home_rounded,
                title: 'House',
                saved: 54637,
                target: 180000,
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)]),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildGoalProgress(
                icon: Icons.camera_alt_rounded,
                title: 'Camera',
                saved: 983.75,
                target: 4650,
                gradient: const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF38BDF8)]),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required String initial,
    required String name,
    required String accountMask,
    required Color avatarColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: avatarColor.withValues(alpha: 0.2),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: avatarColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  accountMask,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress({
    required IconData icon,
    required String title,
    required double saved,
    required double target,
    required LinearGradient gradient,
    required bool isDark,
  }) {
    final progress = (saved / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '₹${saved.toInt()} / ₹${target.toInt()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            width: double.infinity,
            color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutCategory {
  final String name;
  final double amount;
  final Color color;
  const _DonutCategory({
    required this.name,
    required this.amount,
    required this.color,
  });
}

class _SampleTxn {
  final String name;
  final String subtitle;
  final double amount;
  final bool isExpense;
  final String method;
  final IconData icon;
  final Color iconColor;
  const _SampleTxn({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.method,
    required this.icon,
    required this.iconColor,
  });
}

