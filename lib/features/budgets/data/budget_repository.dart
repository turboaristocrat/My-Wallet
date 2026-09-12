import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class BudgetWithSpend {
  final Budget budget;
  final Category? category;
  final double spentAmount;
  final double remainingAmount;
  final double progressRatio; // 0.0 to 1.0+

  BudgetWithSpend({
    required this.budget,
    required this.category,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progressRatio,
  });
}

class GoalWithProgress {
  final Goal goal;
  final double progressRatio; // 0.0 to 1.0
  final int daysRemaining;

  GoalWithProgress({
    required this.goal,
    required this.progressRatio,
    required this.daysRemaining,
  });
}

class BudgetRepository {
  final AppDatabase _db;
  BudgetRepository(this._db);

  /// Watch active budgets joined with Category and month-to-date spent amounts
  Stream<List<BudgetWithSpend>> watchBudgetsWithSpend() {
    final budgetsQuery = _db.select(_db.budgets).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ])..where(_db.budgets.isDeleted.equals(false));

    return budgetsQuery.watch().asyncMap((budgetRows) async {
      final List<BudgetWithSpend> result = [];

      for (final row in budgetRows) {
        final b = row.readTable(_db.budgets);
        final c = row.readTableOrNull(_db.categories);

        // Compute spent amount within budget date range
        final txQuery = _db.select(_db.transactions)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..where((tbl) => tbl.type.equals('expense'))
          ..where((tbl) => tbl.transactionDate.isBiggerOrEqualValue(b.startDate))
          ..where((tbl) => tbl.transactionDate.isSmallerOrEqualValue(b.endDate));

        if (b.categoryId != null) {
          txQuery.where((tbl) => tbl.categoryId.equals(b.categoryId!));
        }

        final txList = await txQuery.get();
        double totalSpent = 0.0;
        for (final tx in txList) {
          totalSpent += tx.amount;
        }

        final remaining = (b.amount - totalSpent).clamp(0.0, double.infinity);
        final ratio = b.amount > 0 ? (totalSpent / b.amount) : 0.0;

        result.add(BudgetWithSpend(
          budget: b,
          category: c,
          spentAmount: totalSpent,
          remainingAmount: remaining,
          progressRatio: ratio,
        ));
      }

      return result;
    });
  }

  /// Create a new category or overall budget
  Future<String> createBudget({
    String? categoryId,
    required double amount,
    String period = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
    int notifyAtPercent = 80,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ??
        DateTime(
          now.year,
          now.month,
          DateTime(now.year, now.month + 1, 0).day,
          23,
          59,
          59,
        );

    await _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: Value(id),
            categoryId: Value(categoryId),
            amount: amount,
            period: Value(period),
            startDate: start,
            endDate: end,
            notifyAtPercent: Value(notifyAtPercent),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Delete budget (soft delete)
  Future<void> deleteBudget(String id) async {
    await (_db.update(_db.budgets)..where((tbl) => tbl.id.equals(id))).write(
      BudgetsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Watch active goals
  Stream<List<GoalWithProgress>> watchGoals() {
    final query = _db.select(_db.goals)
      ..where((tbl) => tbl.isDeleted.equals(false))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.targetDate)]);

    return query.watch().map((goals) {
      final now = DateTime.now();
      return goals.map((g) {
        final ratio = g.targetAmount > 0
            ? (g.currentAmount / g.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final days = g.targetDate.difference(now).inDays;

        return GoalWithProgress(
          goal: g,
          progressRatio: ratio,
          daysRemaining: days < 0 ? 0 : days,
        );
      }).toList();
    });
  }

  /// Create a new savings goal
  Future<String> createGoal({
    required String title,
    required double targetAmount,
    double initialAmount = 0.0,
    required DateTime targetDate,
    double? monthlyAutoSaveAmount,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            id: Value(id),
            title: title,
            targetAmount: targetAmount,
            currentAmount: Value(initialAmount),
            targetDate: targetDate,
            monthlyAutoSaveAmount: Value(monthlyAutoSaveAmount),
            status: const Value('in_progress'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Contribute funds to an existing goal
  Future<void> contributeToGoal(String goalId, double amount) async {
    final goal = await (_db.select(_db.goals)..where((tbl) => tbl.id.equals(goalId))).getSingleOrNull();
    if (goal != null) {
      final newCurrent = goal.currentAmount + amount;
      final isAchieved = newCurrent >= goal.targetAmount;

      await (_db.update(_db.goals)..where((tbl) => tbl.id.equals(goalId))).write(
        GoalsCompanion(
          currentAmount: Value(newCurrent),
          status: Value(isAchieved ? 'achieved' : 'in_progress'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Delete goal (soft delete)
  Future<void> deleteGoal(String id) async {
    await (_db.update(_db.goals)..where((tbl) => tbl.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

final budgetsWithSpendStreamProvider = StreamProvider<List<BudgetWithSpend>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchBudgetsWithSpend();
});

final goalsStreamProvider = StreamProvider<List<GoalWithProgress>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchGoals();
});
