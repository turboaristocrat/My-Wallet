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

  /// Delete transaction (calls soft delete)
  Future<void> deleteTransaction(String id) => softDeleteTransaction(id);

  /// Update existing transaction and properly recalculate account balances
  Future<void> updateTransaction({
    required String id,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required String type,
    required double amount,
    required DateTime transactionDate,
    String? merchantName,
    String? note,
    String paymentType = 'upi',
    String status = 'cleared',
  }) async {
    await _db.transaction(() async {
      final oldTxn = await (_db.select(_db.transactions)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();
      if (oldTxn == null || oldTxn.isDeleted) return;

      // 1. Rollback old balance impact
      final oldSourceAcc = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(oldTxn.accountId)))
          .getSingleOrNull();
      if (oldSourceAcc != null) {
        if (oldTxn.type == 'expense') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(oldTxn.accountId)))
              .write(AccountsCompanion(
            balance: Value(oldSourceAcc.balance + oldTxn.amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (oldTxn.type == 'income') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(oldTxn.accountId)))
              .write(AccountsCompanion(
            balance: Value(oldSourceAcc.balance - oldTxn.amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (oldTxn.type == 'transfer' && oldTxn.toAccountId != null) {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(oldTxn.accountId)))
              .write(AccountsCompanion(
            balance: Value(oldSourceAcc.balance + oldTxn.amount),
            updatedAt: Value(DateTime.now()),
          ));
          final oldTargetAcc = await (_db.select(_db.accounts)
                ..where((tbl) => tbl.id.equals(oldTxn.toAccountId!)))
              .getSingleOrNull();
          if (oldTargetAcc != null) {
            await (_db.update(_db.accounts)
                  ..where((tbl) => tbl.id.equals(oldTxn.toAccountId!)))
                .write(AccountsCompanion(
              balance: Value(oldTargetAcc.balance - oldTxn.amount),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }

      // 2. Update the transaction row
      await (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(id)))
          .write(TransactionsCompanion(
        accountId: Value(accountId),
        toAccountId: Value(toAccountId),
        categoryId: Value(categoryId),
        type: Value(type),
        amount: Value(amount),
        transactionDate: Value(transactionDate),
        merchantName: Value(merchantName),
        note: Value(note),
        paymentType: Value(paymentType),
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ));

      // 3. Apply new balance impact
      final newSourceAcc = await (_db.select(_db.accounts)
            ..where((tbl) => tbl.id.equals(accountId)))
          .getSingleOrNull();
      if (newSourceAcc != null) {
        if (type == 'expense') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(newSourceAcc.balance - amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (type == 'income') {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(newSourceAcc.balance + amount),
            updatedAt: Value(DateTime.now()),
          ));
        } else if (type == 'transfer' && toAccountId != null) {
          await (_db.update(_db.accounts)
                ..where((tbl) => tbl.id.equals(accountId)))
              .write(AccountsCompanion(
            balance: Value(newSourceAcc.balance - amount),
            updatedAt: Value(DateTime.now()),
          ));
          final newTargetAcc = await (_db.select(_db.accounts)
                ..where((tbl) => tbl.id.equals(toAccountId)))
              .getSingleOrNull();
          if (newTargetAcc != null) {
            await (_db.update(_db.accounts)
                  ..where((tbl) => tbl.id.equals(toAccountId)))
                .write(AccountsCompanion(
              balance: Value(newTargetAcc.balance + amount),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }
    });
  }

  /// Watch all categories (including subcategories)
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Watch only top-level parent categories
  Stream<List<Category>> watchParentCategories() {
    return (_db.select(_db.categories)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.parentId.isNull())
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Watch subcategories for a given parent category ID
  Stream<List<Category>> watchSubcategories(String parentId) {
    return (_db.select(_db.categories)
          ..where((tbl) =>
              tbl.isDeleted.equals(false) & tbl.parentId.equals(parentId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Create a new category or subcategory
  Future<String> createCategory({
    required String name,
    required String iconName,
    String colorHex = '0xFF008080',
    String? parentId,
    bool isDefault = false,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: Value(id),
            name: name,
            iconName: iconName,
            colorHex: Value(colorHex),
            parentId: Value(parentId),
            isDefault: Value(isDefault),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Update an existing category
  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconName,
    String? colorHex,
    String? parentId,
  }) async {
    await (_db.update(_db.categories)..where((tbl) => tbl.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        iconName: Value(iconName),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a category (and cascade soft delete its subcategories)
  Future<void> deleteCategory(String id) async {
    await _db.transaction(() async {
      // Soft delete category
      await (_db.update(_db.categories)..where((tbl) => tbl.id.equals(id)))
          .write(CategoriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));

      // Soft delete all child subcategories
      await (_db.update(_db.categories)..where((tbl) => tbl.parentId.equals(id)))
          .write(CategoriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  // --- Tags Management ---

  /// Watch all non-deleted tags
  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tags)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Create a tag
  Future<String> createTag({
    required String name,
    String colorHex = '0xFF26B2AB',
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: Value(id),
            name: name,
            colorHex: Value(colorHex),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Update a tag
  Future<void> updateTag({
    required String id,
    required String name,
    String? colorHex,
  }) async {
    await (_db.update(_db.tags)..where((tbl) => tbl.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a tag
  Future<void> deleteTag(String id) async {
    await (_db.update(_db.tags)..where((tbl) => tbl.id.equals(id))).write(
      TagsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Set tags for a transaction (replaces existing tags for this transaction)
  Future<void> setTransactionTags(String transactionId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.transactionTags)
            ..where((tbl) => tbl.transactionId.equals(transactionId)))
          .go();

      for (final tagId in tagIds) {
        await _db.into(_db.transactionTags).insert(
              TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// Get tag IDs associated with a transaction
  Future<List<String>> getTransactionTags(String transactionId) async {
    final rows = await (_db.select(_db.transactionTags)
          ..where((tbl) => tbl.transactionId.equals(transactionId)))
        .get();
    return rows.map((r) => r.tagId).toList();
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

final parentCategoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchParentCategories();
});

final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTags();
});

final accountTransactionsStreamProvider =
    StreamProvider.family<List<Transaction>, String>((ref, accountId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchFilteredTransactions(accountId: accountId);
});
