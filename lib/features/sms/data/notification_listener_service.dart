import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/parsing/regex_parser.dart';
import '../../../core/parsing/transaction_deduplication.dart';
import '../../inbox/data/queue_repository.dart';

class NotificationListenerService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.mywallet.my_wallet/notifications');
  static const EventChannel _eventChannel =
      EventChannel('com.mywallet.my_wallet/notification_events');

  final QueueRepository _queueRepo;
  final RegexParser _parser = RegexParser();
  final TransactionDeduplication _deduplication = TransactionDeduplication();

  StreamSubscription? _subscription;

  NotificationListenerService(this._queueRepo);

  /// Check if notification listener permission is granted by the user
  Future<bool> isPermissionGranted() async {
    try {
      final res =
          await _methodChannel.invokeMethod<bool>('isNotificationListenerEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launch Android Notification Access Settings screen
  Future<void> openSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  /// Start listening for bank & UPI notifications
  void startListening() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        if (event is Map) {
          final title = event['title']?.toString() ?? '';
          final body = event['body']?.toString() ?? '';
          final timestampMs = event['timestamp'] as int?;
          final timestamp = timestampMs != null
              ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
              : DateTime.now();

          await processIncomingNotification(
            sender: title.isNotEmpty ? title : 'UPI',
            body: body,
            timestamp: timestamp,
          );
        }
      },
      onError: (err) {
        // Channel stream error
      },
    );
  }

  /// Process incoming notification text through parser, deduplication, and queue
  Future<void> processIncomingNotification({
    required String sender,
    required String body,
    DateTime? timestamp,
  }) async {
    // 1. Parse with modular BankParser & VpaCleaner
    final parsed = _parser.parse(sender, body, timestamp);
    if (!parsed.isTransaction || parsed.amount == null) return;

    // 2. Deduplication check (SMS + Push collision prevention)
    if (_deduplication.isDuplicate(parsed)) {
      return; // Duplicate ignored
    }

    // 3. Add to Review Queue (subject to Smart Rules and BLOCK filters)
    await _queueRepo.addToQueue(
      sender: sender,
      rawBody: body,
      receivedAt: timestamp ?? DateTime.now(),
      suggestedMerchant: parsed.merchantName,
      suggestedAmount: parsed.amount,
      confidenceScore: parsed.confidence,
      parserUsed: 'push_notification',
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final notificationListenerServiceProvider =
    Provider<NotificationListenerService>((ref) {
  final queueRepo = ref.watch(queueRepositoryProvider);
  final service = NotificationListenerService(queueRepo);
  return service;
});
