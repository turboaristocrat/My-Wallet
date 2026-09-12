import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/budgets/data/budget_repository.dart';
import 'package:my_wallet/features/reports/data/reports_repository.dart';
import 'package:my_wallet/features/rules/data/rules_repository.dart';

void main() {
  late AppDatabase db;
  late RulesRepository rulesRepo;
  late BudgetRepository budgetRepo;
  late ReportsRepository reportsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    rulesRepo = RulesRepository(db);
    budgetRepo = BudgetRepository(db);
    reportsRepo = ReportsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Smart Rules Engine Tests', () {
    test('creates rule and matches keywords accurately', () async {
      await rulesRepo.createRule(
        ruleName: 'Food: Swiggy',
        triggerType: 'merchant_contains',
        triggerValue: 'SWIGGY',
        actionSetPaymentType: 'upi',
      );

      final match = await rulesRepo.evaluateRules(text: 'Paid at SWIGGY BANGALORE');
      expect(match, isNotNull);
      expect(match?.matchedRuleName, 'Food: Swiggy');
      expect(match?.paymentType, 'upi');

      final noMatch = await rulesRepo.evaluateRules(text: 'Paid at STARBUCKS');
      expect(noMatch, isNull);
    });

    test('respects rule active state toggle', () async {
      final ruleId = await rulesRepo.createRule(
        ruleName: 'Uber Cabs',
        triggerType: 'merchant_contains',
        triggerValue: 'UBER',
      );

      // Verify active match
      var match = await rulesRepo.evaluateRules(text: 'UBER TRIP 123');
      expect(match, isNotNull);

      // Disable rule
      await rulesRepo.toggleRule(ruleId, false);
      match = await rulesRepo.evaluateRules(text: 'UBER TRIP 123');
      expect(match, isNull);
    });
  });

  group('Budgets and Goals Tests', () {
    test('creates budget and calculates remaining amount', () async {
      final now = DateTime.now();
      final budgetId = await budgetRepo.createBudget(
        amount: 25000,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month, 28),
      );

      expect(budgetId, isNotEmpty);

      final budgets = await budgetRepo.watchBudgetsWithSpend().first;
      expect(budgets.length, 1);
      expect(budgets.first.budget.amount, 25000);
      expect(budgets.first.spentAmount, 0.0);
      expect(budgets.first.remainingAmount, 25000);
    });

    test('creates savings goal and processes fund contributions', () async {
      final goalId = await budgetRepo.createGoal(
        title: 'Emergency Fund',
        targetAmount: 50000,
        initialAmount: 10000,
        targetDate: DateTime.now().add(const Duration(days: 60)),
      );

      var goals = await budgetRepo.watchGoals().first;
      expect(goals.length, 1);
      expect(goals.first.goal.currentAmount, 10000);
      expect(goals.first.progressRatio, closeTo(0.2, 0.01));

      // Contribute 15000
      await budgetRepo.contributeToGoal(goalId, 15000);
      goals = await budgetRepo.watchGoals().first;
      expect(goals.first.goal.currentAmount, 25000);
      expect(goals.first.progressRatio, closeTo(0.5, 0.01));
    });
  });

  group('Reports Repository Tests', () {
    test('computes savings rate and net savings accurately', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, 28);

      final report = await reportsRepo.watchFinancialReport(
        startDate: start,
        endDate: end,
      ).first;

      expect(report.totalIncome, 0.0);
      expect(report.totalExpense, 0.0);
      expect(report.netSavings, 0.0);
      expect(report.savingsRate, 0.0);
    });
  });
}
