import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/parsing/regex_parser.dart';
import '../../../core/parsing/transaction_deduplication.dart';
import '../../inbox/data/queue_repository.dart';

class ScanReport {
  final int totalScanned;
  final int importedCount;
  final int skippedDuplicates;

  const ScanReport({
    required this.totalScanned,
    required this.importedCount,
    required this.skippedDuplicates,
  });
}

final smsScannerServiceProvider = Provider<SmsScannerService>((ref) {
  final queueRepo = ref.watch(queueRepositoryProvider);
  return SmsScannerService(
    parser: RegexParser(),
    deduplication: TransactionDeduplication(),
    queueRepo: queueRepo,
  );
});

class SmsScannerService {
  static const MethodChannel _channel = MethodChannel('com.mywallet.my_wallet/sms');

  final RegexParser parser;
  final TransactionDeduplication deduplication;
  final QueueRepository queueRepo;

  SmsScannerService({
    required this.parser,
    required this.deduplication,
    required this.queueRepo,
  });

  /// Check if READ_SMS permission is granted
  Future<bool> checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request READ_SMS runtime permission
  Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Scan device SMS inbox and stage financial transactions into review queue
  Future<ScanReport> scanInbox({
    int limit = 250,
    List<Account> activeAccounts = const [],
  }) async {
    final hasPerm = await checkPermission();
    if (!hasPerm) {
      final granted = await requestPermission();
      if (!granted) {
        return const ScanReport(totalScanned: 0, importedCount: 0, skippedDuplicates: 0);
      }
    }

    List<dynamic>? rawMessages;
    try {
      rawMessages = await _channel.invokeMethod<List<dynamic>>(
        'readSmsInbox',
        {'limit': limit},
      );
    } catch (_) {
      return const ScanReport(totalScanned: 0, importedCount: 0, skippedDuplicates: 0);
    }

    if (rawMessages == null || rawMessages.isEmpty) {
      return const ScanReport(totalScanned: 0, importedCount: 0, skippedDuplicates: 0);
    }

    int imported = 0;
    int duplicates = 0;

    for (final item in rawMessages) {
      if (item is! Map) continue;
      final address = (item['address'] as String?) ?? '';
      final body = (item['body'] as String?) ?? '';
      final epochMillis = (item['date'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(epochMillis);

      if (body.trim().isEmpty) continue;

      final parsed = parser.parse(address, body, timestamp);
      if (!parsed.isTransaction || parsed.amount == null) continue;

      // Check deduplication
      if (deduplication.isDuplicate(parsed)) {
        duplicates++;
        continue;
      }

      // Try matching account mask with user accounts
      String? matchedAccountId;
      if (parsed.accountNumberMask != null && activeAccounts.isNotEmpty) {
        final match = activeAccounts.cast<Account?>().firstWhere(
              (acc) =>
                  acc != null &&
                  acc.accountNumberMask != null &&
                  acc.accountNumberMask!.endsWith(parsed.accountNumberMask!),
              orElse: () => null,
            );
        matchedAccountId = match?.id;
      }
      matchedAccountId ??= activeAccounts.isNotEmpty ? activeAccounts.first.id : null;

      final queueId = await queueRepo.addToQueue(
        sender: address.isNotEmpty ? address : 'SMS',
        rawBody: body,
        receivedAt: timestamp,
        suggestedMerchant: parsed.merchantName,
        suggestedAmount: parsed.amount,
        suggestedAccountId: matchedAccountId,
        confidenceScore: parsed.confidence,
        parserUsed: parsed.bankName != null ? 'regex_${parsed.bankName}' : 'regex',
      );

      if (queueId.isNotEmpty) {
        imported++;
      }
    }

    return ScanReport(
      totalScanned: rawMessages.length,
      importedCount: imported,
      skippedDuplicates: duplicates,
    );
  }

  /// Inject demo banking SMS for instant end-to-end testing
  Future<int> injectDemoTransactions(List<Account> activeAccounts) async {
    final now = DateTime.now();
    final demoMessages = [
      (
        sender: 'AD-HDFCBK',
        body: 'Sent Rs.450.00 from HDFC Bank A/C *1234 to SWIGGY on ${now.day}-${now.month}-${now.year}. Ref 425123456789. Avl Bal Rs.48,200.50.',
        time: now.subtract(const Duration(minutes: 15)),
      ),
      (
        sender: 'VK-SBIINB',
        body: 'Dear SBI User, your A/C ending 5678 debited by Rs 1,450.00 on ${now.day}-${now.month}-${now.year} at FLIPKART Ref 99881122. Avail Bal Rs 24,000.00',
        time: now.subtract(const Duration(hours: 1)),
      ),
      (
        sender: 'BZ-ICICIB',
        body: 'ICICI Bank Acct XX3011 debited with INR 850.00 on ${now.day}-${now.month}-${now.year}. Info: UPI*UBER*12345. Available Balance is Rs 31,450.00',
        time: now.subtract(const Duration(hours: 3)),
      ),
      (
        sender: 'AD-KOTAKB',
        body: 'Rs. 220.00 debited from Kotak Bank A/c 6543 towards CHAI POINT on ${now.day}-${now.month}-${now.year}. Bal Rs. 8,230.00',
        time: now.subtract(const Duration(hours: 5)),
      ),
      (
        sender: 'VM-AXISBK',
        body: 'Spent INR 650.00 on Axis Bank Card ending 9876 at BLINKIT on ${now.day}-${now.month}-${now.year}. Bal INR 14,000',
        time: now.subtract(const Duration(hours: 8)),
      ),
    ];

    int count = 0;
    for (final demo in demoMessages) {
      final parsed = parser.parse(demo.sender, demo.body, demo.time);
      if (!parsed.isTransaction) continue;

      String? matchedAccountId;
      if (parsed.accountNumberMask != null && activeAccounts.isNotEmpty) {
        final match = activeAccounts.cast<Account?>().firstWhere(
              (acc) =>
                  acc != null &&
                  acc.accountNumberMask != null &&
                  acc.accountNumberMask!.endsWith(parsed.accountNumberMask!),
              orElse: () => null,
            );
        matchedAccountId = match?.id;
      }
      matchedAccountId ??= activeAccounts.isNotEmpty ? activeAccounts.first.id : null;

      final id = await queueRepo.addToQueue(
        sender: demo.sender,
        rawBody: demo.body,
        receivedAt: demo.time,
        suggestedMerchant: parsed.merchantName,
        suggestedAmount: parsed.amount,
        suggestedAccountId: matchedAccountId,
        confidenceScore: parsed.confidence,
        parserUsed: 'demo_${parsed.bankName}',
      );
      if (id.isNotEmpty) count++;
    }
    return count;
  }
}
