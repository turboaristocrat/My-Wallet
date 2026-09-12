import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../rules/data/rules_repository.dart';
import '../../transactions/data/transaction_repository.dart';

class QueueRepository {
  final AppDatabase _db;
  final TransactionRepository _txnRepo;
  final RulesRepository? _rulesRepo;

  QueueRepository(this._db, this._txnRepo, [this._rulesRepo]);

  /// Watch all unreviewed transactions in the staging queue
  Stream<List<SmsReviewQueueData>> watchPendingItems() {
    return (_db.select(_db.smsReviewQueue)
          ..where((tbl) => tbl.status.equals('pending') & tbl.isDeleted.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
                expression: tbl.receivedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  /// Add a newly captured SMS / notification to queue
  Future<String> addToQueue({
    required String sender,
    required String rawBody,
    required DateTime receivedAt,
    String? suggestedMerchant,
    double? suggestedAmount,
    String? suggestedAccountId,
    String? suggestedCategoryId,
    double? confidenceScore,
    String parserUsed = 'regex',
  }) async {
    String? finalCatId = suggestedCategoryId;
    if (finalCatId == null && _rulesRepo != null) {
      final match = await _rulesRepo.evaluateRules(
        text: suggestedMerchant ?? rawBody,
        amount: suggestedAmount,
      );
      if (match?.categoryId != null) {
        finalCatId = match!.categoryId;
      }
    }

    final id = const Uuid().v4();
    await _db.into(_db.smsReviewQueue).insert(
          SmsReviewQueueCompanion.insert(
            id: Value(id),
            sender: sender,
            rawBody: rawBody,
            receivedAt: receivedAt,
            suggestedMerchant: Value(suggestedMerchant),
            suggestedAmount: Value(suggestedAmount),
            suggestedAccountId: Value(suggestedAccountId),
            suggestedCategoryId: Value(finalCatId),
            confidenceScore: Value(confidenceScore),
            parserUsed: Value(parserUsed),
            status: const Value('pending'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return id;
  }

  /// Approve an item from the queue: converts it to an active transaction and marks queue item approved
  Future<void> approveItem({
    required String queueId,
    required String accountId,
    String? categoryId,
    String type = 'expense',
    required double amount,
    String? merchantName,
    DateTime? date,
    String? note,
  }) async {
    final item = await (_db.select(_db.smsReviewQueue)
          ..where((tbl) => tbl.id.equals(queueId)))
        .getSingleOrNull();
    if (item == null) return;

    // 1. Create real transaction
    await _txnRepo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      transactionDate: date ?? item.receivedAt,
      merchantName: merchantName ?? item.suggestedMerchant,
      note: note,
      rawSmsId: item.id,
      isAiParsed: item.parserUsed != 'regex',
      aiConfidence: item.confidenceScore,
    );

    // 2. Mark queue item approved
    await (_db.update(_db.smsReviewQueue)..where((tbl) => tbl.id.equals(queueId)))
        .write(SmsReviewQueueCompanion(
      status: const Value('approved'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Dismiss / ignore item from queue
  Future<void> dismissItem(String queueId) async {
    await (_db.update(_db.smsReviewQueue)..where((tbl) => tbl.id.equals(queueId)))
        .write(SmsReviewQueueCompanion(
      status: const Value('dismissed'),
      updatedAt: Value(DateTime.now()),
    ));
  }
}

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(
    ref.watch(databaseProvider),
    ref.watch(transactionRepositoryProvider),
    ref.watch(rulesRepositoryProvider),
  );
});

final pendingQueueStreamProvider =
    StreamProvider<List<SmsReviewQueueData>>((ref) {
  return ref.watch(queueRepositoryProvider).watchPendingItems();
});
