import 'bank_parsers/axis_parser.dart';
import 'bank_parsers/bank_parser.dart';
import 'bank_parsers/fallback_bank_parser.dart';
import 'bank_parsers/hdfc_parser.dart';
import 'bank_parsers/icici_parser.dart';
import 'bank_parsers/kotak_parser.dart';
import 'bank_parsers/sbi_parser.dart';
import 'bank_parsers/upi_fintech_parser.dart';
import 'dlt_bank_detector.dart';
import 'sms_parsing_result.dart';

/// Modular, production-grade transaction parser specifically tuned for Indian banking
/// and fintech SMS formats and push notifications.
///
/// Features:
/// - Telecom DLT Header matching (e.g. AD-HDFCBK, VK-SBIINB, BZ-ICICIB, etc.)
/// - Specialized parsers for HDFC, SBI, ICICI, Axis, Kotak, GPay, PhonePe, Paytm, CRED
/// - Strict rejection of OTPs, personal loan offers, limit updates, and spam
/// - UPI VPA cleanup and merchant normalizer
class RegexParser {
  static final RegExp _otpPattern = RegExp(
    r'\b(?:otp|one time password|verification code|secret code|do not share|valid for|is your code|login otp)\b',
    caseSensitive: false,
  );

  static final RegExp _spamPromoPattern = RegExp(
    r'\b(?:pre-approved|apply for|loan offer|instant loan|upgrade your card|credit limit increased|zero processing fee|congratulations! you are eligible)\b',
    caseSensitive: false,
  );

  static final List<BankParser> _parsers = [
    HdfcParser(),
    SbiParser(),
    IciciParser(),
    AxisParser(),
    KotakParser(),
    UpiFintechParser(),
    FallbackBankParser(),
  ];

  /// Parse an incoming SMS or push notification
  SmsParsingResult parse(String sender, String body, [DateTime? timestamp]) {
    final lower = body.toLowerCase();

    // 1. Immediate rejection of OTP alerts (unless it clearly describes a debit/credit txn)
    if (_otpPattern.hasMatch(lower) &&
        !lower.contains('debited') &&
        !lower.contains('credited') &&
        !lower.contains('spent')) {
      return SmsParsingResult.nonTransaction(body);
    }

    // 2. Immediate rejection of promotional & marketing SMS
    if (_spamPromoPattern.hasMatch(lower) &&
        !lower.contains('debited') &&
        !lower.contains('spent') &&
        !lower.contains('transferred to')) {
      return SmsParsingResult.nonTransaction(body);
    }

    // 3. Reject pure balance inquiry alerts without transaction activity
    final hasBalanceKeyword = lower.contains('avl bal') ||
        lower.contains('available bal') ||
        lower.contains('account balance');
    final hasTxnKeyword = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('transfer') ||
        lower.contains('sent') ||
        lower.contains('received') ||
        lower.contains('paid') ||
        lower.contains('txn rs') ||
        lower.contains('reversed');

    if (hasBalanceKeyword && !hasTxnKeyword) {
      return SmsParsingResult.nonTransaction(body);
    }

    // 4. Find matching specialized bank parser
    for (final parser in _parsers) {
      if (parser.canHandle(sender, body)) {
        final result = parser.parse(sender, body, timestamp);
        if (result != null && result.isTransaction) {
          return result;
        }
      }
    }

    // Fallback: non-transaction
    return SmsParsingResult.nonTransaction(body);
  }

  /// Detect bank display name
  String detectBankName(String sender, String body) {
    final type = DltBankDetector.detectBank(sender, body);
    return DltBankDetector.getBankDisplayName(type);
  }
}
