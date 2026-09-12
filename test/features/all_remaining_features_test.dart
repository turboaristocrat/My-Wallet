import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/accounts/data/account_repository.dart';
import 'package:my_wallet/features/budgets/data/budget_repository.dart';
import 'package:my_wallet/features/copilot/data/copilot_service.dart';
import 'package:my_wallet/features/debts/data/debt_repository.dart';
import 'package:my_wallet/features/receipts/data/receipt_scanner_service.dart';
import 'package:my_wallet/features/recurring/data/recurring_repository.dart';
import 'package:my_wallet/features/transactions/data/transaction_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late AccountRepository accountRepo;
  late BudgetRepository budgetRepo;
  late RecurringRepository recurringRepo;
  late DebtRepository debtRepo;
  late TransactionRepository txnRepo;
  late ReceiptScannerService receiptScanner;
  late CopilotService copilotService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    budgetRepo = BudgetRepository(db);
    recurringRepo = RecurringRepository(db);
    debtRepo = DebtRepository(db);
    txnRepo = TransactionRepository(db);
    receiptScanner = ReceiptScannerService(db);
    copilotService = CopilotService(db, accountRepo, budgetRepo, recurringRepo, debtRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Receipt Scanner & Heuristic OCR Tests', () {
    test('parses receipt text and extracts amount, merchant, and category', () {
      const sampleOcr = '''
        STARBUCKS COFFEE #104
        Date: 12/09/2026
        Subtotal: 390.00
        Tax: 19.50
        TOTAL: ₹409.50
        Thank you for visiting!
      ''';

      final result = receiptScanner.parseReceiptText(sampleOcr);
      expect(result.totalAmount, equals(409.50));
      expect(result.merchantName.toLowerCase(), contains('starbucks'));
      expect(result.suggestedCategory, equals('Food & Dining'));
    });

    test('parses grocery receipt and identifies groceries category', () {
      const groceryOcr = '''
        D-MART SUPERMARKET
        Items:
        Milk, Bread, Eggs
        Total: 580.00
        PAID VIA UPI
      ''';

      final result = receiptScanner.parseReceiptText(groceryOcr);
      expect(result.totalAmount, equals(580.00));
      expect(result.merchantName.toLowerCase(), contains('d-mart'));
      expect(result.suggestedCategory, equals('Groceries'));
    });
  });

  group('AI Financial Copilot Tests', () {
    test('computes financial snapshot accurately from database', () async {
      // 1. Create account with initial balance
      final accId = await accountRepo.createAccount(
        name: 'HDFC Savings',
        type: 'bank',
        initialBalance: 50000.0,
      );

      // 2. Add an expense and income transaction
      final catId = (await db.select(db.categories).get()).first.id;
      final now = DateTime.now();

      await txnRepo.createTransaction(
        accountId: accId,
        categoryId: catId,
        amount: 3000.0,
        type: 'expense',
        merchantName: 'Weekly Groceries',
        transactionDate: now,
      );

      await txnRepo.createTransaction(
        accountId: accId,
        categoryId: catId,
        amount: 25000.0,
        type: 'income',
        merchantName: 'Freelance Project',
        transactionDate: now,
      );

      final snapshot = await copilotService.getSnapshot();

      // Net worth = 50000 - 3000 + 25000 = 72000
      expect(snapshot.netWorth, equals(72000.0));
      expect(snapshot.monthlyIncome, equals(25000.0));
      expect(snapshot.monthlyExpense, equals(3000.0));
      expect(snapshot.netSavings, equals(22000.0));
      expect(snapshot.savingsRate, greaterThan(80.0));
    });

    test('answers affordability questions with intelligent risk classification', () async {
      await accountRepo.createAccount(
        name: 'Main Bank',
        type: 'bank',
        initialBalance: 10000.0,
      );

      // Query 1: Expense way beyond balance
      final answerExcessive = await copilotService.answerQuery('Can I afford ₹50,000 for a gaming PC?');
      expect(answerExcessive, contains('Not Recommended right now'));

      // Query 2: Small expense well within cash flow
      final answerSafe = await copilotService.answerQuery('Can I afford ₹1,000 for dinner?');
      expect(answerSafe, contains('Affordable'));
    });

    test('answers queries for upcoming bills and debts', () async {
      final accId = await accountRepo.createAccount(
        name: 'Checking',
        type: 'bank',
        initialBalance: 20000.0,
      );
      final catId = (await db.select(db.categories).get()).first.id;

      // Add a recurring bill
      await recurringRepo.createRecurringTemplate(
        accountId: accId,
        categoryId: catId,
        title: 'Netflix Subscription',
        amount: 649.0,
        frequency: 'monthly',
        startDate: DateTime.now(),
        nextDueDate: DateTime.now().add(const Duration(days: 3)),
      );

      // Add a debt (someone owes user)
      await debtRepo.createDebt(
        debtType: 'i_lent',
        contactName: 'Rohan',
        purpose: 'Concert ticket',
        principalAmount: 2500.0,
      );

      final billAnswer = await copilotService.answerQuery('What bills are due soon?');
      expect(billAnswer, contains('Netflix Subscription'));
      expect(billAnswer, contains('649'));

      final debtAnswer = await copilotService.answerQuery('Who owes me money?');
      expect(debtAnswer, contains('2,500'));
      expect(debtAnswer, contains('Money Lent'));
    });
  });

  group('Split Expenses & Sync to Debts Tests', () {
    test('calculates equal split shares and syncs to debts tracker', () async {
      const totalAmount = 2400.0;
      final participants = ['You', 'Aarav', 'Neha', 'Vikram'];
      final equalShare = totalAmount / participants.length;

      expect(equalShare, equals(600.0));

      // Simulate syncing "You Paid" to debts
      for (int i = 1; i < participants.length; i++) {
        await debtRepo.createDebt(
          debtType: 'i_lent',
          contactName: participants[i],
          purpose: 'Split: Team Lunch',
          principalAmount: equalShare,
        );
      }

      final debts = await debtRepo.watchDebts().first;
      expect(debts.length, equals(3));
      for (final d in debts) {
        expect(d.debt.remainingAmount, equals(600.0));
        expect(d.debt.debtType, equals('i_lent'));
        expect(d.debt.purpose, equals('Split: Team Lunch'));
      }

      final summary = debtRepo.calculateNetDebtSummary(debts.map((e) => e.debt).toList());
      expect(summary.totalLent, equals(1800.0));
      expect(summary.netPosition, equals(1800.0));
    });
  });
}
