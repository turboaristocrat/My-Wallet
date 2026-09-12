import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../data/reports_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const ReportsScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _touchedPieIndex = -1;

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_basket':
        return Icons.shopping_basket_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final reportAsync = ref.watch(financialReportStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/analytics',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Analytics & Reports',
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
      body: Column(
        children: [
          // Time Period Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildRangePill('This Month', 'this_month', selectedRange, isDark),
                const SizedBox(width: 8),
                _buildRangePill('Last Month', 'last_month', selectedRange, isDark),
                const SizedBox(width: 8),
                _buildRangePill('Last 30 Days', 'last_30_days', selectedRange, isDark),
                const SizedBox(width: 8),
                _buildRangePill('This Year', 'this_year', selectedRange, isDark),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
          ),

          // Main Report Content
          Expanded(
            child: reportAsync.when(
              data: (report) {
                if (report.totalIncome == 0 && report.totalExpense == 0) {
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
                              Icons.analytics_rounded,
                              size: 54,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No Data for This Period',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add transactions or switch to another date range to see your analytics.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    // 1. Savings Rate & Cash Flow Hero Card
                    _buildSavingsRateCard(report, isDark, hideAmounts),
                    const SizedBox(height: 20),

                    // 2. Income vs Expense Comparison Bar Chart
                    _buildIncomeVsExpenseChart(report, isDark, hideAmounts),
                    const SizedBox(height: 20),

                    // 3. Category Spending Donut Chart
                    if (report.categoryBreakdown.isNotEmpty) ...[
                      _buildCategoryDonutCard(report, isDark, hideAmounts),
                      const SizedBox(height: 20),
                    ],

                    // 4. Category Spending Ranking List
                    if (report.categoryBreakdown.isNotEmpty) ...[
                      _buildCategoryRankingsList(report, isDark, hideAmounts),
                      const SizedBox(height: 20),
                    ],

                    // 5. Daily Spending Trendline Chart
                    if (report.dailyExpenses.isNotEmpty) ...[
                      _buildDailySpendingChart(report, isDark, hideAmounts),
                      const SizedBox(height: 20),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading report: $err')),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Savings Rate Hero Card
  Widget _buildSavingsRateCard(FinancialReport report, bool isDark, bool hideAmounts) {
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'SAVINGS RATE',
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
              Text(
                '${report.savingsRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.income,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Progress for Savings Rate
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (report.savingsRate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.income),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
          const SizedBox(height: 16),

          // Three Pillars: Income, Expense, Net Savings
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(report.totalIncome, hideAmount: hideAmounts),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(report.totalExpense, hideAmount: hideAmounts),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Saved',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(report.netSavings, hideAmount: hideAmounts),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: report.netSavings >= 0 ? AppColors.income : AppColors.expense,
                      ),
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

  // 2. Income vs Expense Double Bar Chart
  Widget _buildIncomeVsExpenseChart(FinancialReport report, bool isDark, bool hideAmounts) {
    final maxVal = (report.totalIncome > report.totalExpense ? report.totalIncome : report.totalExpense) * 1.25;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
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
                'Income vs Expense',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegendIndicator('Income', AppColors.income),
                  const SizedBox(width: 12),
                  _buildLegendIndicator('Expense', AppColors.expense),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxVal > 0 ? maxVal : 1000,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? AppColors.darkSurface : Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '${isIncome ? "Income" : "Expense"}\n${CurrencyFormatter.format(rod.toY, hideAmount: hideAmounts)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Period Total',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barsSpace: 12,
                    barRods: [
                      BarChartRodData(
                        toY: report.totalIncome,
                        color: AppColors.income,
                        width: 32,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      BarChartRodData(
                        toY: report.totalExpense,
                        color: AppColors.expense,
                        width: 32,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Category Spending Donut Chart
  Widget _buildCategoryDonutCard(FinancialReport report, bool isDark, bool hideAmounts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppStyles.roundedL,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex =
                              pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    sections: report.categoryBreakdown.asMap().entries.map((entry) {
                      final i = entry.key;
                      final cat = entry.value;
                      final isTouched = i == _touchedPieIndex;
                      final fontSize = isTouched ? 14.0 : 11.0;
                      final radius = isTouched ? 36.0 : 28.0;
                      final color = Color(int.tryParse(cat.colorHex) ?? 0xFF8B5CF6);

                      return PieChartSectionData(
                        color: color,
                        value: cat.totalAmount,
                        title: '${cat.percentage.toStringAsFixed(0)}%',
                        radius: radius,
                        titleStyle: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL SPENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(report.totalExpense, hideAmount: hideAmounts),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Category Rankings List
  Widget _buildCategoryRankingsList(FinancialReport report, bool isDark, bool hideAmounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'TOP CATEGORIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        ...report.categoryBreakdown.map((cat) {
          final color = Color(int.tryParse(cat.colorHex) ?? 0xFF8B5CF6);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppStyles.roundedM,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: AppStyles.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.16),
                      child: Icon(_getCategoryIcon(cat.iconName), color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat.categoryName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(cat.totalAmount, hideAmount: hideAmounts),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cat.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightDivider,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${cat.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 5. Daily Spending Trendline
  Widget _buildDailySpendingChart(FinancialReport report, bool isDark, bool hideAmounts) {
    final sortedDays = report.dailyExpenses.keys.toList()..sort();
    if (sortedDays.isEmpty) return const SizedBox();

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDays.length; i++) {
      spots.add(FlSpot(i.toDouble(), report.dailyExpenses[sortedDays[i]]!));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppStyles.roundedL,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Spending Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.expense,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.expense.withValues(alpha: 0.35),
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

  Widget _buildRangePill(String label, String value, String currentSelected, bool isDark) {
    final isSelected = currentSelected == value;
    return GestureDetector(
      onTap: () => ref.read(selectedDateRangeProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: isSelected ? AppStyles.heroGlowShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
