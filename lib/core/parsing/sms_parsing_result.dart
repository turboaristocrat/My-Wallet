/// Model representing parsed information from an Indian banking SMS or push notification
class SmsParsingResult {
  final bool isTransaction;
  final double? amount;
  // 'expense', 'income', 'transfer'
  final String? transactionType;
  final String? merchantName;
  final String? accountNumberMask;
  final String? bankName;
  final double? balanceAfter;
  final String? referenceNumber;
  final DateTime? dateTime;
  final double confidence; // 0.0 to 1.0
  final String? rawBody;

  const SmsParsingResult({
    required this.isTransaction,
    this.amount,
    this.transactionType,
    this.merchantName,
    this.accountNumberMask,
    this.bankName,
    this.balanceAfter,
    this.referenceNumber,
    this.dateTime,
    this.confidence = 0.0,
    this.rawBody,
  });

  /// Factory for non-financial messages (OTP, spam, promos)
  factory SmsParsingResult.nonTransaction(String rawBody) {
    return SmsParsingResult(
      isTransaction: false,
      confidence: 1.0,
      rawBody: rawBody,
    );
  }

  @override
  String toString() {
    return 'SmsParsingResult(isTxn: $isTransaction, type: $transactionType, amount: $amount, merchant: $merchantName, acc: $accountNumberMask, bank: $bankName, conf: $confidence)';
  }
}
