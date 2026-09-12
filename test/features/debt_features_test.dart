import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/debts/data/debt_repository.dart';

void main() {
  late AppDatabase db;
  late DebtRepository debtRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    debtRepo = DebtRepository(db);

    // Create a dummy account with 20000 balance
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: const Value('acc-1'),
            name: 'SBI Savings Account',
            type: 'bank',
            balance: const Value(20000.0),
            updatedAt: Value(DateTime.now()),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Debt Repository Tests', () {
    test('calculates net debt position correctly across lent and borrowed', () {
      final now = DateTime.now();
      final debts = [
        Debt(
          id: '1',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          syncStatus: 'synced',
          debtType: 'i_lent',
          contactName: 'Rahul',
          purpose: 'Weekend Trip',
          principalAmount: 5000.0,
          remainingAmount: 3000.0,
          status: 'active',
        ),
        Debt(
          id: '2',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          syncStatus: 'synced',
          debtType: 'i_borrowed',
          contactName: 'Priya',
          purpose: 'Concert Tickets',
          principalAmount: 2000.0,
          remainingAmount: 1000.0,
          status: 'active',
        ),
        Debt(
          id: '3',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          syncStatus: 'synced',
          debtType: 'formal_loan',
          contactName: 'HDFC Bank',
          purpose: 'Two Wheeler Loan',
          principalAmount: 50000.0,
          remainingAmount: 15000.0,
          status: 'active',
        ),
      ];

      final summary = debtRepo.calculateNetDebtSummary(debts);
      expect(summary.totalLent, 3000.0);
      expect(summary.totalBorrowed, 1000.0);
      expect(summary.totalFormalLoans, 15000.0);
      // Net: 3000 - (1000 + 15000) = -13000
      expect(summary.netPosition, -13000.0);
    });

    test('creates debt and streams list with progress calculation', () async {
      final debtId = await debtRepo.createDebt(
        debtType: 'i_lent',
        contactName: 'Ankit Sharma',
        purpose: 'Office Lunch',
        principalAmount: 1200.0,
      );

      expect(debtId, isNotEmpty);

      final list = await debtRepo.watchDebts().first;
      expect(list.length, 1);
      final item = list.first;
      expect(item.debt.contactName, 'Ankit Sharma');
      expect(item.debt.principalAmount, 1200.0);
      expect(item.debt.remainingAmount, 1200.0);
      expect(item.totalRepaid, 0.0);
      expect(item.progressRatio, 0.0);
    });

    test('partial repayment updates remaining balance and linked account balance', () async {
      final debtId = await debtRepo.createDebt(
        debtType: 'i_lent',
        contactName: 'Kavita',
        purpose: 'Laptop repair',
        principalAmount: 6000.0,
        linkedAccountId: 'acc-1',
      );

      // Initial account balance: 20000
      var acc = await (db.select(db.accounts)..where((t) => t.id.equals('acc-1'))).getSingle();
      expect(acc.balance, 20000.0);

      // Record repayment of 2500 into acc-1
      await debtRepo.recordRepayment(
        debtId: debtId,
        amount: 2500.0,
        accountId: 'acc-1',
        note: 'UPI transfer received',
      );

      // 1. Debt remaining amount should now be 3500
      final updatedDebt = await (db.select(db.debts)..where((t) => t.id.equals(debtId))).getSingle();
      expect(updatedDebt.remainingAmount, 3500.0);
      expect(updatedDebt.status, 'active');

      // 2. Account balance should be 20000 + 2500 = 22500
      acc = await (db.select(db.accounts)..where((t) => t.id.equals('acc-1'))).getSingle();
      expect(acc.balance, 22500.0);

      // 3. DebtRecords table should have 1 entry
      final records = await (db.select(db.debtRecords)..where((t) => t.debtId.equals(debtId))).get();
      expect(records.length, 1);
      expect(records.first.amount, 2500.0);
    });

    test('repaying full remaining amount automatically closes debt', () async {
      final debtId = await debtRepo.createDebt(
        debtType: 'i_borrowed',
        contactName: 'Amit',
        purpose: 'Cab share',
        principalAmount: 500.0,
      );

      // Pay full 500
      await debtRepo.recordRepayment(
        debtId: debtId,
        amount: 500.0,
      );

      final updatedDebt = await (db.select(db.debts)..where((t) => t.id.equals(debtId))).getSingle();
      expect(updatedDebt.remainingAmount, 0.0);
      expect(updatedDebt.status, 'closed');
    });
  });
}
