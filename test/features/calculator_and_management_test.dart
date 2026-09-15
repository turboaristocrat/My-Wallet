import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/accounts/data/account_repository.dart';
import 'package:my_wallet/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository txnRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    txnRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Category and Subcategory Management Tests', () {
    test('creates parent category and subcategory, streams hierarchy correctly', () async {
      final parentId = await txnRepo.createCategory(
        name: 'Food & Dining',
        iconName: 'restaurant',
        colorHex: '0xFFF59E0B',
      );

      final subId = await txnRepo.createCategory(
        name: 'Coffee & Snacks',
        iconName: 'local_cafe',
        colorHex: '0xFFF59E0B',
        parentId: parentId,
      );

      final parents = await txnRepo.watchParentCategories().first;
      expect(parents.any((c) => c.id == parentId), isTrue);

      final subs = await txnRepo.watchSubcategories(parentId).first;
      expect(subs.any((c) => c.id == subId), isTrue);
      expect(subs.first.name, 'Coffee & Snacks');

      // Update subcategory
      await txnRepo.updateCategory(
        id: subId,
        name: 'Specialty Coffee',
        iconName: 'coffee',
      );

      final updatedSubs = await txnRepo.watchSubcategories(parentId).first;
      expect(updatedSubs.first.name, 'Specialty Coffee');
    });
  });

  group('Tags Management Tests', () {
    test('creates, updates, assigns tags to transaction and retrieves them', () async {
      final accId = await accountRepo.createAccount(
        name: 'Savings',
        type: 'savings',
        initialBalance: 10000.0,
      );

      final tag1 = await txnRepo.createTag(name: 'Business', colorHex: '0xFF3B82F6');
      final tag2 = await txnRepo.createTag(name: 'TaxDeductible', colorHex: '0xFF10B981');

      final tags = await txnRepo.watchTags().first;
      expect(tags.length, 2);

      final txnId = await txnRepo.createTransaction(
        accountId: accId,
        type: 'expense',
        amount: 250.0,
        transactionDate: DateTime.now(),
      );

      await txnRepo.setTransactionTags(txnId, [tag1, tag2]);
      final txnTags = await txnRepo.getTransactionTags(txnId);
      expect(txnTags.length, 2);
      expect(txnTags.contains(tag1), isTrue);
      expect(txnTags.contains(tag2), isTrue);
    });
  });

  group('Account Management and Transaction Edit Balance Rollback Tests', () {
    test('updateAccount updates name, type, and balance correctly', () async {
      final accId = await accountRepo.createAccount(
        name: 'Old Bank',
        type: 'savings',
        initialBalance: 5000.0,
      );

      await accountRepo.updateAccount(
        id: accId,
        name: 'HDFC Salary Bank',
        type: 'savings',
        balance: 6500.0,
      );

      final updated = await accountRepo.getAccountById(accId);
      expect(updated?.name, 'HDFC Salary Bank');
      expect(updated?.balance, 6500.0);
    });

    test('updateTransaction rolls back old amount and applies new amount to account balance', () async {
      final accId = await accountRepo.createAccount(
        name: 'Checking',
        type: 'savings',
        initialBalance: 1000.0,
      );

      // Create an expense of 200 -> Balance becomes 800
      final txnId = await txnRepo.createTransaction(
        accountId: accId,
        type: 'expense',
        amount: 200.0,
        transactionDate: DateTime.now(),
      );

      var acc = await accountRepo.getAccountById(accId);
      expect(acc?.balance, 800.0);

      // Update the expense to 150 -> Balance should roll back 200 (1000) and deduct 150 -> 850
      await txnRepo.updateTransaction(
        id: txnId,
        accountId: accId,
        type: 'expense',
        amount: 150.0,
        transactionDate: DateTime.now(),
      );

      acc = await accountRepo.getAccountById(accId);
      expect(acc?.balance, 850.0);
    });
  });
}
