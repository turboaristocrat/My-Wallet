import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class RuleMatchResult {
  final String? categoryId;
  final String? paymentType;
  final String? matchedRuleName;

  RuleMatchResult({
    this.categoryId,
    this.paymentType,
    this.matchedRuleName,
  });
}

class RulesRepository {
  final AppDatabase _db;
  RulesRepository(this._db);

  /// Watch active rules ordered by priority descending
  Stream<List<AutoRule>> watchAllRules() {
    return (_db.select(_db.autoRules)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.priority, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Create a new automation rule
  Future<String> createRule({
    required String ruleName,
    required String triggerType, // 'merchant_contains', 'sms_body_contains'
    required String triggerValue,
    String? actionSetCategoryId,
    String? actionSetPaymentType,
    int priority = 0,
  }) async {
    final id = const Uuid().v4();
    await _db.into(_db.autoRules).insert(
          AutoRulesCompanion.insert(
            id: Value(id),
            ruleName: ruleName,
            triggerType: triggerType,
            triggerValue: triggerValue.trim().toUpperCase(),
            actionSetCategoryId: Value(actionSetCategoryId),
            actionSetPaymentType: Value(actionSetPaymentType),
            priority: Value(priority),
            isActive: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Toggle rule active status
  Future<void> toggleRule(String id, bool isActive) async {
    await (_db.update(_db.autoRules)..where((tbl) => tbl.id.equals(id))).write(
      AutoRulesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete rule (soft delete)
  Future<void> deleteRule(String id) async {
    await (_db.update(_db.autoRules)..where((tbl) => tbl.id.equals(id))).write(
      AutoRulesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Evaluate text against active rules
  Future<RuleMatchResult?> evaluateRules({
    required String text,
    double? amount,
  }) async {
    final activeRules = await (_db.select(_db.autoRules)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.priority, mode: OrderingMode.desc)]))
        .get();

    final normalized = text.toUpperCase();

    for (final rule in activeRules) {
      if (rule.triggerType == 'merchant_contains' || rule.triggerType == 'sms_body_contains') {
        if (normalized.contains(rule.triggerValue.toUpperCase())) {
          return RuleMatchResult(
            categoryId: rule.actionSetCategoryId,
            paymentType: rule.actionSetPaymentType,
            matchedRuleName: rule.ruleName,
          );
        }
      }
    }

    return null;
  }
}

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository(ref.watch(databaseProvider));
});

final allRulesStreamProvider = StreamProvider<List<AutoRule>>((ref) {
  return ref.watch(rulesRepositoryProvider).watchAllRules();
});
