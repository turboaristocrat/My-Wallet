import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class HdfcParser implements BankParser {
  @override
  String get bankName => 'HDFC Bank';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.hdfc;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:a/c|card|acct|ac)\s*(?:no\.?|ending(?:\s*with)?|\s*is)?\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avl\s*bal|available\s*bal|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _refPattern = RegExp(
    r'(?:ref|rrn|upi|utr|txn id)\s*[:.]?\s*([a-zA-Z0-9]+)',
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
        lower.contains('sent rs') ||
        lower.contains('transferred to') ||
        lower.contains('paid rs') ||
        lower.contains('txn rs')) {
      type = 'expense';
    } else if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('salary') ||
        lower.contains('reversed') ||
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
    if (lower.contains('card') || lower.contains('pos') || lower.contains('spent on')) {
      paymentType = 'card';
    } else if (lower.contains('withdrawn') || lower.contains('atm')) {
      paymentType = 'cash';
    } else if (lower.contains('netbanking') || lower.contains('neft') || lower.contains('rtgs') || lower.contains('imps')) {
      paymentType = 'net_banking';
    } else if (lower.contains('upi') || lower.contains('vpa')) {
      paymentType = 'upi';
    }

    // 5. Merchant Extraction
    String? merchant;
    if (lower.contains('withdrawn') && lower.contains('atm')) {
      final atMatch = RegExp(r'At\s+ATM\s+([^On\n.]+)', caseSensitive: false).firstMatch(body);
      if (atMatch != null) {
        merchant = 'ATM at ${atMatch.group(1)!.trim()}';
      } else {
        merchant = 'ATM Cash Withdrawal';
      }
    } else if (body.contains(' reversed to ') || body.contains('By ')) {
      final revMatch = RegExp(r'By\s+([^On\n.]+)', caseSensitive: false).firstMatch(body);
      if (revMatch != null) {
        merchant = VpaCleaner.cleanMerchant(revMatch.group(1)!);
      }
    } else if (RegExp(r'\bat\s+', caseSensitive: false).hasMatch(body)) {
      final atMatch = RegExp(r'\bat\s+([a-zA-Z0-9\s&._-]+?)(?=\s+(?:on|ref|avl|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (atMatch != null) {
        merchant = VpaCleaner.cleanMerchant(atMatch.group(1)!);
      }
    } else if (lower.contains('to vpa ') || lower.contains('to ')) {
      final toMatch = RegExp(r'(?:to\s+vpa|towards|to)\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|ref|avl|bal|using|via|\.|$))', caseSensitive: false).firstMatch(body);
      if (toMatch != null) {
        merchant = VpaCleaner.cleanMerchant(toMatch.group(1)!);
      }
    } else if (lower.contains('by salary') || lower.contains('by ')) {
      final byMatch = RegExp(r'by\s+([a-zA-Z0-9\s&._-]+?)(?=\s+(?:on|ref|avl|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (byMatch != null) {
        merchant = VpaCleaner.cleanMerchant(byMatch.group(1)!);
      }
    }

    merchant ??= type == 'expense' ? 'HDFC Payment' : 'HDFC Deposit';

    // 6. Available Balance
    double? balanceAfter;
    final balMatch = _balancePattern.firstMatch(body);
    if (balMatch != null) {
      final rawBal = balMatch.group(1)?.replaceAll(',', '');
      if (rawBal != null) balanceAfter = double.tryParse(rawBal);
    }

    // 7. Reference Number
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
      bankName: 'HDFC Bank',
      balanceAfter: balanceAfter,
      referenceNumber: refNo,
      paymentType: paymentType,
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
