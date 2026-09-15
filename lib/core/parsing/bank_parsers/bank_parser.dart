import '../sms_parsing_result.dart';

/// Abstract base contract for all bank-specific parsers
abstract class BankParser {
  /// Name of the bank
  String get bankName;

  /// Checks if this parser can handle the given sender and body
  bool canHandle(String sender, String body);

  /// Parse the SMS message body and return a structured SmsParsingResult
  SmsParsingResult? parse(String sender, String body, [DateTime? timestamp]);
}
