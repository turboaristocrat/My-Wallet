/// Identifies Indian Banks and Fintechs based on Indian DLT Telecom Sender IDs
/// and message body keywords.
///
/// In India, commercial SMS headers follow TRAI DLT formats:
/// e.g. [CircleCode]-[Header], such as AD-HDFCBK, VK-SBIINB, BZ-ICICIB, VM-AXISBK, etc.
enum BankType {
  hdfc,
  sbi,
  icici,
  axis,
  kotak,
  upiFintech, // GPay, PhonePe, Paytm, CRED
  unknown,
}

class DltBankDetector {
  static final RegExp _hdfcHeaderPattern = RegExp(
    r'^[A-Z]{2}-HDFC(?:BK)?$|^HDFC(?:BK)?$',
    caseSensitive: false,
  );

  static final RegExp _sbiHeaderPattern = RegExp(
    r'^[A-Z]{2}-SBI(?:INB|UPI|PSG|BNK)?$|^SBI(?:INB|UPI|PSG|BNK)?$',
    caseSensitive: false,
  );

  static final RegExp _iciciHeaderPattern = RegExp(
    r'^[A-Z]{2}-ICICI(?:B|T|P)?$|^ICICI(?:B|T|P)?$',
    caseSensitive: false,
  );

  static final RegExp _axisHeaderPattern = RegExp(
    r'^[A-Z]{2}-AXIS(?:BK)?$|^AXIS(?:BK)?$',
    caseSensitive: false,
  );

  static final RegExp _kotakHeaderPattern = RegExp(
    r'^[A-Z]{2}-KOTAK(?:B)?$|^KOTAK(?:B)?$',
    caseSensitive: false,
  );

  static final RegExp _upiFintechHeaderPattern = RegExp(
    r'^[A-Z]{2}-(?:PAYTM|PHNPE|PHONEPE|GPAY|GOOGLE|CRED|CREDIN)$|^(?:PAYTM|PHNPE|PHONEPE|GPAY|GOOGLE|CRED|CREDIN)$',
    caseSensitive: false,
  );

  /// Detect the bank type from sender header and SMS body
  static BankType detectBank(String sender, String body) {
    final cleanSender = sender.trim().toUpperCase();

    // 1. First priority: Telecom DLT Header matching
    if (_hdfcHeaderPattern.hasMatch(cleanSender)) return BankType.hdfc;
    if (_sbiHeaderPattern.hasMatch(cleanSender)) return BankType.sbi;
    if (_iciciHeaderPattern.hasMatch(cleanSender)) return BankType.icici;
    if (_axisHeaderPattern.hasMatch(cleanSender)) return BankType.axis;
    if (_kotakHeaderPattern.hasMatch(cleanSender)) return BankType.kotak;
    if (_upiFintechHeaderPattern.hasMatch(cleanSender)) {
      return BankType.upiFintech;
    }

    // 2. Second priority: Sender substring
    if (cleanSender.contains('HDFC')) return BankType.hdfc;
    if (cleanSender.contains('SBI') || cleanSender.contains('STATE BANK')) {
      return BankType.sbi;
    }
    if (cleanSender.contains('ICICI')) return BankType.icici;
    if (cleanSender.contains('AXIS')) return BankType.axis;
    if (cleanSender.contains('KOTAK')) return BankType.kotak;
    if (cleanSender.contains('PAYTM') ||
        cleanSender.contains('PHONEPE') ||
        cleanSender.contains('PHNPE') ||
        cleanSender.contains('GPAY') ||
        cleanSender.contains('CRED')) {
      return BankType.upiFintech;
    }

    // 3. Third priority: Body keyword heuristics
    final lowerBody = body.toLowerCase();
    if (lowerBody.contains('hdfc bank') || lowerBody.contains('hdfc a/c')) {
      return BankType.hdfc;
    }
    if (lowerBody.contains('state bank of india') ||
        lowerBody.contains('sbi a/c') ||
        lowerBody.contains('sbi upi')) {
      return BankType.sbi;
    }
    if (lowerBody.contains('icici bank') || lowerBody.contains('icici a/c')) {
      return BankType.icici;
    }
    if (lowerBody.contains('axis bank') || lowerBody.contains('axis a/c')) {
      return BankType.axis;
    }
    if (lowerBody.contains('kotak bank') || lowerBody.contains('kotak 811')) {
      return BankType.kotak;
    }
    if (lowerBody.contains('phonepe') ||
        lowerBody.contains('paytm') ||
        lowerBody.contains('google pay') ||
        lowerBody.contains('cred')) {
      return BankType.upiFintech;
    }

    return BankType.unknown;
  }

  /// Detect specific bank or fintech name string from sender and body
  static String? detectBankName(String sender, String body) {
    final s = sender.trim().toUpperCase();
    final b = body.toUpperCase();

    if (s.contains('HDFC') || b.contains('HDFC BANK')) return 'HDFC Bank';
    if (s.contains('SBI') || b.contains('STATE BANK')) return 'State Bank of India';
    if (s.contains('ICICI') || b.contains('ICICI BANK')) return 'ICICI Bank';
    if (s.contains('AXIS') || b.contains('AXIS BANK')) return 'Axis Bank';
    if (s.contains('KOTAK') || b.contains('KOTAK')) return 'Kotak Mahindra';
    if (s.contains('PAYTM') || b.contains('PAYTM')) return 'Paytm Payments Bank';
    if (s.contains('PNB') || b.contains('PUNJAB NATIONAL')) return 'Punjab National Bank';
    if (s.contains('BOB') || b.contains('BANK OF BARODA')) return 'Bank of Baroda';
    if (s.contains('CANARA') || b.contains('CANARA BANK')) return 'Canara Bank';
    if (s.contains('UNION') || b.contains('UNION BANK')) return 'Union Bank of India';
    if (s.contains('IDFC') || b.contains('IDFC FIRST')) return 'IDFC FIRST Bank';
    if (s.contains('INDUS') || b.contains('INDUSIND')) return 'IndusInd Bank';
    if (s.contains('GPAY') || b.contains('GOOGLE PAY')) return 'Google Pay';
    if (s.contains('PHNPE') || s.contains('PHONEPE') || b.contains('PHONEPE')) return 'PhonePe';
    if (s.contains('CRED') || RegExp(r'\bCRED\b', caseSensitive: false).hasMatch(b)) return 'Cred';
    if (s.contains('AMAZON') || b.contains('AMAZON PAY')) return 'Amazon Pay';

    return null;
  }

  /// Get standard display name for bank
  static String getBankDisplayName(BankType type) {
    switch (type) {
      case BankType.hdfc:
        return 'HDFC Bank';
      case BankType.sbi:
        return 'State Bank of India';
      case BankType.icici:
        return 'ICICI Bank';
      case BankType.axis:
        return 'Axis Bank';
      case BankType.kotak:
        return 'Kotak Mahindra';
      case BankType.upiFintech:
        return 'UPI / Fintech';
      case BankType.unknown:
        return 'Bank';
    }
  }
}
