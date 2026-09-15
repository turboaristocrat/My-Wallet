import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class AccountRepository {
  final AppDatabase _db;
  AccountRepository(this._db);

  /// Watch all un-archived, non-deleted accounts reactively
  Stream<List<Account>> watchActiveAccounts() {
    return (_db.select(_db.accounts)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.isArchived.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Watch all accounts (including archived) for settings
  Stream<List<Account>> watchAllAccounts() {
    return (_db.select(_db.accounts)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.name)]))
        .watch();
  }

  /// Get single account by ID
  Future<Account?> getAccountById(String id) {
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create new account
  Future<String> createAccount({
    required String name,
    required String type,
    String? accountNumberMask,
    String colorHex = '0xFF008080',
    double initialBalance = 0.0,
    double? creditLimit,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: Value(id),
            name: name,
            type: type,
            accountNumberMask: Value(accountNumberMask),
            colorHex: Value(colorHex),
            balance: Value(initialBalance),
            creditLimit: Value(creditLimit),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Update account details
  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    String? accountNumberMask,
    String? colorHex,
    double? balance,
    double? creditLimit,
  }) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        name: Value(name),
        type: Value(type),
        accountNumberMask: Value(accountNumberMask),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        balance: balance != null ? Value(balance) : const Value.absent(),
        creditLimit: creditLimit != null ? Value(creditLimit) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_upload'),
      ),
    );
  }

  /// Update balance by delta (positive for income/credit, negative for expense/debit)
  Future<void> updateBalance(String id, double delta) async {
    final account = await getAccountById(id);
    if (account != null) {
      final newBalance = account.balance + delta;
      await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
        AccountsCompanion(
          balance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pending_upload'),
        ),
      );
    }
  }

  /// Archive or unarchive an account
  Future<void> setArchived(String id, bool archived) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_upload'),
      ),
    );
  }

  /// Soft delete an account
  Future<void> softDelete(String id) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_upload'),
      ),
    );
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final activeAccountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchActiveAccounts();
});
