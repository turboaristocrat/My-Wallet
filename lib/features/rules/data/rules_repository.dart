import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class RuleMatchResult {
  final String? categoryId;
  final String? paymentType;
  final String? addTagId;
  final bool isBlocked;
  final String? matchedRuleName;

  RuleMatchResult({
    this.categoryId,
    this.paymentType,
    this.addTagId,
    this.isBlocked = false,
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
    required String triggerType, // 'merchant_contains', 'sms_body_contains', 'amount_greater_than', 'amount_less_than', 'account_matches', 'block_transaction'
    required String triggerValue,
    String? actionSetCategoryId,
    String? actionSetPaymentType,
    String? actionAddTagId,
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
            actionAddTagId: Value(actionAddTagId),
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

  /// Evaluate transaction details against active rules
  Future<RuleMatchResult?> evaluateRules({
    required String text,
    double? amount,
    String? accountMask,
    String? merchant,
  }) async {
    final activeRules = await (_db.select(_db.autoRules)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.priority, mode: OrderingMode.desc)]))
        .get();

    final normalizedText = text.toUpperCase();
    final normalizedMerchant = (merchant ?? '').toUpperCase();

    for (final rule in activeRules) {
      final val = rule.triggerValue.toUpperCase();

      switch (rule.triggerType) {
        case 'merchant_contains':
          if (normalizedMerchant.contains(val) || normalizedText.contains(val)) {
            return RuleMatchResult(
              categoryId: rule.actionSetCategoryId,
              paymentType: rule.actionSetPaymentType,
              addTagId: rule.actionAddTagId,
              isBlocked: false,
              matchedRuleName: rule.ruleName,
            );
          }
          break;

        case 'sms_body_contains':
          if (normalizedText.contains(val)) {
            return RuleMatchResult(
              categoryId: rule.actionSetCategoryId,
              paymentType: rule.actionSetPaymentType,
              addTagId: rule.actionAddTagId,
              isBlocked: false,
              matchedRuleName: rule.ruleName,
            );
          }
          break;

        case 'amount_greater_than':
          final threshold = double.tryParse(rule.triggerValue);
          if (threshold != null && amount != null && amount > threshold) {
            return RuleMatchResult(
              categoryId: rule.actionSetCategoryId,
              paymentType: rule.actionSetPaymentType,
              addTagId: rule.actionAddTagId,
              isBlocked: false,
              matchedRuleName: rule.ruleName,
            );
          }
          break;

        case 'amount_less_than':
          final threshold = double.tryParse(rule.triggerValue);
          if (threshold != null && amount != null && amount < threshold) {
            return RuleMatchResult(
              categoryId: rule.actionSetCategoryId,
              paymentType: rule.actionSetPaymentType,
              addTagId: rule.actionAddTagId,
              isBlocked: false,
              matchedRuleName: rule.ruleName,
            );
          }
          break;

        case 'account_matches':
          if (accountMask != null && accountMask.contains(val)) {
            return RuleMatchResult(
              categoryId: rule.actionSetCategoryId,
              paymentType: rule.actionSetPaymentType,
              addTagId: rule.actionAddTagId,
              isBlocked: false,
              matchedRuleName: rule.ruleName,
            );
          }
          break;

        case 'block_transaction':
          if (normalizedText.contains(val) || normalizedMerchant.contains(val)) {
            return RuleMatchResult(
              isBlocked: true,
              matchedRuleName: rule.ruleName,
            );
          }
          break;
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
