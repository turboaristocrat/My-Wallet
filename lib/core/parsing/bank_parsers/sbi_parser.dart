import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class SbiParser implements BankParser {
  @override
  String get bankName => 'State Bank of India';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.sbi;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|card|acct)\s*(?:ending\s*(?:with)?)?\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avail\s*bal|total\s*bal|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _refPattern = RegExp(
    r'(?:ref|rrn|upi|utr|ref no)\s*[:.]?\s*([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    // 1. Transaction Type
    String? type;
    if (lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('transfer to') ||
        lower.contains('paid rs')) {
      type = 'expense';
    } else if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('deposited') ||
        lower.contains('refund')) {
      type = 'income';
    }

    if (type == null) return null;

    // 2. Amount
    double? amount;
    final amtMatch = _amountPattern.firstMatch(body);
    if (amtMatch != null) {
      final raw = (amtMatch.group(1) ?? amtMatch.group(2))?.replaceAll(',', '');
      if (raw != null) amount = double.tryParse(raw);
    }
    if (amount == null || amount <= 0) return null;

    // 3. Account Mask
    String? accountMask;
    final accMatch = _accPattern.firstMatch(body);
    if (accMatch != null) {
      accountMask = accMatch.group(1);
    }

    // 4. Payment Type
    String paymentType = 'upi';
    if (lower.contains('credit card') || lower.contains('sbi card')) {
      paymentType = 'card';
    } else if (lower.contains('atm') || lower.contains('withdrawn')) {
      paymentType = 'cash';
    } else if (lower.contains('upi') || lower.contains('vpa')) {
      paymentType = 'upi';
    } else if (lower.contains('inb') || lower.contains('neft') || lower.contains('rtgs')) {
      paymentType = 'net_banking';
    }

    // 5. Merchant
    String? merchant;
    if (body.contains(' at ') && (lower.contains('card') || lower.contains('spent'))) {
      final atIndex = body.indexOf(' at ');
      final onIndex = body.indexOf(' on ', atIndex + 4);
      if (atIndex != -1) {
        final end = onIndex != -1 ? onIndex : body.length;
        final rawM = body.substring(atIndex + 4, end).trim();
        merchant = VpaCleaner.cleanMerchant(rawM);
      }
    } else if (lower.contains('transfer to ') || lower.contains('to vpa ') || lower.contains('to ')) {
      final match = RegExp(
        r'(?:transfer to|to vpa|to)\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:ref|avail|bal|on|\.|$))',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) {
        merchant = VpaCleaner.cleanMerchant(match.group(1)!);
      }
    } else if (lower.contains('transfer from ') || lower.contains('by transfer from ')) {
      final match = RegExp(
        r'(?:transfer from|by transfer from)\s+([a-zA-Z0-9\s&._-]+?)(?=\s+(?:ref|total|bal|\.|$))',
        caseSensitive: false,
      ).firstMatch(body);
      if (match != null) {
        merchant = VpaCleaner.cleanMerchant(match.group(1)!);
      }
    }

    merchant ??= type == 'expense' ? 'SBI Transfer' : 'SBI Deposit';

    // 6. Balance
    double? balanceAfter;
    final balMatch = _balancePattern.firstMatch(body);
    if (balMatch != null) {
      final rawBal = balMatch.group(1)?.replaceAll(',', '');
      if (rawBal != null) balanceAfter = double.tryParse(rawBal);
    }

    // 7. Ref
    String? refNo;
    final refMatch = _refPattern.firstMatch(body);
    if (refMatch != null) {
      refNo = refMatch.group(1);
    }

    return SmsParsingResult(
      isTransaction: true,
      amount: amount,
      transactionType: type,
      merchantName: merchant,
      accountNumberMask: accountMask,
      bankName: 'State Bank of India',
      balanceAfter: balanceAfter,
      referenceNumber: refNo,
      paymentType: paymentType,
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
