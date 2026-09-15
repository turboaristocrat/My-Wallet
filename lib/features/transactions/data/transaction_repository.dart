import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class TransactionRepository {
  final AppDatabase _db;
  TransactionRepository(this._db);

  /// Watch recent non-deleted transactions
  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) {
    return (_db.select(_db.transactions)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
                expression: tbl.transactionDate, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .watch();
  }

  /// Watch transactions with optional filters
  Stream<List<Transaction>> watchFilteredTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    final query = _db.select(_db.transactions)
      ..where((tbl) {
        var predicate = tbl.isDeleted.equals(false);
        if (accountId != null) {
          predicate = predicate &
              (tbl.accountId.equals(accountId) |
                  tbl.toAccountId.equals(accountId));
        }
        if (categoryId != null) {
          predicate = predicate & tbl.categoryId.equals(categoryId);
        }
        if (type != null && type != 'all') {
          predicate = predicate & tbl.type.equals(type);
        }
        if (startDate != null) {
          predicate = predicate & tbl.transactionDate.isBiggerOrEqualValue(startDate);
        }
        if (endDate != null) {
          predicate = predicate & tbl.transactionDate.isSmallerOrEqualValue(endDate);
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          predicate = predicate &
              (tbl.merchantName.like('%$searchQuery%') |
                  tbl.note.like('%$searchQuery%'));
        }
        return predicate;
      })
      ..orderBy([
        (tbl) => OrderingTerm(
            expression: tbl.transactionDate, mode: OrderingMode.desc)
      ]);
    return query.watch();
  }

  /// Create a transaction and automatically adjust account balances within a DB transaction
  Future<String> createTransaction({
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required String type, // 'expense', 'income', 'transfer'
    required double amount,
    required DateTime transactionDate,
    String? merchantName,
    String? note,
    String paymentType = 'upi',
    String? locationAddress,
    double? locationLat,
    double? locationLng,
    String status = 'cleared',
    String? rawSmsId,
    bool isAiParsed = false,
    double? aiConfidence,
  }) async {
    final id = const Uuid().v4();

    await _db.transaction(() async {
      // 1. Insert transaction
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: Value(id),
              accountId: accountId,
              toAccountId: Value(toAccountId),
              categoryId: Value(categoryId),
              type: type,
              amount: amount,
              transactionDate: transactionDate,
              merchantName: Value(merchantName),
              note: Value(note),
              paymentType: Value(paymentType),
              locationAddress: Value(locationAddress),
              locationLat: Value(locationLat),
              locationLng: Value(locationLng),
              status: Value(status),
              rawSmsId: Value(rawSmsId),
              isAiParsed: Value(isAiParsed),
              aiConfidence: Value(aiConfidence),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // 2. Adjust account balances
      final sourceAcc = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(accountId)))
          .getSingleOrNull();

      if (sourceAcc != null) {
        if (type == 'expense') {
          await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance - amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (type == 'income') {
          await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance + amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (type == 'transfer' && toAccountId != null) {
          // Deduct from source
          await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance - amount),
            updatedAt: Value(DateTime.now()),
          ));
          // Add to target
          final targetAcc = await (_db.select(_db.accounts)
                ..where((tbl) => tbl.id.equals(toAccountId)))
              .getSingleOrNull();
          if (targetAcc != null) {
            await (_db.update(_db.accounts)
                  ..where((tbl) => tbl.id.equals(toAccountId)))
                .write(AccountsCompanion(
              balance: Value(targetAcc.balance + amount),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }
    });

    return id;
  }

  /// Soft delete transaction and rollback account balance
  Future<void> softDeleteTransaction(String id) async {
    await _db.transaction(() async {
      final txn = await (_db.select(_db.transactions)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();
      if (txn == null || txn.isDeleted) return;

      // Mark as deleted
      await (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(id)))
          .write(TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));

      // Rollback balance
      final sourceAcc = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(txn.accountId)))
          .getSingleOrNull();

      if (sourceAcc != null) {
        if (txn.type == 'expense') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(txn.accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance + txn.amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (txn.type == 'income') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(txn.accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance - txn.amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (txn.type == 'transfer' && txn.toAccountId != null) {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(txn.accountId)))
              .write(AccountsCompanion(
            balance: Value(sourceAcc.balance + txn.amount),
            updatedAt: Value(DateTime.now()),
          ));
          final targetAcc = await (_db.select(_db.accounts)
                ..where((tbl) => tbl.id.equals(txn.toAccountId!)))
              .getSingleOrNull();
          if (targetAcc != null) {
            await (_db.update(_db.accounts)
                  ..where((tbl) => tbl.id.equals(txn.toAccountId!)))
                .write(AccountsCompanion(
              balance: Value(targetAcc.balance - txn.amount),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }
    });
  }

  /// Watch all categories
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final recentTransactionsStreamProvider =
    StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchRecentTransactions(limit: 5);
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchCategories();
});

final accountTransactionsStreamProvider =
    StreamProvider.family<List<Transaction>, String>((ref, accountId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchFilteredTransactions(accountId: accountId);
});
