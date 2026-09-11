import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

// --- Shared Base Columns for Cloud-Sync Architecture ---
mixin SyncAuditTable on Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  // syncStatus: 'synced', 'pending_upload', 'conflict'
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending_upload'))();

  @override
  Set<Column> get primaryKey => {id};
}

// 1. Accounts Table
class Accounts extends Table with SyncAuditTable {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  // type: 'savings', 'current', 'credit_card', 'cash', 'wallet'
  TextColumn get type => text()();
  TextColumn get accountNumberMask => text().nullable()(); // e.g. "1234"
  TextColumn get colorHex => text().withDefault(const Constant('0xFF008080'))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  RealColumn get creditLimit => real().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

// 2. Categories Table
class Categories extends Table with SyncAuditTable {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get iconName => text()(); // material icon identifier or name
  TextColumn get colorHex => text().withDefault(const Constant('0xFF008080'))();
  TextColumn get parentId => text().nullable()(); // for subcategories
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

// 3. Tags (Labels) Table
class Tags extends Table with SyncAuditTable {
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().withDefault(const Constant('0xFF26B2AB'))();
}

// 4. Transactions Table
class Transactions extends Table with SyncAuditTable {
  @ReferenceName('accountTransactions')
  TextColumn get accountId => text().references(Accounts, #id)();
  @ReferenceName('targetTransfers')
  TextColumn get toAccountId =>
      text().nullable().references(Accounts, #id)(); // for transfers
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  // type: 'expense', 'income', 'transfer'
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get merchantName => text().nullable()();
  TextColumn get note => text().nullable()();
  // paymentType: 'upi', 'card', 'cash', 'net_banking'
  TextColumn get paymentType =>
      text().withDefault(const Constant('upi'))();
  TextColumn get locationAddress => text().nullable()();
  RealColumn get locationLat => real().nullable()();
  RealColumn get locationLng => real().nullable()();
  // status: 'cleared', 'pending', 'reconciled'
  TextColumn get status => text().withDefault(const Constant('cleared'))();
  TextColumn get rawSmsId => text().nullable()();
  BoolColumn get isAiParsed => boolean().withDefault(const Constant(false))();
  RealColumn get aiConfidence => real().nullable()();
}

// 5. TransactionTags (Many-to-Many join)
class TransactionTags extends Table {
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

// 6. ReceiptAttachments Table
class ReceiptAttachments extends Table with SyncAuditTable {
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get filePath => text()();
  TextColumn get parsedItemsJson => text().nullable()(); // itemized line items
}

// 7. SmsReviewQueue Table (Auto-Capture Staging Area)
class SmsReviewQueue extends Table with SyncAuditTable {
  TextColumn get sender => text()(); // e.g. "HDFC-BK", "VK-SBIINB"
  TextColumn get rawBody => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get suggestedMerchant => text().nullable()();
  RealColumn get suggestedAmount => real().nullable()();
  TextColumn get suggestedAccountId => text().nullable()();
  TextColumn get suggestedCategoryId => text().nullable()();
  RealColumn get confidenceScore => real().nullable()();
  // parserUsed: 'regex', 'gemini', 'on_device'
  TextColumn get parserUsed => text().withDefault(const Constant('regex'))();
  // status: 'pending', 'approved', 'dismissed'
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

// 8. AutoRules Table (If-This-Then-That Automation)
class AutoRules extends Table with SyncAuditTable {
  TextColumn get ruleName => text()();
  // triggerType: 'merchant_contains', 'sms_body_contains', 'amount_between'
  TextColumn get triggerType => text()();
  TextColumn get triggerValue => text()();
  TextColumn get actionSetCategoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get actionAddTagId => text().nullable().references(Tags, #id)();
  TextColumn get actionSetPaymentType => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// 9. RecurringTemplates Table (Planned Payments)
class RecurringTemplates extends Table with SyncAuditTable {
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  // frequency: 'daily', 'weekly', 'monthly', 'yearly'
  TextColumn get frequency => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get autoLog => boolean().withDefault(const Constant(false))();
}

// 10. Budgets Table
class Budgets extends Table with SyncAuditTable {
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // null = overall budget
  RealColumn get amount => real()();
  // period: 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  IntColumn get notifyAtPercent => integer().withDefault(const Constant(80))();
}

// 11. Debts Table (Formal Loans & People Debts)
class Debts extends Table with SyncAuditTable {
  // debtType: 'formal_loan', 'i_lent', 'i_borrowed'
  TextColumn get debtType => text()();
  TextColumn get contactName => text()(); // Person name or Bank name
  TextColumn get purpose => text()(); // e.g. "Car Loan", "Fridge", "Trip"
  RealColumn get principalAmount => real()();
  RealColumn get remainingAmount => real()();
  RealColumn get interestRate => real().nullable()(); // for loans (e.g. 8.5)
  RealColumn get emiAmount => real().nullable()();
  DateTimeColumn get nextEmiDate => dateTime().nullable()();
  // status: 'active', 'closed'
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get linkedAccountId =>
      text().nullable().references(Accounts, #id)();
}

// 12. DebtRecords Table (Partial Repayments)
class DebtRecords extends Table with SyncAuditTable {
  TextColumn get debtId => text().references(Debts, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paidDate => dateTime()();
  TextColumn get accountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get note => text().nullable()();
}

// 13. Goals Table (Savings Targets)
class Goals extends Table with SyncAuditTable {
  TextColumn get title => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime()();
  BoolColumn get isLinkedAccount =>
      boolean().withDefault(const Constant(false))();
  TextColumn get linkedAccountId =>
      text().nullable().references(Accounts, #id)();
  RealColumn get monthlyAutoSaveAmount => real().nullable()();
  // status: 'in_progress', 'achieved'
  TextColumn get status =>
      text().withDefault(const Constant('in_progress'))();
}

// 14. DashboardWidgets Table (Customization Engine)
class DashboardWidgets extends Table with SyncAuditTable {
  TextColumn get widgetType => text()(); // e.g. 'cash_flow', 'balance_gauge'
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  TextColumn get settingsJson => text().nullable()();
}

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Tags,
  Transactions,
  TransactionTags,
  ReceiptAttachments,
  SmsReviewQueue,
  AutoRules,
  RecurringTemplates,
  Budgets,
  Debts,
  DebtRecords,
  Goals,
  DashboardWidgets,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(name: 'my_wallet_db'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Seed default categories
          await _seedDefaultCategories();
          await _seedDefaultWidgets();
        },
      );

  Future<void> _seedDefaultCategories() async {
    final defaultCategories = [
      CategoriesCompanion.insert(
        name: 'Food & Dining',
        iconName: 'restaurant',
        colorHex: const Value('0xFFF59E0B'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Groceries',
        iconName: 'shopping_basket',
        colorHex: const Value('0xFF10B981'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Transport & Fuel',
        iconName: 'directions_car',
        colorHex: const Value('0xFF3B82F6'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Shopping',
        iconName: 'shopping_bag',
        colorHex: const Value('0xFFEC4899'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Bills & Utilities',
        iconName: 'receipt_long',
        colorHex: const Value('0xFF8B5CF6'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Entertainment',
        iconName: 'movie',
        colorHex: const Value('0xFF6366F1'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Salary & Income',
        iconName: 'account_balance_wallet',
        colorHex: const Value('0xFF059669'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Healthcare',
        iconName: 'local_hospital',
        colorHex: const Value('0xFFEF4444'),
        isDefault: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Investments',
        iconName: 'trending_up',
        colorHex: const Value('0xFF008080'),
        isDefault: const Value(true),
      ),
    ];

    for (final cat in defaultCategories) {
      await into(categories).insert(cat);
    }
  }

  Future<void> _seedDefaultWidgets() async {
    final defaultWidgets = [
      DashboardWidgetsCompanion.insert(
        widgetType: 'cash_flow',
        displayOrder: const Value(0),
        isVisible: const Value(true),
      ),
      DashboardWidgetsCompanion.insert(
        widgetType: 'balance_gauge',
        displayOrder: const Value(1),
        isVisible: const Value(true),
      ),
      DashboardWidgetsCompanion.insert(
        widgetType: 'spending_donut',
        displayOrder: const Value(2),
        isVisible: const Value(true),
      ),
      DashboardWidgetsCompanion.insert(
        widgetType: 'budget_status',
        displayOrder: const Value(3),
        isVisible: const Value(true),
      ),
      DashboardWidgetsCompanion.insert(
        widgetType: 'recent_transactions',
        displayOrder: const Value(4),
        isVisible: const Value(true),
      ),
    ];

    for (final w in defaultWidgets) {
      await into(dashboardWidgets).insert(w);
    }
  }
}
