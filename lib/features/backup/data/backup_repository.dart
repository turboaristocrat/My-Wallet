import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class RestoreResult {
  final bool isSuccess;
  final String message;
  final Map<String, int> restoredCounts;

  const RestoreResult({
    required this.isSuccess,
    required this.message,
    required this.restoredCounts,
  });
}

class BackupRepository {
  final AppDatabase _db;
  BackupRepository(this._db);

  /// Escape a CSV field value
  String _escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Export all non-deleted transactions to CSV format
  Future<String> exportTransactionsToCsv() async {
    final transactions = await (_db.select(_db.transactions)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
                expression: tbl.transactionDate, mode: OrderingMode.desc)
          ]))
        .get();

    final accounts = await (_db.select(_db.accounts)).get();
    final categories = await (_db.select(_db.categories)).get();

    final accountMap = {for (final a in accounts) a.id: a.name};
    final categoryMap = {for (final c in categories) c.id: c.name};

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'Transaction ID,Date,Type,Amount,Currency,Category,Account,Merchant,Note,Payment Type,Status');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final tx in transactions) {
      final accName = accountMap[tx.accountId] ?? tx.accountId;
      final catName =
          tx.categoryId != null ? (categoryMap[tx.categoryId!] ?? '') : '';

      final row = [
        _escapeCsv(tx.id),
        _escapeCsv(dateFormat.format(tx.transactionDate)),
        _escapeCsv(tx.type),
        _escapeCsv(tx.amount.toStringAsFixed(2)),
        _escapeCsv(tx.currency),
        _escapeCsv(catName),
        _escapeCsv(accName),
        _escapeCsv(tx.merchantName ?? ''),
        _escapeCsv(tx.note ?? ''),
        _escapeCsv(tx.paymentType),
        _escapeCsv(tx.status),
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Export all non-deleted accounts to CSV format
  Future<String> exportAccountsToCsv() async {
    final accounts = await (_db.select(_db.accounts)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .get();

    final buffer = StringBuffer();
    buffer.writeln('Account ID,Account Name,Type,Current Balance,Currency,Updated At');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final a in accounts) {
      final row = [
        _escapeCsv(a.id),
        _escapeCsv(a.name),
        _escapeCsv(a.type),
        _escapeCsv(a.balance.toStringAsFixed(2)),
        _escapeCsv('INR'),
        _escapeCsv(dateFormat.format(a.updatedAt)),
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// Generate a complete JSON backup of the entire SQLite database
  Future<String> generateFullBackupJson() async {
    final accounts = await (_db.select(_db.accounts)).get();
    final categories = await (_db.select(_db.categories)).get();
    final transactions = await (_db.select(_db.transactions)).get();
    final budgets = await (_db.select(_db.budgets)).get();
    final goals = await (_db.select(_db.goals)).get();
    final recurring = await (_db.select(_db.recurringTemplates)).get();
    final debts = await (_db.select(_db.debts)).get();
    final debtRecords = await (_db.select(_db.debtRecords)).get();
    final autoRules = await (_db.select(_db.autoRules)).get();

    final backupMap = {
      'metadata': {
        'appName': 'My Wallet',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'counts': {
          'accounts': accounts.length,
          'categories': categories.length,
          'transactions': transactions.length,
          'budgets': budgets.length,
          'goals': goals.length,
          'recurringTemplates': recurring.length,
          'debts': debts.length,
          'debtRecords': debtRecords.length,
          'autoRules': autoRules.length,
        },
      },
      'data': {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'budgets': budgets.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'recurringTemplates': recurring.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'debtRecords': debtRecords.map((e) => e.toJson()).toList(),
        'autoRules': autoRules.map((e) => e.toJson()).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(backupMap);
  }

  /// Restore database from a backup JSON string
  Future<RestoreResult> restoreFromBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
        return const RestoreResult(
          isSuccess: false,
          message: 'Invalid backup file structure. Missing data section.',
          restoredCounts: {},
        );
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final Map<String, int> counts = {};

      await _db.transaction(() async {
        // 1. Accounts
        if (data.containsKey('accounts')) {
          final items = (data['accounts'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.accounts).insertOnConflictUpdate(Account.fromJson(item));
          }
          counts['accounts'] = items.length;
        }

        // 2. Categories
        if (data.containsKey('categories')) {
          final items = (data['categories'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.categories).insertOnConflictUpdate(Category.fromJson(item));
          }
          counts['categories'] = items.length;
        }

        // 3. Transactions
        if (data.containsKey('transactions')) {
          final items = (data['transactions'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.transactions).insertOnConflictUpdate(Transaction.fromJson(item));
          }
          counts['transactions'] = items.length;
        }

        // 4. Budgets
        if (data.containsKey('budgets')) {
          final items = (data['budgets'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.budgets).insertOnConflictUpdate(Budget.fromJson(item));
          }
          counts['budgets'] = items.length;
        }

        // 5. Goals
        if (data.containsKey('goals')) {
          final items = (data['goals'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.goals).insertOnConflictUpdate(Goal.fromJson(item));
          }
          counts['goals'] = items.length;
        }

        // 6. Recurring Templates
        if (data.containsKey('recurringTemplates')) {
          final items =
              (data['recurringTemplates'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db
                .into(_db.recurringTemplates)
                .insertOnConflictUpdate(RecurringTemplate.fromJson(item));
          }
          counts['recurringTemplates'] = items.length;
        }

        // 7. Debts
        if (data.containsKey('debts')) {
          final items = (data['debts'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.debts).insertOnConflictUpdate(Debt.fromJson(item));
          }
          counts['debts'] = items.length;
        }

        // 8. Debt Records
        if (data.containsKey('debtRecords')) {
          final items =
              (data['debtRecords'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db
                .into(_db.debtRecords)
                .insertOnConflictUpdate(DebtRecord.fromJson(item));
          }
          counts['debtRecords'] = items.length;
        }

        // 9. Auto Rules
        if (data.containsKey('autoRules')) {
          final items = (data['autoRules'] as List).cast<Map<String, dynamic>>();
          for (final item in items) {
            await _db.into(_db.autoRules).insertOnConflictUpdate(AutoRule.fromJson(item));
          }
          counts['autoRules'] = items.length;
        }
      });

      return RestoreResult(
        isSuccess: true,
        message: 'Successfully restored all backup records.',
        restoredCounts: counts,
      );
    } catch (e) {
      return RestoreResult(
        isSuccess: false,
        message: 'Failed to restore backup: $e',
        restoredCounts: {},
      );
    }
  }

  /// Safety erase all non-default user data
  Future<void> clearAllUserData() async {
    await _db.transaction(() async {
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.smsReviewQueue).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.recurringTemplates).go();
      await _db.delete(_db.debtRecords).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.autoRules).go();
      await _db.delete(_db.accounts).go();
    });
  }
}

// --- Provider ---

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(databaseProvider));
});
