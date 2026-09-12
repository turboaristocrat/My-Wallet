import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/backup/data/backup_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late BackupRepository backupRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backupRepo = BackupRepository(db);

    // Seed test data
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: const Value('acc-1'),
            name: 'ICICI Bank Salary',
            type: 'bank',
            balance: const Value(75000.0),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: const Value('cat-1'),
            name: 'Dining & Restaurants',
            iconName: 'restaurant',
            colorHex: const Value('#F43F5E'),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: const Value('tx-1'),
            accountId: 'acc-1',
            categoryId: const Value('cat-1'),
            type: 'expense',
            amount: 1450.0,
            transactionDate: DateTime(2026, 9, 10, 19, 30),
            merchantName: const Value('Toit Brewpub, Indiranagar'),
            note: const Value('Team dinner, food was great!'),
            paymentType: const Value('upi'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Backup & Export Repository Tests', () {
    test('exportTransactionsToCsv generates properly formatted and escaped CSV', () async {
      final csv = await backupRepo.exportTransactionsToCsv();

      expect(csv, contains('Transaction ID,Date,Type,Amount,Currency,Category,Account,Merchant,Note,Payment Type,Status'));
      expect(csv, contains('tx-1'));
      expect(csv, contains('1450.00'));
      expect(csv, contains('Dining & Restaurants'));
      expect(csv, contains('ICICI Bank Salary'));
      // Check escaping of commas in merchant name and note
      expect(csv, contains('"Toit Brewpub, Indiranagar"'));
      expect(csv, contains('"Team dinner, food was great!"'));
    });

    test('exportAccountsToCsv exports accounts with current balances', () async {
      final csv = await backupRepo.exportAccountsToCsv();

      expect(csv, contains('Account ID,Account Name,Type,Current Balance,Currency,Updated At'));
      expect(csv, contains('acc-1'));
      expect(csv, contains('ICICI Bank Salary'));
      expect(csv, contains('75000.00'));
    });

    test('generateFullBackupJson and restoreFromBackupJson successfully migrates all tables', () async {
      // 1. Generate full backup
      final jsonBackup = await backupRepo.generateFullBackupJson();
      expect(jsonBackup, contains('"appName": "My Wallet"'));
      expect(jsonBackup, contains('"accounts"'));
      expect(jsonBackup, contains('ICICI Bank Salary'));
      expect(jsonBackup, contains('Toit Brewpub, Indiranagar'));

      // 2. Create a clean secondary in-memory database
      final newDb = AppDatabase(NativeDatabase.memory());
      final newBackupRepo = BackupRepository(newDb);

      // Verify secondary DB is initially empty
      final initialAccs = await newDb.select(newDb.accounts).get();
      expect(initialAccs.isEmpty, true);

      // 3. Restore data into new database
      final restoreResult = await newBackupRepo.restoreFromBackupJson(jsonBackup);
      expect(restoreResult.isSuccess, true);
      expect(restoreResult.restoredCounts['accounts'], 1);
      expect(restoreResult.restoredCounts['transactions'], 1);
      expect(restoreResult.restoredCounts['categories'], greaterThanOrEqualTo(1));

      // 4. Verify data in new database
      final restoredAccounts = await newDb.select(newDb.accounts).get();
      expect(restoredAccounts.length, 1);
      expect(restoredAccounts.first.name, 'ICICI Bank Salary');
      expect(restoredAccounts.first.balance, 75000.0);

      final restoredTxs = await newDb.select(newDb.transactions).get();
      expect(restoredTxs.length, 1);
      expect(restoredTxs.first.merchantName, 'Toit Brewpub, Indiranagar');
      expect(restoredTxs.first.amount, 1450.0);

      await newDb.close();
    });

    test('clearAllUserData removes user transactions and accounts safely', () async {
      await backupRepo.clearAllUserData();

      final accs = await db.select(db.accounts).get();
      expect(accs.isEmpty, true);

      final txs = await db.select(db.transactions).get();
      expect(txs.isEmpty, true);
    });
  });
}
