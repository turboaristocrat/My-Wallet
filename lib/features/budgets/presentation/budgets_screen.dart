import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../transactions/data/transaction_repository.dart';
import '../data/budget_repository.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  final String initialTab; // 'budgets' or 'goals'
  const BudgetsScreen({super.key, required this.onNavigate, this.initialTab = 'budgets'});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void _openCreateBudgetSheet() {
    final amountCtrl = TextEditingController();
    String? selectedCategoryId;
    final categoriesAsync = ref.read(categoriesStreamProvider);

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
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Budget',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  categoriesAsync.when(
                    data: (cats) {
                      return DropdownButtonFormField<String?>(
                        initialValue: selectedCategoryId,
                        dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: const Icon(Icons.category_rounded, size: 20),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                          border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppStyles.roundedM,
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Overall Monthly Budget (All Categories)'),
                          ),
                          ...cats.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (val) => setSheetState(() => selectedCategoryId = val),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 14),

                  // Budget Limit Amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit (₹)',
                      hintText: 'e.g. 15000',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
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
                        final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                        if (amt <= 0) return;

                        await ref.read(budgetRepositoryProvider).createBudget(
                              categoryId: selectedCategoryId,
                              amount: amt,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Set Budget',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  void _openCreateGoalSheet() {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final initialCtrl = TextEditingController(text: '0');
    DateTime targetDate = DateTime.now().add(const Duration(days: 90));

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
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Savings Goal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Goal Title
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g. Emergency Fund, New Laptop',
                      prefixIcon: const Icon(Icons.track_changes_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Target Amount & Initial Amount
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Target (₹)',
                            prefixIcon: const Icon(Icons.flag_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                            border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: initialCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Already Saved (₹)',
                            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                            border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppStyles.roundedM,
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Target Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setSheetState(() => targetDate = picked);
                    },
                    borderRadius: AppStyles.roundedM,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Target Date',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppStyles.roundedM,
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.event_rounded, size: 20),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(targetDate),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                        final title = titleCtrl.text.trim();
                        final target = double.tryParse(targetCtrl.text) ?? 0.0;
                        final initial = double.tryParse(initialCtrl.text) ?? 0.0;
                        if (title.isEmpty || target <= 0) return;

                        await ref.read(budgetRepositoryProvider).createGoal(
                              title: title,
                              targetAmount: target,
                              initialAmount: initial,
                              targetDate: targetDate,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Create Goal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  void _openContributeGoalSheet(String goalId, String goalTitle) {
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Funds to $goalTitle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Contribution Amount (₹)',
                  hintText: 'e.g. 5000',
                  prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppStyles.roundedM,
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 50,
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
                    final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amt <= 0) return;

                    await ref.read(budgetRepositoryProvider).contributeToGoal(goalId, amt);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'Deposit Funds',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final budgetsAsync = ref.watch(budgetsWithSpendStreamProvider);
    final goalsAsync = ref.watch(goalsStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: _selectedTab == 'budgets' ? '/budgets' : '/goals',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Budgets & Goals',
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
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: hideAmounts ? 'Show Amounts' : 'Hide Amounts',
            onPressed: () => ref.read(hideAmountsProvider.notifier).state = !hideAmounts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tab Switcher Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  _buildTabPill('budgets', 'Category Budgets', Icons.pie_chart_rounded),
                  _buildTabPill('goals', 'Savings Goals', Icons.track_changes_rounded),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightDivider),

          // Tab Content
          Expanded(
            child: _selectedTab == 'budgets'
                ? _buildBudgetsTab(budgetsAsync, isDark, hideAmounts)
                : _buildGoalsTab(goalsAsync, isDark, hideAmounts),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: _selectedTab == 'budgets' ? _openCreateBudgetSheet : _openCreateGoalSheet,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildTabPill(String tabKey, String label, IconData icon) {
    final isSelected = _selectedTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? AppStyles.heroGlowShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Budgets Tab
  Widget _buildBudgetsTab(
    AsyncValue<List<BudgetWithSpend>> budgetsAsync,
    bool isDark,
    bool hideAmounts,
  ) {
    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) {
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
                    child: const Icon(Icons.pie_chart_rounded, size: 54, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Budgets Set Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set monthly spending limits for categories to stay within your target and avoid overspending.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                        shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                      ),
                      onPressed: _openCreateBudgetSheet,
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('Create First Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Compute total monthly budget vs total spent
        double totalBudget = 0.0;
        double totalSpent = 0.0;
        for (final b in budgets) {
          totalBudget += b.budget.amount;
          totalSpent += b.spentAmount;
        }
        final overallRatio = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
        final totalRemaining = (totalBudget - totalSpent).clamp(0.0, double.infinity);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            // Overall Monthly Health Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: AppStyles.roundedL,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: isDark ? AppStyles.heroGlowShadow : AppStyles.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Monthly Budget',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: (overallRatio > 0.85 ? AppColors.expense : AppColors.income).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${CurrencyFormatter.format(totalRemaining, hideAmount: hideAmounts)} left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: overallRatio > 0.85 ? AppColors.expense : AppColors.income,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyFormatter.format(totalSpent, hideAmount: hideAmounts),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'of ${CurrencyFormatter.format(totalBudget, hideAmount: hideAmounts)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallRatio,
                      minHeight: 8,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightDivider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallRatio > 0.9
                            ? AppColors.expense
                            : (overallRatio > 0.75 ? AppColors.warning : AppColors.income),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'CATEGORY BUDGETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),

            ...budgets.map((b) {
              final catName = b.category?.name ?? 'Overall Monthly Budget';
              final color = Color(int.tryParse(b.category?.colorHex ?? '0xFF8B5CF6') ?? 0xFF8B5CF6);
              final isOver = b.spentAmount > b.budget.amount;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppStyles.roundedL,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                          child: Icon(Icons.pie_chart_rounded, color: color, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            catName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          isOver
                              ? 'Over by ${CurrencyFormatter.format(b.spentAmount - b.budget.amount, hideAmount: hideAmounts)}'
                              : '${CurrencyFormatter.format(b.remainingAmount, hideAmount: hideAmounts)} left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isOver ? AppColors.expense : AppColors.income,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary,
                          onPressed: () => ref.read(budgetRepositoryProvider).deleteBudget(b.budget.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: ${CurrencyFormatter.format(b.spentAmount, hideAmount: hideAmounts)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          'Limit: ${CurrencyFormatter.format(b.budget.amount, hideAmount: hideAmounts)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: b.progressRatio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightDivider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          b.progressRatio > 0.9
                              ? AppColors.expense
                              : (b.progressRatio > 0.75 ? AppColors.warning : AppColors.income),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // Goals Tab
  Widget _buildGoalsTab(
    AsyncValue<List<GoalWithProgress>> goalsAsync,
    bool isDark,
    bool hideAmounts,
  ) {
    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
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
                    child: const Icon(Icons.track_changes_rounded, size: 54, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Savings Goals Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create financial targets like an Emergency Fund, Travel, or New Gadget and track your progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                        shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                      ),
                      onPressed: _openCreateGoalSheet,
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text('Create First Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: goals.map((g) {
            final goal = g.goal;
            final isAchieved = goal.status == 'achieved' || goal.currentAmount >= goal.targetAmount;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: AppStyles.roundedL,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: isDark ? AppStyles.heroGlowShadow : AppStyles.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isAchieved ? AppColors.income : AppColors.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isAchieved ? '🎉 ACHIEVED' : '${g.daysRemaining}d left',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isAchieved ? AppColors.income : AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyFormatter.format(goal.currentAmount, hideAmount: hideAmounts),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Target: ${CurrencyFormatter.format(goal.targetAmount, hideAmount: hideAmounts)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: g.progressRatio,
                      minHeight: 8,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightDivider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isAchieved ? AppColors.income : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(g.progressRatio * 100).toStringAsFixed(0)}% Saved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAchieved ? AppColors.income : AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary,
                            onPressed: () => ref.read(budgetRepositoryProvider).deleteGoal(goal.id),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openContributeGoalSheet(goal.id, goal.title),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('+ Add Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
