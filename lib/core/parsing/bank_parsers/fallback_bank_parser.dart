import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class FallbackBankParser implements BankParser {
  @override
  String get bankName => 'Bank';

  @override
  bool canHandle(String sender, String body) => true;

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|acct|account|card|ending|acc|\bac\b)\s*(?:no\.?|with)?\s*[*xX.]*([0-9]{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avl|avlbl|available|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    String? type;
    if (lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('purchase') ||
        lower.contains('sent rs') ||
        lower.contains('transferred to')) {
      type = 'expense';
    } else if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('deposited') ||
        lower.contains('salary') ||
        lower.contains('refund')) {
      type = 'income';
    }

    if (type == null) return null;

    double? amount;
    final amtMatch = _amountPattern.firstMatch(body);
    if (amtMatch != null) {
      final raw = (amtMatch.group(1) ?? amtMatch.group(2))?.replaceAll(',', '');
      if (raw != null) amount = double.tryParse(raw);
    }
    if (amount == null || amount <= 0) return null;

    String? accountMask;
    final accMatch = _accPattern.firstMatch(body);
    if (accMatch != null) accountMask = accMatch.group(1);

    String paymentType = 'upi';
    if (lower.contains('card')) {
      paymentType = 'card';
    } else if (lower.contains('atm') || lower.contains('withdrawn')) {
      paymentType = 'cash';
    } else if (lower.contains('netbanking') || lower.contains('neft') || lower.contains('rtgs')) {
      paymentType = 'net_banking';
    }

    String? merchant;
    final merchantMatch = RegExp(
      r'(?:to|at|info|vpa|paid to|transferred to)\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|ref|avl|bal|using|via|\.|$))',
      caseSensitive: false,
    ).firstMatch(body);
    if (merchantMatch != null) {
      merchant = VpaCleaner.cleanMerchant(merchantMatch.group(1)!);
    }

    merchant ??= type == 'expense' ? 'Bank Payment' : 'Bank Credit';

    double? balanceAfter;
    final balMatch = _balancePattern.firstMatch(body);
    if (balMatch != null) {
      final rawBal = balMatch.group(1)?.replaceAll(',', '');
      if (rawBal != null) balanceAfter = double.tryParse(rawBal);
    }

    return SmsParsingResult(
      isTransaction: true,
      amount: amount,
      transactionType: type,
      merchantName: merchant,
      accountNumberMask: accountMask,
      bankName: DltBankDetector.detectBankName(sender, body) ?? 'Bank',
      balanceAfter: balanceAfter,
      paymentType: paymentType,
      confidence: 0.85,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
