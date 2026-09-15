import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class UpiFintechParser implements BankParser {
  @override
  String get bankName => 'UPI / Fintech';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.upiFintech;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|card|ending(?:\s*in)?)\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _txnIdPattern = RegExp(
    r'(?:txn\s*id|transaction\s*id|order\s*id|ref)\s*[:.]?\s*([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    String? type;
    if (lower.contains('paid') ||
        lower.contains('sent') ||
        lower.contains('debited') ||
        lower.contains('transfer to')) {
      type = 'expense';
    } else if (lower.contains('received') ||
        lower.contains('cashback') ||
        lower.contains('credited') ||
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

    String? merchant;
    if ((lower.contains('paid') || lower.contains('sent')) && lower.contains('to ')) {
      final match = RegExp(
        r'(?:paid|sent).*?\bto\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|using|via|for|ref|txn|updated|\.|$))',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) {
        merchant = VpaCleaner.cleanMerchant(match.group(1)!);
      }
    } else if (lower.contains('for ')) {
      final match = RegExp(
        r'for\s+([a-zA-Z0-9\s&._-]+?)(?=\s+(?:ending|ref|txn|\.|$))',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) {
        merchant = VpaCleaner.cleanMerchant(match.group(1)!);
      }
    }

    merchant ??= type == 'expense' ? 'UPI Payment' : 'UPI Receipt';

    String? refNo;
    final refMatch = _txnIdPattern.firstMatch(body);
    if (refMatch != null) refNo = refMatch.group(1);

    final detectedBank = DltBankDetector.detectBankName(sender, body);

    return SmsParsingResult(
      isTransaction: true,
      amount: amount,
      transactionType: type,
      merchantName: merchant,
      accountNumberMask: accountMask,
      bankName: detectedBank ?? 'UPI',
      referenceNumber: refNo,
      paymentType: 'upi',
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
