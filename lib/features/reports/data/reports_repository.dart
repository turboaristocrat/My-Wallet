import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class CategorySpending {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final String iconName;
  final double totalAmount;
  final double percentage;

  CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.iconName,
    required this.totalAmount,
    required this.percentage,
  });
}

class FinancialReport {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // 0.0 to 100.0
  final List<CategorySpending> categoryBreakdown;
  final Map<DateTime, double> dailyExpenses;
  final Map<String, double> monthlyIncome;
  final Map<String, double> monthlyExpense;

  FinancialReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.categoryBreakdown,
    required this.dailyExpenses,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });
}

class ReportsRepository {
  final AppDatabase _db;
  ReportsRepository(this._db);

  Stream<FinancialReport> watchFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Select all transactions within date range
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(_db.transactions.isDeleted.equals(false))
      ..where(_db.transactions.transactionDate.isBiggerOrEqualValue(startDate))
      ..where(_db.transactions.transactionDate.isSmallerOrEqualValue(endDate));

    return query.watch().map((rows) {
      double totalIncome = 0.0;
      double totalExpense = 0.0;
      final Map<String, double> catTotals = {};
      final Map<String, CategoriesCompanion> catMeta = {};
      final Map<DateTime, double> dailyMap = {};
      final Map<String, double> monthInc = {};
      final Map<String, double> monthExp = {};

      for (final row in rows) {
        final t = row.readTable(_db.transactions);
        final c = row.readTableOrNull(_db.categories);

        final dayKey = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
        final monthKey = '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}';

        if (t.type == 'income') {
          totalIncome += t.amount;
          monthInc[monthKey] = (monthInc[monthKey] ?? 0.0) + t.amount;
        } else if (t.type == 'expense') {
          totalExpense += t.amount;
          dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + t.amount;
          monthExp[monthKey] = (monthExp[monthKey] ?? 0.0) + t.amount;

          final catId = t.categoryId ?? 'uncategorized';
          catTotals[catId] = (catTotals[catId] ?? 0.0) + t.amount;

          if (c != null && !catMeta.containsKey(catId)) {
            catMeta[catId] = CategoriesCompanion(
              id: Value(c.id),
              name: Value(c.name),
              colorHex: Value(c.colorHex),
              iconName: Value(c.iconName),
            );
          }
        }
      }

      final netSavings = totalIncome - totalExpense;
      final savingsRate = totalIncome > 0
          ? ((netSavings / totalIncome) * 100).clamp(0.0, 100.0)
          : 0.0;

      // Build category breakdown sorted descending
      final List<CategorySpending> breakdown = [];
      catTotals.forEach((catId, amount) {
        final meta = catMeta[catId];
        final name = meta?.name.value ?? 'Uncategorized';
        final color = meta?.colorHex.value ?? '0xFF94A3B8';
        final icon = meta?.iconName.value ?? 'category';
        final pct = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

        breakdown.add(CategorySpending(
          categoryId: catId,
          categoryName: name,
          colorHex: color,
          iconName: icon,
          totalAmount: amount,
          percentage: pct,
        ));
      });

      breakdown.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      return FinancialReport(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netSavings: netSavings,
        savingsRate: savingsRate,
        categoryBreakdown: breakdown,
        dailyExpenses: dailyMap,
        monthlyIncome: monthInc,
        monthlyExpense: monthExp,
      );
    });
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(databaseProvider));
});

final selectedDateRangeProvider = StateProvider<String>((ref) => 'this_month');

final financialReportStreamProvider = StreamProvider<FinancialReport>((ref) {
  final rangeKey = ref.watch(selectedDateRangeProvider);
  final now = DateTime.now();
  DateTime start;
  DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

  switch (rangeKey) {
    case 'last_month':
      final firstOfThisMonth = DateTime(now.year, now.month, 1);
      final lastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
      start = DateTime(lastMonth.year, lastMonth.month, 1);
      end = DateTime(lastMonth.year, lastMonth.month, lastMonth.day, 23, 59, 59);
      break;
    case 'last_30_days':
      start = now.subtract(const Duration(days: 30));
      break;
    case 'this_year':
      start = DateTime(now.year, 1, 1);
      break;
    case 'this_month':
    default:
      start = DateTime(now.year, now.month, 1);
      break;
  }

  return ref.watch(reportsRepositoryProvider).watchFinancialReport(
        startDate: start,
        endDate: end,
      );
});
