import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class KotakParser implements BankParser {
  @override
  String get bankName => 'Kotak Mahindra';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.kotak;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|card|account|ac)\s*(?:no\.?)?\s*(?:ending(?:\s*with)?)?\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avl\s*bal|available\s*bal|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    String? type;
    if (lower.contains('debited') || lower.contains('sent rs') || lower.contains('paid')) {
      type = 'expense';
    } else if (lower.contains('credited') || lower.contains('received') || lower.contains('refund')) {
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
    } else if (lower.contains('upi')) {
      paymentType = 'upi';
    } else if (lower.contains('netbanking')) {
      paymentType = 'net_banking';
    }

    String? merchant;
    if (lower.contains('towards ')) {
      final toMatch = RegExp(r'towards\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|avl|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (toMatch != null) merchant = VpaCleaner.cleanMerchant(toMatch.group(1)!);
    } else if (lower.contains('to ')) {
      final toMatch = RegExp(r'to\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:via|on|avl|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (toMatch != null) merchant = VpaCleaner.cleanMerchant(toMatch.group(1)!);
    }
    merchant ??= type == 'expense' ? 'Kotak Payment' : 'Kotak Deposit';

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
      bankName: bankName,
      balanceAfter: balanceAfter,
      paymentType: paymentType,
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
