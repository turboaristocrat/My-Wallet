import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../accounts/data/account_repository.dart';
import '../../budgets/data/budget_repository.dart';
import '../../debts/data/debt_repository.dart';
import '../../recurring/data/recurring_repository.dart';

class CopilotMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? actionSuggestions;

  CopilotMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionSuggestions,
  });
}

class FinancialSnapshot {
  final double netWorth;
  final double monthlyIncome;
  final double monthlyExpense;
  final double netSavings;
  final double savingsRate;
  final Map<String, double> categorySpending;
  final List<BudgetWithSpend> activeBudgets;
  final List<RecurringWithDetails> upcomingBills;
  final double monthlyBillCommitment;
  final NetDebtSummary debtSummary;

  FinancialSnapshot({
    required this.netWorth,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.categorySpending,
    required this.activeBudgets,
    required this.upcomingBills,
    required this.monthlyBillCommitment,
    required this.debtSummary,
  });
}

class CopilotService {
  final AppDatabase _db;
  final AccountRepository _accountRepo;
  final BudgetRepository _budgetRepo;
  final RecurringRepository _recurringRepo;
  final DebtRepository _debtRepo;

  CopilotService(
    this._db,
    this._accountRepo,
    this._budgetRepo,
    this._recurringRepo,
    this._debtRepo,
  );

  /// Fetch full financial snapshot from local SQLite DB
  Future<FinancialSnapshot> getSnapshot() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // 1. Net worth across active accounts
    final accounts = await _accountRepo.watchActiveAccounts().first;
    double netWorth = 0.0;
    for (final acc in accounts) {
      netWorth += acc.balance;
    }

    // 2. Monthly income & expenses
    final txRows = await (_db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
          ..where(_db.transactions.isDeleted.equals(false))
          ..where(_db.transactions.transactionDate.isBiggerOrEqualValue(startOfMonth))
          ..where(_db.transactions.transactionDate.isSmallerOrEqualValue(endOfMonth)))
        .get();

    double income = 0.0;
    double expense = 0.0;
    final Map<String, double> catSpending = {};

    for (final row in txRows) {
      final t = row.readTable(_db.transactions);
      final c = row.readTableOrNull(_db.categories);
      final catName = c?.name ?? 'Other';

      if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'expense') {
        expense += t.amount;
        catSpending[catName] = (catSpending[catName] ?? 0.0) + t.amount;
      }
    }

    final netSavings = income - expense;
    final savingsRate = income > 0 ? (netSavings / income) * 100 : 0.0;

    // 3. Budgets
    final budgets = await _budgetRepo.watchBudgetsWithSpend().first;

    // 4. Upcoming bills & commitments
    final recurringDetails = await _recurringRepo.watchRecurringTemplates().first;
    final templates = recurringDetails.map((d) => d.template).toList();
    final monthlyCommitment = _recurringRepo.calculateMonthlyCommitment(templates);
    final upcomingBills = recurringDetails.take(5).toList();

    // 5. Debts
    final debtsList = await _debtRepo.watchDebts().first;
    final debts = debtsList.map((d) => d.debt).toList();
    final debtSummary = _debtRepo.calculateNetDebtSummary(debts);

    return FinancialSnapshot(
      netWorth: netWorth,
      monthlyIncome: income,
      monthlyExpense: expense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      categorySpending: catSpending,
      activeBudgets: budgets,
      upcomingBills: upcomingBills,
      monthlyBillCommitment: monthlyCommitment,
      debtSummary: debtSummary,
    );
  }

  /// Process natural language query with on-device financial reasoning
  Future<String> answerQuery(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();
    final snapshot = await getSnapshot();
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    // 1. Affordability query: "can i afford 5000", "can i buy a phone for 20000"
    if (query.contains('afford') || query.contains('can i buy') || query.contains('can i spend')) {
      return _evaluateAffordability(rawQuery, snapshot, currencyFormat);
    }

    // 2. Spending by category or total expenses
    if (query.contains('spent') || query.contains('spending') || query.contains('expense')) {
      return _evaluateSpending(query, snapshot, currencyFormat);
    }

    // 3. Upcoming bills & subscriptions
    if (query.contains('bill') || query.contains('subscription') || query.contains('recurring') || query.contains('due')) {
      return _evaluateBills(snapshot, currencyFormat);
    }

    // 4. Budgets and limits
    if (query.contains('budget') || query.contains('limit') || query.contains('overspend')) {
      return _evaluateBudgets(snapshot, currencyFormat);
    }

    // 5. Debts, loans, and who owes what
    if (query.contains('debt') || query.contains('owe') || query.contains('lent') || query.contains('loan') || query.contains('borrowed')) {
      return _evaluateDebts(snapshot, currencyFormat);
    }

    // 6. Savings and net worth
    if (query.contains('save') || query.contains('saving') || query.contains('net worth') || query.contains('balance') || query.contains('wealth')) {
      return _evaluateNetWorthAndSavings(snapshot, currencyFormat);
    }

    // Default: Comprehensive Financial Health Summary
    return _generateOverview(snapshot, currencyFormat);
  }

  String _evaluateAffordability(String query, FinancialSnapshot s, NumberFormat fmt) {
    // Extract first numeric value found in query
    final regExp = RegExp(r'(\d[\d,.]*)');
    final match = regExp.firstMatch(query.replaceAll('₹', ''));
    if (match == null) {
      return "To give you an accurate affordability check, please specify the amount! For example: *'Can I afford ₹15,000 for a new gadget?'*";
    }

    final cleanNum = match.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(cleanNum);
    if (amount == null || amount <= 0) {
      return "I couldn't detect a valid cost. Try asking: *'Can I afford ₹5,000?'*";
    }

    final freeCashFlow = s.netSavings - s.monthlyBillCommitment;
    final liquidRatio = s.netWorth > 0 ? (amount / s.netWorth) : 1.0;

    final buffer = StringBuffer();
    buffer.writeln("### 💳 Affordability Assessment for ${fmt.format(amount)}\n");

    if (amount > s.netWorth) {
      buffer.writeln("❌ **Not Recommended right now.**");
      buffer.writeln("- This purchase (${fmt.format(amount)}) exceeds your total recorded liquid balance across all accounts (${fmt.format(s.netWorth)}).");
      buffer.writeln("- Making this purchase could risk overdraft or immediate liquidity strain.");
    } else if (liquidRatio > 0.4) {
      buffer.writeln("⚠️ **Caution Advised:**");
      buffer.writeln("- This purchase uses **${(liquidRatio * 100).toStringAsFixed(1)}%** of your total balance (${fmt.format(s.netWorth)}).");
      buffer.writeln("- You also have upcoming recurring commitments of **${fmt.format(s.monthlyBillCommitment)}/month**.");
      buffer.writeln("- If this is not an essential purchase, consider saving across the next 2-3 months first.");
    } else if (liquidRatio <= 0.2 && freeCashFlow >= amount) {
      buffer.writeln("✅ **Safe to proceed!**");
      buffer.writeln("- This purchase represents only **${(liquidRatio * 100).toStringAsFixed(1)}%** of your total liquid balance (${fmt.format(s.netWorth)}).");
      buffer.writeln("- Your positive monthly cash flow easily covers it without dipping into your emergency reserves.");
      buffer.writeln("- Remaining liquid buffer after purchase: **${fmt.format(s.netWorth - amount)}**.");
    } else {
      buffer.writeln("🟢 **Affordable with moderate impact:**");
      buffer.writeln("- You have sufficient balance (${fmt.format(s.netWorth)}), but keep in mind your scheduled commitments (${fmt.format(s.monthlyBillCommitment)}).");
      buffer.writeln("- Post-purchase balance will be **${fmt.format(s.netWorth - amount)}**.");
    }

    return buffer.toString();
  }

  String _evaluateSpending(String query, FinancialSnapshot s, NumberFormat fmt) {
    // Check if user named a specific category
    String? matchedCategory;
    for (final cat in s.categorySpending.keys) {
      if (query.contains(cat.toLowerCase())) {
        matchedCategory = cat;
        break;
      }
    }

    final buffer = StringBuffer();
    if (matchedCategory != null) {
      final spent = s.categorySpending[matchedCategory] ?? 0.0;
      final pct = s.monthlyExpense > 0 ? (spent / s.monthlyExpense * 100) : 0.0;
      buffer.writeln("### 🏷️ Spending on $matchedCategory\n");
      buffer.writeln("You have spent **${fmt.format(spent)}** on **$matchedCategory** this month.");
      buffer.writeln("This accounts for **${pct.toStringAsFixed(1)}%** of your total monthly expenses (${fmt.format(s.monthlyExpense)}).");
      return buffer.toString();
    }

    // General spending summary
    buffer.writeln("### 📊 Current Month Spending Breakdown\n");
    buffer.writeln("- **Total Expenses:** ${fmt.format(s.monthlyExpense)}");
    buffer.writeln("- **Total Income:** ${fmt.format(s.monthlyIncome)}");
    buffer.writeln("- **Net Savings:** ${fmt.format(s.netSavings)} (${s.savingsRate.toStringAsFixed(1)}%)\n");

    if (s.categorySpending.isEmpty) {
      buffer.writeln("No expense transactions recorded yet this month.");
    } else {
      buffer.writeln("**Top Spending Categories:**");
      final sorted = s.categorySpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted.take(4)) {
        final pct = s.monthlyExpense > 0 ? (entry.value / s.monthlyExpense * 100) : 0.0;
        buffer.writeln("• **${entry.key}**: ${fmt.format(entry.value)} (${pct.toStringAsFixed(1)}%)");
      }
    }

    return buffer.toString();
  }

  String _evaluateBills(FinancialSnapshot s, NumberFormat fmt) {
    final buffer = StringBuffer();
    buffer.writeln("### 📅 Upcoming Bills & Subscriptions\n");
    buffer.writeln("Your estimated monthly recurring commitments total **${fmt.format(s.monthlyBillCommitment)}/month**.\n");

    if (s.upcomingBills.isEmpty) {
      buffer.writeln("You have no upcoming bills due in the immediate schedule.");
    } else {
      buffer.writeln("**Next Due Items:**");
      for (final b in s.upcomingBills) {
        final dueStr = DateFormat('dd MMM').format(b.template.nextDueDate);
        buffer.writeln("• **${b.template.title}**: ${fmt.format(b.template.amount)} — due **$dueStr** (${b.template.frequency})");
      }
    }

    return buffer.toString();
  }

  String _evaluateBudgets(FinancialSnapshot s, NumberFormat fmt) {
    final buffer = StringBuffer();
    buffer.writeln("### 🎯 Budget Status\n");

    if (s.activeBudgets.isEmpty) {
      buffer.writeln("You don't have any active budgets set up. Go to the Budgets tab to set spending limits for your frequent categories!");
      return buffer.toString();
    }

    final overspent = s.activeBudgets.where((b) => b.progressRatio >= 1.0).toList();
    final warning = s.activeBudgets.where((b) => b.progressRatio >= 0.8 && b.progressRatio < 1.0).toList();
    final healthy = s.activeBudgets.where((b) => b.progressRatio < 0.8).toList();

    if (overspent.isNotEmpty) {
      buffer.writeln("🚨 **Over-Budget Categories:**");
      for (final b in overspent) {
        final cat = b.category?.name ?? 'Overall';
        buffer.writeln("• **$cat**: Spent ${fmt.format(b.spentAmount)} of ${fmt.format(b.budget.amount)} (${(b.progressRatio * 100).toStringAsFixed(0)}%)");
      }
      buffer.writeln();
    }

    if (warning.isNotEmpty) {
      buffer.writeln("⚠️ **Approaching Limit (>= 80%):**");
      for (final b in warning) {
        final cat = b.category?.name ?? 'Overall';
        buffer.writeln("• **$cat**: ${fmt.format(b.spentAmount)} / ${fmt.format(b.budget.amount)} — ${fmt.format(b.remainingAmount)} remaining");
      }
      buffer.writeln();
    }

    if (healthy.isNotEmpty) {
      buffer.writeln("✅ **On Track:**");
      for (final b in healthy) {
        final cat = b.category?.name ?? 'Overall';
        buffer.writeln("• **$cat**: ${fmt.format(b.spentAmount)} of ${fmt.format(b.budget.amount)} (${(b.progressRatio * 100).toStringAsFixed(0)}%)");
      }
    }

    return buffer.toString();
  }

  String _evaluateDebts(FinancialSnapshot s, NumberFormat fmt) {
    final buffer = StringBuffer();
    buffer.writeln("### 🤝 Debts & Loans Summary\n");
    buffer.writeln("- **Money Lent (Others owe you):** ${fmt.format(s.debtSummary.totalLent)}");
    buffer.writeln("- **Money Borrowed (You owe others):** ${fmt.format(s.debtSummary.totalBorrowed)}");
    buffer.writeln("- **Bank Loans Outstanding:** ${fmt.format(s.debtSummary.totalFormalLoans)}");
    buffer.writeln("- **Net Debt Position:** **${fmt.format(s.debtSummary.netPosition)}**\n");

    if (s.debtSummary.totalLent > 0) {
      buffer.writeln("💡 *Tip: You can use the Debts screen to send one-tap WhatsApp payment reminders to friends.*");
    } else {
      buffer.writeln("You have no outstanding informal debts pending collection.");
    }

    return buffer.toString();
  }

  String _evaluateNetWorthAndSavings(FinancialSnapshot s, NumberFormat fmt) {
    final buffer = StringBuffer();
    buffer.writeln("### 💰 Wealth & Net Worth Overview\n");
    buffer.writeln("- **Total Liquid Net Worth:** **${fmt.format(s.netWorth)}** across all active accounts.");
    buffer.writeln("- **Monthly Cash Flow:** ${s.netSavings >= 0 ? '+' : ''}${fmt.format(s.netSavings)}");
    buffer.writeln("- **Current Savings Rate:** **${s.savingsRate.toStringAsFixed(1)}%**");

    if (s.savingsRate >= 30) {
      buffer.writeln("\n🌟 Exceptional! Your savings rate is well above the recommended 20% benchmark.");
    } else if (s.savingsRate >= 15) {
      buffer.writeln("\n👍 Good job! You are maintaining a healthy savings buffer.");
    } else if (s.monthlyIncome > 0) {
      buffer.writeln("\n💡 Consider trimming top discretionary expenses to reach at least a 20% monthly savings rate.");
    }

    return buffer.toString();
  }

  String _generateOverview(FinancialSnapshot s, NumberFormat fmt) {
    final buffer = StringBuffer();
    buffer.writeln("### 🤖 Financial Health Digest\n");
    buffer.writeln("Here is your real-time financial snapshot:\n");
    buffer.writeln("- **Net Worth:** **${fmt.format(s.netWorth)}**");
    buffer.writeln("- **Monthly Income:** ${fmt.format(s.monthlyIncome)}");
    buffer.writeln("- **Monthly Spending:** ${fmt.format(s.monthlyExpense)}");
    buffer.writeln("- **Net Savings:** ${fmt.format(s.netSavings)} (${s.savingsRate.toStringAsFixed(1)}%)");
    buffer.writeln("- **Monthly Recurring Commitments:** ${fmt.format(s.monthlyBillCommitment)}");
    buffer.writeln("- **Net Debt Position:** ${fmt.format(s.debtSummary.netPosition)}\n");

    buffer.writeln("You can ask me questions like:");
    buffer.writeln("• *\"Can I afford ₹10,000 for shopping?\"*");
    buffer.writeln("• *\"How much did I spend on food?\"*");
    buffer.writeln("• *\"What bills are due soon?\"*");
    buffer.writeln("• *\"Am I over budget?\"*");
    buffer.writeln("• *\"Who owes me money?\"*");

    return buffer.toString();
  }
}

final copilotServiceProvider = Provider<CopilotService>((ref) {
  final db = ref.watch(databaseProvider);
  final accountRepo = ref.watch(accountRepositoryProvider);
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final recurringRepo = ref.watch(recurringRepositoryProvider);
  final debtRepo = ref.watch(debtRepositoryProvider);
  return CopilotService(db, accountRepo, budgetRepo, recurringRepo, debtRepo);
});
