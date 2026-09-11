import 'sms_parsing_result.dart';

/// Offline Regex Parser specifically tuned for Indian banking SMS formats.
/// Accurately parses HDFC, SBI, ICICI, Axis, Kotak, Paytm, GPay, PhonePe, and Cred SMS.
class RegexParser {
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one time password|verification code|secret code|do not share|valid for|is your code)\b',
    caseSensitive: false,
  );

  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );

  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|acct|account|card|ending|acc|\bac\b)\s*(?:no\.?|with)?\s*[*xX]*([0-9]{3,4})\b',
    caseSensitive: false,
  );

  static final RegExp _balancePattern = RegExp(
    r'(?:avl|avlbl|available|bal|balance)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _refPattern = RegExp(
    r'\b(?:ref|rrn|utr|txn id|ref no)\s*[:.]?\s*([a-zA-Z0-9]+)\b',
    caseSensitive: false,
  );

  static final RegExp _merchantPattern = RegExp(
    r'(?:to|at|info|vpa|paid to|transferred to)\s+([a-zA-Z0-9\s&._@-]+?)(?=\s+(?:on|ref|avl|bal|using|via|through|val|\.|$))',
    caseSensitive: false,
  );

  /// Parse an incoming SMS
  SmsParsingResult parse(String sender, String body, [DateTime? timestamp]) {
    final lowerBody = body.toLowerCase();

    // 1. Immediate rejection of OTP / security alerts
    if (_otpPattern.hasMatch(lowerBody) && !lowerBody.contains('debited') && !lowerBody.contains('credited')) {
      return SmsParsingResult.nonTransaction(body);
    }

    // 2. Identify Transaction Type
    String? type;
    if (lowerBody.contains('debited') ||
        lowerBody.contains('spent') ||
        lowerBody.contains('paid') ||
        lowerBody.contains('withdrawn') ||
        lowerBody.contains('purchase') ||
        lowerBody.contains('sent rs') ||
        lowerBody.contains('transferred to')) {
      type = 'expense';
    } else if (lowerBody.contains('credited') ||
        lowerBody.contains('received') ||
        lowerBody.contains('deposited') ||
        lowerBody.contains('salary') ||
        lowerBody.contains('refund')) {
      type = 'income';
    }

    if (type == null) {
      // Not a debit or credit transaction alert
      return SmsParsingResult.nonTransaction(body);
    }

    // 3. Extract Amount
    double? amount;
    final amountMatch = _amountPattern.firstMatch(body);
    if (amountMatch != null) {
      final rawAmountStr = (amountMatch.group(1) ?? amountMatch.group(2))
          ?.replaceAll(',', '');
      if (rawAmountStr != null) {
        amount = double.tryParse(rawAmountStr);
      }
    }

    if (amount == null || amount <= 0) {
      return SmsParsingResult.nonTransaction(body);
    }

    // 4. Extract Account Number (Mask)
    String? accountMask;
    final accMatch = _accountPattern.firstMatch(body);
    if (accMatch != null) {
      accountMask = accMatch.group(1);
    }

    // 5. Extract Bank Name from sender or body
    String? bankName = _detectBank(sender, body);

    // 6. Extract Available Balance
    double? balanceAfter;
    final balMatch = _balancePattern.firstMatch(body);
    if (balMatch != null) {
      final rawBalStr = balMatch.group(1)?.replaceAll(',', '');
      if (rawBalStr != null) {
        balanceAfter = double.tryParse(rawBalStr);
      }
    }

    // 7. Extract Reference Number
    String? refNumber;
    final refMatch = _refPattern.firstMatch(body);
    if (refMatch != null) {
      refNumber = refMatch.group(1);
    }

    // 8. Extract & Clean Merchant Name
    String? merchant;
    final merchMatch = _merchantPattern.firstMatch(body);
    if (merchMatch != null) {
      merchant = _cleanMerchant(merchMatch.group(1));
    }

    return SmsParsingResult(
      isTransaction: true,
      amount: amount,
      transactionType: type,
      merchantName: merchant,
      accountNumberMask: accountMask,
      bankName: bankName,
      balanceAfter: balanceAfter,
      referenceNumber: refNumber,
      dateTime: timestamp ?? DateTime.now(),
      confidence: 0.95,
      rawBody: body,
    );
  }

  static String? _detectBank(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();

    if (s.contains('HDFC') || b.contains('HDFC BANK')) return 'HDFC Bank';
    if (s.contains('SBI') || b.contains('STATE BANK')) return 'State Bank of India';
    if (s.contains('ICICI') || b.contains('ICICI BANK')) return 'ICICI Bank';
    if (s.contains('AXIS') || b.contains('AXIS BANK')) return 'Axis Bank';
    if (s.contains('KOTAK') || b.contains('KOTAK')) return 'Kotak Mahindra';
    if (s.contains('PAYTM') || b.contains('PAYTM')) return 'Paytm Payments Bank';
    if (s.contains('PNB') || b.contains('PUNJAB NATIONAL')) return 'Punjab National Bank';
    if (s.contains('BOB') || b.contains('BANK OF BARODA')) return 'Bank of Baroda';
    if (s.contains('CREDIN') || RegExp(r'\bCRED\b', caseSensitive: false).hasMatch(b)) return 'Cred';
    return null;
  }

  static String? _cleanMerchant(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();

    // Remove VPA handle (e.g. "swiggy@icici" -> "Swiggy")
    if (cleaned.contains('@')) {
      cleaned = cleaned.split('@').first;
    }

    // Capitalize first letter of words
    if (cleaned.length > 1) {
      cleaned = cleaned
          .split(' ')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '')
          .join(' ');
    }

    if (cleaned.isEmpty || cleaned.length > 50) return null;
    return cleaned;
  }
}
