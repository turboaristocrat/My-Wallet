import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../transactions/data/transaction_repository.dart';
import '../data/rules_repository.dart';

class RulesScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const RulesScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  final TextEditingController _testTextCtrl = TextEditingController();
  RuleMatchResult? _testResult;

  void _openAddRuleSheet() {
    final nameCtrl = TextEditingController();
    final keywordCtrl = TextEditingController();
    String? selectedCategoryId;
    String? selectedPaymentType = 'upi';
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
                        'New Smart Rule',
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

                  // Rule Name
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Rule Name',
                      hintText: 'e.g. Swiggy Food Orders',
                      prefixIcon: const Icon(Icons.label_rounded, size: 20),
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

                  // Trigger Keyword
                  TextField(
                    controller: keywordCtrl,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'When text contains keyword',
                      hintText: 'e.g. SWIGGY, UBER, ZOMATO, NETFLIX',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
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

                  // Target Category Selector
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
                          labelText: 'Auto-Assign Category',
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
                        items: cats.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )).toList(),
                        onChanged: (val) => setSheetState(() => selectedCategoryId = val),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 14),

                  // Payment Mode (Optional)
                  DropdownButtonFormField<String?>(
                    initialValue: selectedPaymentType,
                    dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Auto-Assign Payment Mode (Optional)',
                      prefixIcon: const Icon(Icons.payment_rounded, size: 20),
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
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Leave Unchanged')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI (Google Pay, PhonePe)')),
                      DropdownMenuItem(value: 'card', child: Text('Debit / Credit Card')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'net_banking', child: Text('Net Banking')),
                    ],
                    onChanged: (val) => setSheetState(() => selectedPaymentType = val),
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
                        final name = nameCtrl.text.trim();
                        final keyword = keywordCtrl.text.trim();
                        if (name.isEmpty || keyword.isEmpty) return;

                        await ref.read(rulesRepositoryProvider).createRule(
                              ruleName: name,
                              triggerType: 'merchant_contains',
                              triggerValue: keyword,
                              actionSetCategoryId: selectedCategoryId,
                              actionSetPaymentType: selectedPaymentType,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Create Smart Rule',
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

  void _runRuleTest() async {
    final text = _testTextCtrl.text.trim();
    if (text.isEmpty) return;

    final res = await ref.read(rulesRepositoryProvider).evaluateRules(text: text);
    setState(() => _testResult = res);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rulesAsync = ref.watch(allRulesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/rules',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Smart Automation Rules',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Interactive Test Simulator Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: AppStyles.roundedL,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: AppStyles.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.income, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Test Rule Simulator',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Type any merchant name or SMS snippet to simulate how rules will categorize it in real-time.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _testTextCtrl,
                        onSubmitted: (_) => _runRuleTest(),
                        style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Paid at SWIGGY BANGALORE',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _runRuleTest,
                      child: const Text('Test', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_testResult?.matchedRuleName != null ? AppColors.income : AppColors.expense)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult?.matchedRuleName != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 18,
                          color: _testResult?.matchedRuleName != null ? AppColors.income : AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResult?.matchedRuleName != null
                                ? 'Matched rule: "${_testResult!.matchedRuleName}"'
                                : 'No matching rule found. Default categorization will be used.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _testResult?.matchedRuleName != null ? AppColors.income : AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rules List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'ACTIVE AUTOMATION RULES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),

          rulesAsync.when(
            data: (rules) {
              if (rules.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      children: [
                        Icon(Icons.rule_folder_rounded, size: 48, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        const SizedBox(height: 12),
                        const Text('No rules configured yet', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Tap + to set your first auto-categorization rule', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              final categories = categoriesAsync.value ?? [];

              return Column(
                children: rules.map((r) {
                  final cat = categories.where((c) => c.id == r.actionSetCategoryId).firstOrNull;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: AppStyles.roundedL,
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      boxShadow: AppStyles.softShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                          child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.ruleName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    child: Text(
                                      'Keyword: "${r.triggerValue}"',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  if (cat != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.income.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '→ ${cat.name}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.income,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: r.isActive,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            ref.read(rulesRepositoryProvider).toggleRule(r.id, val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary,
                          onPressed: () => ref.read(rulesRepositoryProvider).deleteRule(r.id),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
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
          onPressed: _openAddRuleSheet,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}
