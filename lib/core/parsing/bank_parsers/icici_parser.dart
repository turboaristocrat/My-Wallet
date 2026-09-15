import '../dlt_bank_detector.dart';
import '../sms_parsing_result.dart';
import '../vpa_cleaner.dart';
import 'bank_parser.dart';

class IciciParser implements BankParser {
  @override
  String get bankName => 'ICICI Bank';

  @override
  bool canHandle(String sender, String body) {
    return DltBankDetector.detectBank(sender, body) == BankType.icici;
  }

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accPattern = RegExp(
    r'(?:acct|a/c|card|account|ac)\s*(?:no\.?|ending(?:\s*with)?|\s*is)?\s*[*xX.]*([0-9]{3,4})',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:available\s*balance|avail\s*bal|avl\s*bal|bal)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  @override
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    // 1. Type
    String? type;
    if (lower.contains('debited') ||
        lower.contains('used for') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('paid rs')) {
      type = 'expense';
    } else if (lower.contains('credited') ||
        lower.contains('received') ||
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

    // 3. Account
    String? accountMask;
    final accMatch = _accPattern.firstMatch(body);
    if (accMatch != null) {
      accountMask = accMatch.group(1);
    }

    // 4. Payment Type
    String paymentType = 'upi';
    if (lower.contains('credit card') || lower.contains('card xx') || lower.contains('pos')) {
      paymentType = 'card';
    } else if (lower.contains('atm') || lower.contains('withdrawn')) {
      paymentType = 'cash';
    } else if (lower.contains('upi')) {
      paymentType = 'upi';
    } else if (lower.contains('neft') || lower.contains('rtgs') || lower.contains('imps')) {
      paymentType = 'net_banking';
    }

    // 5. Merchant Extraction
    String? merchant;
    // Format: "Info: UPI*SWIGGY*12345" or "Info: UBER"
    final infoMatch = RegExp(r'Info:\s*(?:UPI\*)?([a-zA-Z0-9\s&._@-]+?)(?:\*|\.|$)', caseSensitive: false).firstMatch(body);
    if (infoMatch != null) {
      merchant = VpaCleaner.cleanMerchant(infoMatch.group(1)!);
    } else if (body.contains(' at ')) {
      final atIndex = body.indexOf(' at ');
      final onIndex = body.indexOf(' on ', atIndex + 4);
      final end = onIndex != -1 ? onIndex : body.length;
      final rawM = body.substring(atIndex + 4, end).trim();
      merchant = VpaCleaner.cleanMerchant(rawM);
    } else if (lower.contains('towards ')) {
      final match = RegExp(r'towards\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|avl|bal|\.|$))', caseSensitive: false).firstMatch(body);
      if (match != null) {
        merchant = VpaCleaner.cleanMerchant(match.group(1)!);
      }
    }

    merchant ??= type == 'expense' ? 'ICICI Payment' : 'ICICI Credit';

    // 6. Balance
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
      bankName: 'ICICI Bank',
      balanceAfter: balanceAfter,
      paymentType: paymentType,
      confidence: 0.95,
      dateTime: timestamp ?? DateTime.now(),
      rawBody: body,
    );
  }
}
