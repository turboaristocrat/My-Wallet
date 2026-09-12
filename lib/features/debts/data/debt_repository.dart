import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class DebtWithRecords {
  final Debt debt;
  final List<DebtRecord> records;
  final Account? linkedAccount;
  final double totalRepaid;
  final double progressRatio; // 0.0 to 1.0

  const DebtWithRecords({
    required this.debt,
    required this.records,
    required this.linkedAccount,
    required this.totalRepaid,
    required this.progressRatio,
  });
}

class NetDebtSummary {
  final double totalLent;
  final double totalBorrowed;
  final double totalFormalLoans;
  final double netPosition; // totalLent - (totalBorrowed + totalFormalLoans)

  const NetDebtSummary({
    required this.totalLent,
    required this.totalBorrowed,
    required this.totalFormalLoans,
    required this.netPosition,
  });
}

class DebtRepository {
  final AppDatabase _db;
  DebtRepository(this._db);

  /// Watch active and closed debts with linked repayments
  Stream<List<DebtWithRecords>> watchDebts({String? debtType}) {
    final query = _db.select(_db.debts)
      ..where((tbl) => tbl.isDeleted.equals(false));

    if (debtType != null && debtType != 'all') {
      query.where((tbl) => tbl.debtType.equals(debtType));
    }

    query.orderBy([
      (tbl) => OrderingTerm(expression: tbl.status, mode: OrderingMode.asc),
      (tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc),
    ]);

    return query.watch().asyncMap((debtsList) async {
      final List<DebtWithRecords> result = [];

      for (final debt in debtsList) {
        // Fetch repayments
        final records = await (_db.select(_db.debtRecords)
              ..where((r) => r.debtId.equals(debt.id))
              ..where((r) => r.isDeleted.equals(false))
              ..orderBy([(r) => OrderingTerm(expression: r.paidDate, mode: OrderingMode.desc)]))
            .get();

        // Fetch linked account if present
        Account? account;
        if (debt.linkedAccountId != null) {
          account = await (_db.select(_db.accounts)
                ..where((a) => a.id.equals(debt.linkedAccountId!)))
              .getSingleOrNull();
        }

        final totalRepaid = max(0.0, debt.principalAmount - debt.remainingAmount);
        final ratio = debt.principalAmount > 0
            ? (totalRepaid / debt.principalAmount).clamp(0.0, 1.0)
            : 1.0;

        result.add(DebtWithRecords(
          debt: debt,
          records: records,
          linkedAccount: account,
          totalRepaid: totalRepaid,
          progressRatio: ratio,
        ));
      }
      return result;
    });
  }

  /// Calculates total lent, borrowed, and net position
  NetDebtSummary calculateNetDebtSummary(List<Debt> debts) {
    double lent = 0.0;
    double borrowed = 0.0;
    double loans = 0.0;

    for (final d in debts) {
      if (d.status == 'closed' || d.isDeleted) continue;
      if (d.debtType == 'i_lent') {
        lent += d.remainingAmount;
      } else if (d.debtType == 'i_borrowed') {
        borrowed += d.remainingAmount;
      } else if (d.debtType == 'formal_loan') {
        loans += d.remainingAmount;
      }
    }

    return NetDebtSummary(
      totalLent: lent,
      totalBorrowed: borrowed,
      totalFormalLoans: loans,
      netPosition: lent - (borrowed + loans),
    );
  }

  /// Create a new debt or loan entry
  Future<String> createDebt({
    required String debtType, // 'i_lent', 'i_borrowed', 'formal_loan'
    required String contactName,
    required String purpose,
    required double principalAmount,
    double? interestRate,
    double? emiAmount,
    DateTime? nextEmiDate,
    String? linkedAccountId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.debts).insert(
          DebtsCompanion.insert(
            id: Value(id),
            debtType: debtType,
            contactName: contactName,
            purpose: purpose,
            principalAmount: principalAmount,
            remainingAmount: principalAmount,
            interestRate: Value(interestRate),
            emiAmount: Value(emiAmount),
            nextEmiDate: Value(nextEmiDate),
            linkedAccountId: Value(linkedAccountId),
            status: const Value('active'),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Record a partial or full repayment
  Future<void> recordRepayment({
    required String debtId,
    required double amount,
    String? accountId,
    String? note,
    DateTime? paidDate,
  }) async {
    final now = paidDate ?? DateTime.now();
    final recordId = const Uuid().v4();

    await _db.transaction(() async {
      final debt = await (_db.select(_db.debts)
            ..where((tbl) => tbl.id.equals(debtId)))
          .getSingleOrNull();

      if (debt == null) return;

      // 1. Insert repayment record
      await _db.into(_db.debtRecords).insert(
            DebtRecordsCompanion.insert(
              id: Value(recordId),
              debtId: debtId,
              amount: amount,
              paidDate: now,
              accountId: Value(accountId),
              note: Value(note),
              updatedAt: Value(now),
            ),
          );

      // 2. Compute new remaining amount
      final newRemaining = max(0.0, debt.remainingAmount - amount);
      final newStatus = newRemaining <= 0.001 ? 'closed' : debt.status;

      await (_db.update(_db.debts)..where((tbl) => tbl.id.equals(debtId)))
          .write(DebtsCompanion(
        remainingAmount: Value(newRemaining),
        status: Value(newStatus),
        updatedAt: Value(now),
      ));

      // 3. Update account balance if accountId is provided
      if (accountId != null) {
        final acc = await (_db.select(_db.accounts)
              ..where((tbl) => tbl.id.equals(accountId)))
            .getSingleOrNull();

        if (acc != null) {
          // If 'i_lent', user received money back (+ balance)
          // If 'i_borrowed' or 'formal_loan', user paid money out (- balance)
          final balanceDelta = (debt.debtType == 'i_lent') ? amount : -amount;

          await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(acc.balance + balanceDelta),
            updatedAt: Value(now),
          ));
        }
      }
    });
  }

  /// Mark debt as fully settled/closed
  Future<void> closeDebt(String debtId) async {
    await (_db.update(_db.debts)..where((tbl) => tbl.id.equals(debtId))).write(
      DebtsCompanion(
        remainingAmount: const Value(0.0),
        status: const Value('closed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a debt (soft-delete)
  Future<void> deleteDebt(String debtId) async {
    await (_db.update(_db.debts)..where((tbl) => tbl.id.equals(debtId))).write(
      DebtsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

// --- Riverpod Providers ---

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.watch(databaseProvider));
});

final debtsStreamProvider = StreamProvider<List<DebtWithRecords>>((ref) {
  return ref.watch(debtRepositoryProvider).watchDebts();
});

final selectedDebtTabProvider = StateProvider<String>((ref) => 'i_lent');
