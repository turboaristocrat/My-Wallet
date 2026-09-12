import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class RecurringWithDetails {
  final RecurringTemplate template;
  final Account? account;
  final Category? category;
  final int daysUntilDue;
  final bool isOverdue;
  final bool isDueToday;

  const RecurringWithDetails({
    required this.template,
    required this.account,
    required this.category,
    required this.daysUntilDue,
    required this.isOverdue,
    required this.isDueToday,
  });
}

class RecurringRepository {
  final AppDatabase _db;
  RecurringRepository(this._db);

  /// Watch active recurring templates joined with Account and Category
  Stream<List<RecurringWithDetails>> watchRecurringTemplates() {
    final query = _db.select(_db.recurringTemplates).join([
      leftOuterJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.recurringTemplates.accountId),
      ),
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.recurringTemplates.categoryId),
      ),
    ])..where(_db.recurringTemplates.isDeleted.equals(false));

    return query.watch().map((rows) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final list = rows.map((row) {
        final t = row.readTable(_db.recurringTemplates);
        final a = row.readTableOrNull(_db.accounts);
        final c = row.readTableOrNull(_db.categories);

        final dueDateMidnight =
            DateTime(t.nextDueDate.year, t.nextDueDate.month, t.nextDueDate.day);
        final differenceDays = dueDateMidnight.difference(today).inDays;

        return RecurringWithDetails(
          template: t,
          account: a,
          category: c,
          daysUntilDue: differenceDays,
          isOverdue: differenceDays < 0,
          isDueToday: differenceDays == 0,
        );
      }).toList();

      // Sort by nextDueDate ascending
      list.sort((a, b) => a.template.nextDueDate.compareTo(b.template.nextDueDate));
      return list;
    });
  }

  /// Calculates total monthly equivalent financial commitment across templates
  double calculateMonthlyCommitment(List<RecurringTemplate> templates) {
    double monthlyTotal = 0.0;
    for (final t in templates) {
      final freq = t.frequency.toLowerCase();
      switch (freq) {
        case 'daily':
          monthlyTotal += t.amount * 30.0;
          break;
        case 'weekly':
          monthlyTotal += t.amount * (52.0 / 12.0);
          break;
        case 'yearly':
        case 'annual':
          monthlyTotal += t.amount / 12.0;
          break;
        case 'quarterly':
          monthlyTotal += t.amount / 3.0;
          break;
        case 'monthly':
        default:
          monthlyTotal += t.amount;
          break;
      }
    }
    return monthlyTotal;
  }

  /// Calculates next due date based on current due date and frequency
  DateTime computeNextDueDate(DateTime currentDue, String frequency) {
    final freq = frequency.toLowerCase();
    switch (freq) {
      case 'daily':
        return currentDue.add(const Duration(days: 1));
      case 'weekly':
        return currentDue.add(const Duration(days: 7));
      case 'quarterly':
        return DateTime(currentDue.year, currentDue.month + 3, currentDue.day);
      case 'yearly':
      case 'annual':
        return DateTime(currentDue.year + 1, currentDue.month, currentDue.day);
      case 'monthly':
      default:
        return DateTime(currentDue.year, currentDue.month + 1, currentDue.day);
    }
  }

  /// Create a new recurring subscription template
  Future<String> createRecurringTemplate({
    required String title,
    required double amount,
    required String accountId,
    required String categoryId,
    required String frequency,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool autoLog = false,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            id: Value(id),
            title: title,
            amount: amount,
            accountId: accountId,
            categoryId: categoryId,
            frequency: frequency,
            startDate: startDate,
            nextDueDate: nextDueDate,
            autoLog: Value(autoLog),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Mark payment as paid: Atomically logs a ledger transaction and advances nextDueDate
  Future<void> markAsPaid(String templateId, {DateTime? paidDate}) async {
    final now = paidDate ?? DateTime.now();

    await _db.transaction(() async {
      final template = await (_db.select(_db.recurringTemplates)
            ..where((tbl) => tbl.id.equals(templateId)))
          .getSingleOrNull();

      if (template == null) return;

      // 1. Insert transaction into transactions table
      final txId = const Uuid().v4();
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: Value(txId),
              accountId: template.accountId,
              categoryId: Value(template.categoryId),
              type: 'expense',
              amount: template.amount,
              transactionDate: now,
              merchantName: Value(template.title),
              note: Value('Recurring auto/manual bill: ${template.title}'),
              paymentType: const Value('auto_debit'),
              status: const Value('cleared'),
              updatedAt: Value(now),
            ),
          );

      // 2. Adjust account balance
      final acc = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(template.accountId)))
          .getSingleOrNull();

      if (acc != null) {
        await (_db.update(_db.accounts)
              ..where((tbl) => tbl.id.equals(template.accountId)))
            .write(AccountsCompanion(
          balance: Value(acc.balance - template.amount),
          updatedAt: Value(now),
        ));
      }

      // 3. Advance next due date
      final nextDate = computeNextDueDate(template.nextDueDate, template.frequency);
      await (_db.update(_db.recurringTemplates)
            ..where((tbl) => tbl.id.equals(templateId)))
          .write(RecurringTemplatesCompanion(
        nextDueDate: Value(nextDate),
        updatedAt: Value(now),
      ));
    });
  }

  /// Skip current cycle without logging an expense
  Future<void> skipCycle(String templateId) async {
    final template = await (_db.select(_db.recurringTemplates)
          ..where((tbl) => tbl.id.equals(templateId)))
        .getSingleOrNull();

    if (template == null) return;

    final nextDate = computeNextDueDate(template.nextDueDate, template.frequency);
    await (_db.update(_db.recurringTemplates)
          ..where((tbl) => tbl.id.equals(templateId)))
        .write(RecurringTemplatesCompanion(
      nextDueDate: Value(nextDate),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Toggle autoLog status
  Future<void> toggleAutoLog(String templateId, bool autoLog) async {
    await (_db.update(_db.recurringTemplates)
          ..where((tbl) => tbl.id.equals(templateId)))
        .write(RecurringTemplatesCompanion(
      autoLog: Value(autoLog),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Delete recurring subscription
  Future<void> deleteRecurringTemplate(String templateId) async {
    await (_db.update(_db.recurringTemplates)
          ..where((tbl) => tbl.id.equals(templateId)))
        .write(RecurringTemplatesCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }
}

// --- Riverpod Providers ---

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(databaseProvider));
});

final recurringTemplatesStreamProvider =
    StreamProvider<List<RecurringWithDetails>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchRecurringTemplates();
});

final recurringFrequencyFilterProvider =
    StateProvider<String>((ref) => 'all');
