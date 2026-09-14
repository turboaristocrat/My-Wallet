import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../navigation/presentation/side_drawer.dart';

class InvestmentHolding {
  final String id;
  final String name;
  final String type; // 'Mutual Fund', 'Stock', 'Gold', 'Fixed Deposit'
  final double investedAmount;
  final double currentValue;
  final double returnPercentage;
  final String frequency; // 'SIP Monthly', 'One-time', 'Quarterly'
  final Color accentColor;

  const InvestmentHolding({
    required this.id,
    required this.name,
    required this.type,
    required this.investedAmount,
    required this.currentValue,
    required this.returnPercentage,
    required this.frequency,
    required this.accentColor,
  });
}

class InvestmentsScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const InvestmentsScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedFilter = 'All';

  final List<InvestmentHolding> _holdings = [
    const InvestmentHolding(
      id: 'inv_1',
      name: 'Parag Parikh Flexi Cap',
      type: 'Mutual Fund',
      investedAmount: 48000,
      currentValue: 62450,
      returnPercentage: 30.1,
      frequency: 'SIP ₹4,000/mo',
      accentColor: Color(0xFF8B5CF6),
    ),
    const InvestmentHolding(
      id: 'inv_2',
      name: 'Nifty 50 Index Fund',
      type: 'Mutual Fund',
      investedAmount: 36000,
      currentValue: 43800,
      returnPercentage: 21.6,
      frequency: 'SIP ₹3,000/mo',
      accentColor: Color(0xFF00D2FF),
    ),
    const InvestmentHolding(
      id: 'inv_3',
      name: 'HDFC Bank & Tata Motors',
      type: 'Stock',
      investedAmount: 32000,
      currentValue: 38900,
      returnPercentage: 21.5,
      frequency: 'One-time',
      accentColor: Color(0xFF38BDF8),
    ),
    const InvestmentHolding(
      id: 'inv_4',
      name: 'Sovereign Gold Bond (SGB)',
      type: 'Gold',
      investedAmount: 25000,
      currentValue: 31200,
      returnPercentage: 24.8,
      frequency: 'Tranche VIII',
      accentColor: Color(0xFFF59E0B),
    ),
    const InvestmentHolding(
      id: 'inv_5',
      name: 'HDFC 7.25% Fixed Deposit',
      type: 'Fixed Deposit',
      investedAmount: 50000,
      currentValue: 53625,
      returnPercentage: 7.25,
      frequency: 'Matures Nov 2026',
      accentColor: Color(0xFF10B981),
    ),
  ];

  void _openAddHoldingSheet() {
    final nameCtrl = TextEditingController();
    final investedCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    String selectedType = 'Mutual Fund';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                        'Add Investment Asset',
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
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Asset / Fund Name',
                      hintText: 'e.g. Parag Parikh Flexi Cap, Sovereign Gold',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    decoration: const InputDecoration(labelText: 'Asset Category'),
                    items: const [
                      DropdownMenuItem(value: 'Mutual Fund', child: Text('Mutual Fund / SIP')),
                      DropdownMenuItem(value: 'Stock', child: Text('Equities & Stocks')),
                      DropdownMenuItem(value: 'Gold', child: Text('Gold & Precious Metals')),
                      DropdownMenuItem(value: 'Fixed Deposit', child: Text('Fixed Deposit / PPF')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: investedCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Invested (₹)',
                            hintText: '0',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: currentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Current Value (₹)',
                            hintText: '0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final invested = double.tryParse(investedCtrl.text.trim()) ?? 0;
                        final current = double.tryParse(currentCtrl.text.trim()) ?? invested;

                        if (name.isEmpty || invested <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid details')),
                          );
                          return;
                        }

                        final retPct = invested > 0
                            ? ((current - invested) / invested) * 100
                            : 0.0;

                        Color color = const Color(0xFF8B5CF6);
                        if (selectedType == 'Stock') color = const Color(0xFF38BDF8);
                        if (selectedType == 'Gold') color = const Color(0xFFF59E0B);
                        if (selectedType == 'Fixed Deposit') color = const Color(0xFF10B981);

                        setState(() {
                          _holdings.insert(
                            0,
                            InvestmentHolding(
                              id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              type: selectedType,
                              investedAmount: invested,
                              currentValue: current,
                              returnPercentage: retPct,
                              frequency: 'Active Holding',
                              accentColor: color,
                            ),
                          );
                        });

                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added $name to portfolio')),
                        );
                      },
                      child: const Text(
                        'Save to Portfolio',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);

    final filteredHoldings = _selectedFilter == 'All'
        ? _holdings
        : _holdings.where((h) => h.type == _selectedFilter).toList();

    double totalInvested = 0;
    double totalCurrent = 0;
    for (final h in _holdings) {
      totalInvested += h.investedAmount;
      totalCurrent += h.currentValue;
    }
    final totalGain = totalCurrent - totalInvested;
    final totalGainPct = totalInvested > 0 ? (totalGain / totalInvested) * 100 : 0.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/investments',
        onNavigate: (route) {
          Navigator.of(context).pop();
          widget.onNavigate(route);
        },
      ),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Investments',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'AI Copilot Advice',
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            onPressed: () => widget.onNavigate('/copilot'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Portfolio Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF6B21A8), Color(0xFF9333EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppStyles.roundedXL,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL PORTFOLIO VALUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+${totalGainPct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(totalCurrent, hideAmount: hideAmounts),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Invested',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(totalInvested, hideAmount: hideAmounts),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Overall Returns',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${CurrencyFormatter.format(totalGain, hideAmount: hideAmounts)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF86EFAC),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Mutual Fund',
                  'Stock',
                  'Gold',
                  'Fixed Deposit',
                ].map((category) {
                  final isSelected = _selectedFilter == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppColors.lightTextPrimary),
                      ),
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFilter = category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Holdings List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Holdings (${filteredHoldings.length})',
                  style: AppStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openAddHoldingSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Holding'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Holdings Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHoldings.length,
              itemBuilder: (context, index) {
                final h = filteredHoldings[index];
                final gain = h.currentValue - h.investedAmount;
                final isPositive = gain >= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: AppStyles.roundedL,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    boxShadow: AppStyles.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: h.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            h.type == 'Mutual Fund'
                                ? Icons.pie_chart_rounded
                                : h.type == 'Stock'
                                    ? Icons.show_chart_rounded
                                    : h.type == 'Gold'
                                        ? Icons.monetization_on_rounded
                                        : Icons.account_balance_rounded,
                            color: h.accentColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${h.type} • ${h.frequency}',
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
                            CurrencyFormatter.format(h.currentValue, hideAmount: hideAmounts),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${isPositive ? '+' : ''}${h.returnPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? const Color(0xFF10B981) : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openAddHoldingSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Investment'),
      ),
    );
  }
}
