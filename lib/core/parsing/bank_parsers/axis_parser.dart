import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class AxisParser implements BankParser {
  @override
  String get bankName => 'Axis Bank';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.axis;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|card|account)\s*(?:no\.?)?\s*(?:ending)?\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avail(?:able)?\s*bal|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    String? type;
    if (lower.contains('debited') || lower.contains('spent') || lower.contains('paid')) {
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
    } else if (lower.contains('netbanking') || lower.contains('neft')) {
      paymentType = 'net_banking';
    }

    String? merchant;
    if (body.contains(' at ')) {
      final atIndex = body.indexOf(' at ');
      final onIndex = body.indexOf(' on ', atIndex + 4);
      final end = onIndex != -1 ? onIndex : body.length;
      merchant = VpaCleaner.cleanMerchant(body.substring(atIndex + 4, end).trim());
    } else if (lower.contains('to ')) {
      final toMatch = RegExp(r'to\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|avail|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (toMatch != null) merchant = VpaCleaner.cleanMerchant(toMatch.group(1)!);
    }
    merchant ??= type == 'expense' ? 'Axis Payment' : 'Axis Credit';

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
      bankName: 'Axis Bank',
      balanceAfter: balanceAfter,
      paymentType: paymentType,
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
