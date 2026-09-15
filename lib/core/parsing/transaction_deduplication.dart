import 'sms_parsing_result.dart';

/// Prevents duplicate transactions when both SMS and Push Notification arrive for the same purchase,
/// or when banks send dual authorization/settlement SMS.
class TransactionDeduplication {
  static final TransactionDeduplication _instance =
      TransactionDeduplication._internal();
  factory TransactionDeduplication() => _instance;
  TransactionDeduplication._internal();

  // Stores hash -> insertion time
  final Map<String, DateTime> _recentSignatures = {};

  // Maximum age to keep signatures in memory (e.g. 1 hour)
  static const Duration _windowDuration = Duration(hours: 1);

  /// Generate deterministic composite signature for a parsed transaction
  static String generateSignature({
    required double amount,
    String? accountMask,
    String? merchant,
    DateTime? timestamp,
  }) {
    final time = timestamp ?? DateTime.now();
    // Quantize time to 15-minute bucket to absorb slight delivery delays between SMS and push notification
    final bucketMin = (time.minute / 15).floor() * 15;
    final timeBucket =
        '${time.year}-${time.month}-${time.day}_${time.hour}:$bucketMin';

    final cleanMerchant = (merchant ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    return '${amount.toStringAsFixed(2)}_${cleanMerchant}_$timeBucket';
  }

  /// Checks if a transaction is a duplicate.
  /// If NOT a duplicate, records it in the history and returns `false`.
  /// If IT IS a duplicate, returns `true`.
  bool isDuplicate(SmsParsingResult parsed) {
    if (!parsed.isTransaction || parsed.amount == null) return false;

    _purgeOldSignatures();

    final sig = generateSignature(
      amount: parsed.amount!,
      accountMask: parsed.accountNumberMask,
      merchant: parsed.merchantName,
      timestamp: parsed.dateTime,
    );

    if (_recentSignatures.containsKey(sig)) {
      return true; // Already processed
    }

    _recentSignatures[sig] = DateTime.now();
    return false;
  }

  void _purgeOldSignatures() {
    final now = DateTime.now();
    _recentSignatures.removeWhere(
      (sig, time) => now.difference(time) > _windowDuration,
    );
  }

  /// Clear in-memory history (useful for tests)
  void clear() {
    _recentSignatures.clear();
  }
}
