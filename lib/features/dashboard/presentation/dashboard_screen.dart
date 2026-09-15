import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../auth/presentation/lock_screen.dart';
import '../../budgets/data/budget_repository.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../reports/data/reports_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../data/dashboard_config.dart';
import '../data/dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenAddTransaction;
  final ValueChanged<String> onNavigate;

  const DashboardScreen({
    super.key,
    required this.onOpenAddTransaction,
    required this.onNavigate,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _kpiPageController;
  late final AnimationController _cardAnimController;
  Animation<double>? _cardSlideAnimation;
  int _kpiPageIndex = 0;
  int _accountsPageIndex = 0;
  double _dragDx = 0.0;
  bool _isCardAnimating = false;

  static const List<LinearGradient> _accountCardGradients = [
    AppColors.cardGradientCyanPurple,
    AppColors.cardGradientSunset,
    AppColors.cardGradientViolet,
    LinearGradient(
      colors: [Color(0xFF0D9488), Color(0xFF10B981), Color(0xFF34D399)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _kpiPageController = PageController();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadProfileName();
  }

  Future<void> _loadProfileName() async {
    final storage = ref.read(secureStorageProvider);
    final name = await storage.read(key: 'user_profile_name');
    if (name != null && name.isNotEmpty && mounted) {
      ref.read(userProfileNameProvider.notifier).state = name;
    }
  }

  void _onCardDragUpdate(DragUpdateDetails details) {
    if (_isCardAnimating) return;
    setState(() {
      _dragDx += details.primaryDelta ?? 0.0;
    });
  }

  void _onCardDragEnd(DragEndDetails details, double cardWidth, int totalCount) {
    if (_isCardAnimating || totalCount <= 1) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final progress = _dragDx / cardWidth;

    if (progress < -0.18 || velocity < -240) {
      _animateCard(
        from: _dragDx,
        to: -cardWidth,
        onComplete: () {
          setState(() {
            _accountsPageIndex = (_accountsPageIndex + 1) % totalCount;
            _dragDx = 0.0;
          });
        },
      );
    } else if (progress > 0.18 || velocity > 240) {
      _animateCard(
        from: _dragDx,
        to: cardWidth,
        onComplete: () {
          setState(() {
            _accountsPageIndex =
                (_accountsPageIndex - 1 + totalCount) % totalCount;
            _dragDx = 0.0;
          });
        },
      );
    } else {
      _animateCard(
        from: _dragDx,
        to: 0.0,
        onComplete: () {
          setState(() {
            _dragDx = 0.0;
          });
        },
      );
    }
  }

  void _animateCard({
    required double from,
    required double to,
    required VoidCallback onComplete,
  }) {
    _isCardAnimating = true;
    _cardSlideAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _cardAnimController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        setState(() {
          _dragDx = _cardSlideAnimation!.value;
        });
      });

    _cardAnimController.forward(from: 0.0).then((_) {
      _isCardAnimating = false;
      onComplete();
    });
  }

  void _advanceToNextCard(double cardWidth, int totalCount) {
    if (_isCardAnimating || totalCount <= 1) return;
    _animateCard(
      from: 0.0,
      to: -cardWidth,
      onComplete: () {
        setState(() {
          _accountsPageIndex = (_accountsPageIndex + 1) % totalCount;
          _dragDx = 0.0;
        });
      },
    );
  }

  void _openAddTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _kpiPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyFlowAsync = ref.watch(monthlyFlowProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final recentTxnsAsync = ref.watch(recentTransactionsStreamProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final pendingCount = ref.watch(pendingQueueCountProvider);
    final dashboardConfig = ref.watch(dashboardConfigProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/dashboard',
        onNavigate: widget.onNavigate,
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
          IconButton(
            tooltip: 'Customize Dashboard',
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: () => _showConfigureDashboardSheet(context),
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
                onPressed: () => widget.onNavigate('/inbox'),
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
          IconButton(
            tooltip: 'AI Financial Copilot',
            icon: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            onPressed: () => widget.onNavigate('/copilot'),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => widget.onNavigate('/settings'),
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
                  if (dashboardConfig.showKpiCards) ...[
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
                  ],

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
                      config: dashboardConfig,
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
                      config: dashboardConfig,
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
          onPressed: _openAddTransaction,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  void _showConfigureDashboardSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (sheetCtx, sheetRef, _) {
            final config = sheetRef.watch(dashboardConfigProvider);
            final notifier = sheetRef.read(dashboardConfigProvider.notifier);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Customize Dashboard',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => notifier.resetDefaults(),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose which sections and cards appear on your dashboard.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildConfigSwitch(
                      title: 'Top KPI Stat Cards',
                      subtitle: 'Income, Expenses, Net Savings sparklines',
                      icon: Icons.show_chart_rounded,
                      value: config.showKpiCards,
                      onChanged: (_) =>
                          notifier.toggleWidget(DashboardWidgetType.kpiCards),
                      isDark: isDark,
                    ),
                    _buildConfigSwitch(
                      title: 'My Accounts',
                      subtitle: 'Card carousel and account balances',
                      icon: Icons.account_balance_wallet_rounded,
                      value: config.showMyAccounts,
                      onChanged: (_) =>
                          notifier.toggleWidget(DashboardWidgetType.myAccounts),
                      isDark: isDark,
                    ),
                    _buildConfigSwitch(
                      title: 'Revenue Analysis',
                      subtitle: 'Dual wave spline cashflow chart',
                      icon: Icons.stacked_line_chart_rounded,
                      value: config.showRevenueAnalysis,
                      onChanged: (_) => notifier
                          .toggleWidget(DashboardWidgetType.revenueAnalysis),
                      isDark: isDark,
                    ),
                    _buildConfigSwitch(
                      title: 'Expense Breakdown Donut',
                      subtitle: 'Interactive category breakdown donut',
                      icon: Icons.donut_large_rounded,
                      value: config.showExpenseDonut,
                      onChanged: (_) => notifier
                          .toggleWidget(DashboardWidgetType.expenseDonut),
                      isDark: isDark,
                    ),
                    _buildConfigSwitch(
                      title: 'Recent Transactions',
                      subtitle: 'Latest financial activity stream',
                      icon: Icons.receipt_long_rounded,
                      value: config.showRecentTransactions,
                      onChanged: (_) => notifier
                          .toggleWidget(DashboardWidgetType.recentTransactions),
                      isDark: isDark,
                    ),
                    _buildConfigSwitch(
                      title: 'Quick Transfers & Goals',
                      subtitle: 'Direct peer transfers and savings goals',
                      icon: Icons.savings_rounded,
                      value: config.showQuickTransfer || config.showGoals,
                      onChanged: (_) {
                        notifier
                            .toggleWidget(DashboardWidgetType.quickTransfer);
                        notifier.toggleWidget(DashboardWidgetType.goals);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConfigSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.4)
                : AppColors.lightBorder.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  // --- Header Greeting ---
  Widget _buildUserGreeting(bool isDark) {
    final customName = ref.watch(userProfileNameProvider);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    final titleText = customName.trim().isNotEmpty
        ? '$greeting, $customName! 👋'
        : '$greeting! 👋';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
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

  // --- Top KPI Sparkline Cards (Dual Income/Expense + Swipable Investment) ---
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
    final netSavingsVal = flow.income - flow.expense;

    final incomeCard = _buildSparklineCard(
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
      isCompact: !isWide,
      onTap: () => widget.onNavigate('/analytics'),
    );

    final expenseCard = _buildSparklineCard(
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
      isCompact: !isWide,
      onTap: () => widget.onNavigate('/analytics'),
    );

    final investmentCard = _buildSparklineCard(
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
      isCompact: !isWide,
      onTap: () => widget.onNavigate('/investments'),
    );

    final netSavingsCard = _buildSparklineCard(
      title: 'Net Savings',
      amount: netSavingsVal != 0 ? netSavingsVal.abs() : 5138.62,
      trend: netSavingsVal >= 0 ? '↗ Surplus' : '↘ Deficit',
      accentColor: AppColors.incomeGreen,
      spots: const [
        FlSpot(0, 12),
        FlSpot(1, 15),
        FlSpot(2, 18),
        FlSpot(3, 17),
        FlSpot(4, 23),
        FlSpot(5, 26),
        FlSpot(6, 30),
      ],
      isDark: isDark,
      hideAmount: hideAmounts,
      isCompact: !isWide,
      onTap: () => widget.onNavigate('/analytics'),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: incomeCard),
          const SizedBox(width: 14),
          Expanded(child: expenseCard),
          const SizedBox(width: 14),
          Expanded(child: investmentCard),
          const SizedBox(width: 14),
          Expanded(child: netSavingsCard),
        ],
      );
    }

    // On mobile: Income and Expense cards together fully visible on Page 0!
    // Investment card is one swipe away on Page 1.
    return Column(
      children: [
        SizedBox(
          height: 154,
          child: PageView(
            controller: _kpiPageController,
            onPageChanged: (idx) {
              setState(() {
                _kpiPageIndex = idx;
              });
            },
            children: [
              // Page 0: Income & Expense cards side-by-side fully visible
              Row(
                children: [
                  Expanded(child: incomeCard),
                  const SizedBox(width: 10),
                  Expanded(child: expenseCard),
                ],
              ),
              // Page 1: Investment & Net Savings cards side-by-side (one swipe away)
              Row(
                children: [
                  Expanded(child: investmentCard),
                  const SizedBox(width: 10),
                  Expanded(child: netSavingsCard),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Swiping Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _kpiPageIndex == 0 ? 16 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _kpiPageIndex == 0
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _kpiPageIndex == 1 ? 16 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: _kpiPageIndex == 1
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ],
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
    bool isCompact = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppStyles.roundedL,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.roundedL,
        child: Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        isCompact ? 12 : 16,
        isCompact ? 12 : 16,
        isCompact ? 8 : 8,
      ),
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (!isCompact)
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
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount, hideAmount: hideAmount),
              style: TextStyle(
                fontSize: isCompact ? 18 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ),
          if (!isCompact) ...[
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
          ],
          SizedBox(height: isCompact ? 6 : 10),
          SizedBox(
            height: isCompact ? 36 : 44,
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
    ),
  ),
);
  }

  // --- Responsive Desktop Layout ---
  Widget _buildWideLayout({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmounts,
    required bool isDark,
    required AsyncValue<List<Account>> accountsAsync,
    required AsyncValue<MonthlyFlow> monthlyFlowAsync,
    required AsyncValue<List<dynamic>> recentTxnsAsync,
    required DashboardConfig config,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Charts & Transactions)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              if (config.showRevenueAnalysis) ...[
                _buildRevenueAnalysisCard(isDark),
                const SizedBox(height: 20),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (config.showExpenseDonut)
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
                  if (config.showExpenseDonut && config.showRecentTransactions)
                    const SizedBox(width: 16),
                  if (config.showRecentTransactions)
                    Expanded(
                      child: _buildTransactionsSection(
                        context: context,
                        recentTxnsAsync: recentTxnsAsync,
                        hideAmounts: hideAmounts,
                        isDark: isDark,
                        onViewAll: () => widget.onNavigate('/transactions'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (config.showMyAccounts ||
            config.showQuickTransfer ||
            config.showGoals) ...[
          const SizedBox(width: 20),
          // Right Column (My Accounts & Quick actions)
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (config.showMyAccounts) ...[
                  _buildMyAccountsSection(
                    context: context,
                    totalBalance: totalBalance,
                    hideAmount: hideAmounts,
                    isDark: isDark,
                    accountsAsync: accountsAsync,
                    onAddAccount: () => widget.onNavigate('/accounts'),
                  ),
                  const SizedBox(height: 20),
                ],
                if (config.showQuickTransfer || config.showGoals)
                  _buildQuickTransfersAndGoals(
                    context: context,
                    isDark: isDark,
                    onNavigate: widget.onNavigate,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Responsive Mobile Layout ---
  Widget _buildMobileLayout({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmounts,
    required bool isDark,
    required AsyncValue<List<Account>> accountsAsync,
    required AsyncValue<MonthlyFlow> monthlyFlowAsync,
    required AsyncValue<List<dynamic>> recentTxnsAsync,
    required DashboardConfig config,
  }) {
    return Column(
      children: [
        // 1. My Accounts Section (Swiping Card Carousel vs All Tiles)
        if (config.showMyAccounts) ...[
          _buildMyAccountsSection(
            context: context,
            totalBalance: totalBalance,
            hideAmount: hideAmounts,
            isDark: isDark,
            accountsAsync: accountsAsync,
            onAddAccount: () => widget.onNavigate('/accounts'),
          ),
          const SizedBox(height: 22),
        ],

        // 2. Revenue analysis Dual Spline Wave Chart
        if (config.showRevenueAnalysis) ...[
          _buildRevenueAnalysisCard(isDark),
          const SizedBox(height: 22),
        ],

        // 3. Expenses Breakdown Donut Card
        if (config.showExpenseDonut) ...[
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
        ],

        // 4. Recent Transactions
        if (config.showRecentTransactions) ...[
          _buildTransactionsSection(
            context: context,
            recentTxnsAsync: recentTxnsAsync,
            hideAmounts: hideAmounts,
            isDark: isDark,
            onViewAll: () => widget.onNavigate('/transactions'),
          ),
          const SizedBox(height: 22),
        ],

        // 5. Quick Transfers & Goals
        if (config.showQuickTransfer || config.showGoals) ...[
          _buildQuickTransfersAndGoals(
            context: context,
            isDark: isDark,
            onNavigate: widget.onNavigate,
          ),
        ],
      ],
    );
  }

  // --- "My Accounts" Section with Carousel & Tiles Switcher ---
  Widget _buildMyAccountsSection({
    required BuildContext context,
    required double totalBalance,
    required bool hideAmount,
    required bool isDark,
    required AsyncValue<List<Account>> accountsAsync,
    required VoidCallback onAddAccount,
  }) {
    final displayMode = ref.watch(accountsDisplayModeProvider);
    final accounts = accountsAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Accounts',
              style: AppStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Mode Toggle (Card Carousel vs All Tiles)
                Container(
                  padding: const EdgeInsets.all(2),
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
                      _buildDisplayModeTab(
                        icon: Icons.view_carousel_rounded,
                        tooltip: 'Card Swiping',
                        isSelected:
                            displayMode == AccountsDisplayMode.carousel,
                        isDark: isDark,
                        onTap: () {
                          ref
                              .read(accountsDisplayModeProvider.notifier)
                              .state = AccountsDisplayMode.carousel;
                        },
                      ),
                      const SizedBox(width: 2),
                      _buildDisplayModeTab(
                        icon: Icons.grid_view_rounded,
                        tooltip: 'All Tiles',
                        isSelected: displayMode == AccountsDisplayMode.tiles,
                        isDark: isDark,
                        onTap: () {
                          ref
                              .read(accountsDisplayModeProvider.notifier)
                              .state = AccountsDisplayMode.tiles;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Add Account',
                  child: InkWell(
                    onTap: onAddAccount,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Display Mode Content
        if (displayMode == AccountsDisplayMode.carousel)
          _buildAccountsCarousel(
            accounts: accounts,
            totalBalance: totalBalance,
            hideAmount: hideAmount,
            isDark: isDark,
            onAddAccount: onAddAccount,
          )
        else
          _buildAccountsTiles(
            accounts: accounts,
            hideAmount: hideAmount,
            isDark: isDark,
            onAddAccount: onAddAccount,
          ),
      ],
    );
  }

  Widget _buildDisplayModeTab({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
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

  Widget _buildAccountsCarousel({
    required List<Account> accounts,
    required double totalBalance,
    required bool hideAmount,
    required bool isDark,
    required VoidCallback onAddAccount,
  }) {
    if (accounts.isEmpty) {
      return GestureDetector(
        onTap: onAddAccount,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: 14,
              bottom: -6,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  gradient: _accountCardGradients[1],
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                gradient: _accountCardGradients[0],
                borderRadius: AppStyles.roundedL,
                boxShadow: AppStyles.heroGlowShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(
                              totalBalance > 0 ? totalBalance : 0.0,
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
                          'WALLET',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'No Accounts Linked Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tap here to add an account',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
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

    if (accounts.length == 1) {
      return GestureDetector(
        onTap: () => widget.onNavigate('/accounts'),
        child: SizedBox(
          width: double.infinity,
          height: 200,
          child: _buildAccountCardItem(accounts.first, 0, hideAmount),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              const double peekWidth = 18.0;
              final cardWidth = totalWidth - peekWidth;
              final totalCount = accounts.length;

              // Ensure index is within range
              if (_accountsPageIndex >= totalCount) {
                _accountsPageIndex = 0;
              }

              final currentIndex = _accountsPageIndex;
              final nextIndex = (currentIndex + 1) % totalCount;
              final prevIndex = (currentIndex - 1 + totalCount) % totalCount;

              final List<Widget> stackCards = [];

              if (_dragDx <= 0) {
                // Dragging LEFT (or idle): Current card on top, Next card underneath peeking on the right
                final t = (-_dragDx / cardWidth).clamp(0.0, 1.0);

                // 1. Third card (if totalCount > 2) tucked further behind
                if (totalCount > 2) {
                  final thirdIndex = (currentIndex + 2) % totalCount;
                  stackCards.add(
                    Positioned(
                      left: peekWidth,
                      top: 6,
                      bottom: 6,
                      width: cardWidth,
                      child: Opacity(
                        opacity: t.clamp(0.0, 0.8),
                        child: Transform.scale(
                          scale: 0.90 + 0.04 * t,
                          alignment: Alignment.centerRight,
                          child: _buildAccountCardItem(
                            accounts[thirdIndex],
                            thirdIndex,
                            hideAmount,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // 2. Next card: Underneath! Peeks 18px on the right when idle (t=0); scales up and slides into view as t -> 1
                final nextLeft = (1.0 - t) * peekWidth;
                final nextInset = (1.0 - t) * 6.0;
                final nextScale = 0.94 + (0.06 * t);

                stackCards.add(
                  Positioned(
                    left: nextLeft,
                    top: nextInset,
                    bottom: nextInset,
                    width: cardWidth,
                    child: Transform.scale(
                      scale: nextScale,
                      alignment: Alignment.centerRight,
                      child: _buildAccountCardItem(
                        accounts[nextIndex],
                        nextIndex,
                        hideAmount,
                      ),
                    ),
                  ),
                );

                // 3. Current card: ON TOP! Slides left as user drags
                final currentLeft = _dragDx;
                final currentOpacity = (1.0 - t * 0.35).clamp(0.0, 1.0);

                stackCards.add(
                  Positioned(
                    left: currentLeft,
                    top: 0,
                    bottom: 0,
                    width: cardWidth,
                    child: Opacity(
                      opacity: currentOpacity,
                      child: _buildAccountCardItem(
                        accounts[currentIndex],
                        currentIndex,
                        hideAmount,
                      ),
                    ),
                  ),
                );
              } else {
                // Dragging RIGHT: Previous card slides in from left OVER current card!
                final t = (_dragDx / cardWidth).clamp(0.0, 1.0);

                // 1. Current card: becomes underneath as previous card slides over it
                final currentScale = 1.0 - 0.06 * t;
                final currentInset = t * 6.0;
                final currentLeft = t * peekWidth;

                stackCards.add(
                  Positioned(
                    left: currentLeft,
                    top: currentInset,
                    bottom: currentInset,
                    width: cardWidth,
                    child: Transform.scale(
                      scale: currentScale,
                      alignment: Alignment.centerRight,
                      child: _buildAccountCardItem(
                        accounts[currentIndex],
                        currentIndex,
                        hideAmount,
                      ),
                    ),
                  ),
                );

                // 2. Previous card: ON TOP sliding in from left!
                final prevLeft = -cardWidth + _dragDx;
                final prevOpacity = (0.7 + 0.3 * t).clamp(0.0, 1.0);

                stackCards.add(
                  Positioned(
                    left: prevLeft,
                    top: 0,
                    bottom: 0,
                    width: cardWidth,
                    child: Opacity(
                      opacity: prevOpacity,
                      child: _buildAccountCardItem(
                        accounts[prevIndex],
                        prevIndex,
                        hideAmount,
                      ),
                    ),
                  ),
                );
              }

              // 4. Interactive Gesture detector covering the card stack
              stackCards.add(
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _onCardDragUpdate,
                    onHorizontalDragEnd: (details) =>
                        _onCardDragEnd(details, cardWidth, totalCount),
                    onTapUp: (details) {
                      if (details.localPosition.dx > totalWidth - 44) {
                        _advanceToNextCard(cardWidth, totalCount);
                      } else {
                        widget.onNavigate('/accounts');
                      }
                    },
                  ),
                ),
              );

              return Stack(
                clipBehavior: Clip.none,
                children: stackCards,
              );
            },
          ),
        ),
        if (accounts.length > 1) ...[
          const SizedBox(height: 12),
          // Swiping Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(accounts.length, (i) {
              final isCurrent = i == _accountsPageIndex;
              return GestureDetector(
                onTap: () {
                  if (i != _accountsPageIndex && !_isCardAnimating) {
                    setState(() {
                      _accountsPageIndex = i;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountCardItem(
    Account account,
    int index,
    bool hideAmount,
  ) {
    final gradient =
        _accountCardGradients[index % _accountCardGradients.length];
    final mask = account.accountNumberMask != null
        ? '•••• •••• •••• ${account.accountNumberMask}'
        : '•••• •••• •••• ${index.toString().padLeft(4, '0')}';
    final badgeLabel = account.type.toUpperCase().replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppStyles.roundedL,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(
                          account.balance,
                          hideAmount: hideAmount,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          Text(
            mask,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getAccountTypeIcon(account.type),
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getAccountTypeDisplayName(account.type),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.contactless_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTiles({
    required List<Account> accounts,
    required bool hideAmount,
    required bool isDark,
    required VoidCallback onAddAccount,
  }) {
    if (accounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppStyles.roundedL,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'No Accounts Linked',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your bank accounts, cards, or wallets to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Account'),
            ),
          ],
        ),
      );
    }

    // Responsive Grid of Account Tiles (2 columns) with same vibrant gradients as swipe cards
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.30,
      ),
      itemCount: accounts.length + 1, // +1 for "+ Add Account" tile
      itemBuilder: (context, index) {
        // Last item is the "+ Add Account" tile
        if (index == accounts.length) {
          return InkWell(
            onTap: onAddAccount,
            borderRadius: AppStyles.roundedL,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.6)
                    : AppColors.lightSurface,
                borderRadius: AppStyles.roundedL,
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: AppStyles.softShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final account = accounts[index];
        final gradient =
            _accountCardGradients[index % _accountCardGradients.length];
        final mask = account.accountNumberMask != null
            ? '•••• ${account.accountNumberMask}'
            : '•••• ${index.toString().padLeft(4, '0')}';

        return GestureDetector(
          onTap: () => widget.onNavigate('/accounts'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppStyles.roundedL,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: White translucent icon container + type badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getAccountTypeIcon(account.type),
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getAccountTypeDisplayName(account.type),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                // Middle: Account Name & Mask
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mask,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                // Bottom: Formatted Balance in bold white
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(
                      account.balance,
                      hideAmount: hideAmount,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.account_balance_rounded;
      case 'current':
        return Icons.business_center_rounded;
      case 'cash':
        return Icons.payments_rounded;
      case 'wallet':
        return Icons.wallet_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  String _getAccountTypeDisplayName(String type) {
    switch (type.toLowerCase()) {
      case 'credit_card':
        return 'Credit';
      case 'savings':
        return 'Savings';
      case 'current':
        return 'Current';
      case 'cash':
        return 'Cash';
      case 'wallet':
        return 'Wallet';
      default:
        return 'Account';
    }
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
              InkWell(
                onTap: () => widget.onNavigate('/analytics'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Text(
                      'Revenue analysis',
                      style: AppStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ],
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
    final reportAsync = ref.watch(financialReportStreamProvider);
    final reportCategories = reportAsync.asData?.value.categoryBreakdown ?? [];

    final double displayAmount = totalExpense > 0
        ? totalExpense
        : (reportAsync.asData?.value.totalExpense ?? 1525.61);

    final List<_DonutCategory> categories;
    if (reportCategories.isNotEmpty) {
      categories = reportCategories.take(5).map((c) {
        Color color = AppColors.primary;
        try {
          final clean = c.colorHex.replaceAll('#', '').replaceAll('0x', '');
          color = Color(int.parse(clean, radix: 16));
        } catch (_) {}
        return _DonutCategory(
          name: c.categoryName,
          amount: c.totalAmount,
          color: color,
        );
      }).toList();
    } else {
      categories = [
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
    }

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
              InkWell(
                onTap: () => widget.onNavigate('/analytics'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Text(
                      'Expenses',
                      style: AppStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ],
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
                onTap: widget.onOpenAddTransaction,
              ),
              _buildContactTile(
                initial: 'J',
                name: 'Julia Davidson',
                accountMask: '•••• 2675',
                avatarColor: const Color(0xFF00D2FF),
                isDark: isDark,
                onTap: widget.onOpenAddTransaction,
              ),
              _buildContactTile(
                initial: 'A',
                name: 'Andrew Evans',
                accountMask: '•••• 0987',
                avatarColor: const Color(0xFFEC4899),
                isDark: isDark,
                onTap: widget.onOpenAddTransaction,
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
                  InkWell(
                    onTap: () => onNavigate('/goals'),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Text(
                          'Goals',
                          style: AppStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => onNavigate('/goals'),
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
              ref.watch(goalsStreamProvider).when(
                data: (goals) {
                  if (goals.isEmpty) {
                    return Column(
                      children: [
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
                    );
                  }

                  const gradients = [
                    LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8)]),
                    LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)]),
                    LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF38BDF8)]),
                    LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                  ];

                  return Column(
                    children: goals.take(4).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final g = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildGoalProgress(
                          icon: Icons.savings_rounded,
                          title: g.goal.title,
                          saved: g.goal.currentAmount,
                          target: g.goal.targetAmount,
                          gradient: gradients[i % gradients.length],
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox(),
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
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

