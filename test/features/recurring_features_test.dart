import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/features/recurring/data/recurring_repository.dart';

void main() {
  late AppDatabase db;
  late RecurringRepository recurringRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    recurringRepo = RecurringRepository(db);

    // Create a dummy account
    await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            id: const Value('acc-1'),
            name: 'HDFC Salary Account',
            type: 'bank',
            balance: const Value(50000.0),
            updatedAt: Value(DateTime.now()),
          ),
        );

    // Create a dummy category
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: const Value('cat-sub'),
            name: 'Subscriptions & Utilities',
            iconName: 'tv',
            colorHex: const Value('#8B5CF6'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Recurring Repository Tests', () {
    test('calculates monthly commitments accurately across mixed frequencies', () {
      final now = DateTime.now();
      final templates = [
        RecurringTemplate(
          id: '1',
          title: 'Netflix',
          amount: 649.0,
          accountId: 'acc-1',
          categoryId: 'cat-sub',
          frequency: 'monthly',
          startDate: now,
          nextDueDate: now,
          autoLog: false,
          syncStatus: 'synced',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        RecurringTemplate(
          id: '2',
          title: 'Amazon Prime',
          amount: 1499.0,
          accountId: 'acc-1',
          categoryId: 'cat-sub',
          frequency: 'yearly',
          startDate: now,
          nextDueDate: now,
          autoLog: false,
          syncStatus: 'synced',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        RecurringTemplate(
          id: '3',
          title: 'Weekly Milk & Grocery',
          amount: 500.0,
          accountId: 'acc-1',
          categoryId: 'cat-sub',
          frequency: 'weekly',
          startDate: now,
          nextDueDate: now,
          autoLog: false,
          syncStatus: 'synced',
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
      ];

      final monthlyTotal = recurringRepo.calculateMonthlyCommitment(templates);
      // Expected: 649 + (1499 / 12) + (500 * 52 / 12)
      // 649 + 124.916 + 2166.666 = ~2940.58
      expect(monthlyTotal, closeTo(2940.58, 0.5));
    });

    test('creates template and streams details with accurate days until due', () async {
      final now = DateTime.now();
      final inFiveDays = now.add(const Duration(days: 5));

      final templateId = await recurringRepo.createRecurringTemplate(
        title: 'Spotify Family',
        amount: 179.0,
        accountId: 'acc-1',
        categoryId: 'cat-sub',
        frequency: 'monthly',
        startDate: now,
        nextDueDate: inFiveDays,
        autoLog: false,
      );

      expect(templateId, isNotEmpty);

      final templatesWithDetails =
          await recurringRepo.watchRecurringTemplates().first;
      expect(templatesWithDetails.length, 1);
      final item = templatesWithDetails.first;
      expect(item.template.title, 'Spotify Family');
      expect(item.template.amount, 179.0);
      expect(item.account?.name, 'HDFC Salary Account');
      expect(item.category?.name, 'Subscriptions & Utilities');
      expect(item.daysUntilDue, 5);
      expect(item.isOverdue, false);
      expect(item.isDueToday, false);
    });

    test('markAsPaid logs transaction, updates account balance, and advances nextDueDate', () async {
      final dueDate = DateTime(2026, 9, 15);
      final templateId = await recurringRepo.createRecurringTemplate(
        title: 'House Rent',
        amount: 25000.0,
        accountId: 'acc-1',
        categoryId: 'cat-sub',
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 1),
        nextDueDate: dueDate,
        autoLog: false,
      );

      // Check balance before
      var acc = await (db.select(db.accounts)..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(acc.balance, 50000.0);

      // Mark as paid
      await recurringRepo.markAsPaid(templateId, paidDate: DateTime(2026, 9, 15));

      // 1. Check account balance deducted
      acc = await (db.select(db.accounts)..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(acc.balance, 25000.0);

      // 2. Check ledger transaction was logged
      final txList = await (db.select(db.transactions)
            ..where((t) => t.merchantName.equals('House Rent')))
          .get();
      expect(txList.length, 1);
      expect(txList.first.amount, 25000.0);
      expect(txList.first.type, 'expense');

      // 3. Check nextDueDate was advanced by 1 month to October
      final updatedTemplate = await (db.select(db.recurringTemplates)
            ..where((t) => t.id.equals(templateId)))
          .getSingle();
      expect(updatedTemplate.nextDueDate.month, 10);
      expect(updatedTemplate.nextDueDate.day, 15);
    });

    test('skipCycle advances nextDueDate without logging an expense', () async {
      final dueDate = DateTime(2026, 9, 15);
      final templateId = await recurringRepo.createRecurringTemplate(
        title: 'Gym Membership',
        amount: 2000.0,
        accountId: 'acc-1',
        categoryId: 'cat-sub',
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 1),
        nextDueDate: dueDate,
      );

      await recurringRepo.skipCycle(templateId);

      // Verify balance unchanged
      final acc = await (db.select(db.accounts)..where((t) => t.id.equals('acc-1')))
          .getSingle();
      expect(acc.balance, 50000.0);

      // Verify no transactions created
      final txList = await db.select(db.transactions).get();
      expect(txList.isEmpty, true);

      // Verify date advanced
      final updatedTemplate = await (db.select(db.recurringTemplates)
            ..where((t) => t.id.equals(templateId)))
          .getSingle();
      expect(updatedTemplate.nextDueDate.month, 10);
    });
  });
}
