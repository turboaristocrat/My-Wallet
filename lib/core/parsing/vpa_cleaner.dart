/// Cleans, strips, and normalizes UPI VPA addresses and cryptic merchant descriptions
/// into clean, readable merchant names (e.g. Swiggy, Zomato, Uber, Blinkit).
class VpaCleaner {
  static final RegExp _vpaSuffixPattern = RegExp(
    r'@(?:okhdfcbank|okaxis|okicici|oksbi|paytm|ybl|upi|ibl|axl|barodampay|fednet|aubank|icici|sbi|hdfcbank|kotak|axisbank|yesbank|waicici|postbank|jupiteraxis|fi)\b',
    caseSensitive: false,
  );

  static final Map<String, String> _knownMerchantKeywords = {
    'SWIGGY': 'Swiggy',
    'ZOMATO': 'Zomato',
    'UBER': 'Uber',
    'OLA': 'Ola Cabs',
    'BLINKIT': 'Blinkit',
    'ZEPTO': 'Zepto',
    'INSTAMART': 'Instamart',
    'AMAZON PAY': 'Amazon Pay',
    'AMAZON': 'Amazon',
    'FLIPKART': 'Flipkart',
    'MYNTRA': 'Myntra',
    'NYKAA': 'Nykaa',
    'NETFLIX': 'Netflix',
    'SPOTIFY': 'Spotify',
    'APPLE': 'Apple',
    'GOOGLE': 'Google Play',
    'YOUTUBE': 'YouTube',
    'BOOKMYSHOW': 'BookMyShow',
    'IRCTC': 'IRCTC',
    'MAKEMYTRIP': 'MakeMyTrip',
    'GOIBIBO': 'Goibibo',
    'CRED': 'CRED',
    'AIRTEL': 'Airtel',
    'JIO': 'Jio',
    'VI': 'Vodafone Idea',
    'STARBUCKS': 'Starbucks',
    'MCDONALDS': 'McDonalds',
    'DOMINOS': 'Dominos Pizza',
    'PIZZAHUT': 'Pizza Hut',
    'KFC': 'KFC',
    'SUBWAY': 'Subway',
    'DECATHLON': 'Decathlon',
    'DMART': 'DMart',
    'RELIANCE FRESH': 'Reliance Fresh',
    'RELIANCE': 'Reliance Retail',
    'APOLLO': 'Apollo Pharmacy',
    'PHARMEASY': 'PharmEasy',
    '1MG': 'Tata 1mg',
    'TATA': 'Tata',
  };

  /// Cleans up raw merchant string or UPI VPA into human-friendly merchant name
  static String cleanMerchant(String raw) {
    if (raw.trim().isEmpty) return 'Unknown Merchant';

    var text = raw.trim();

    // 1. Check known brand keywords first
    final upper = text.toUpperCase();
    for (final entry in _knownMerchantKeywords.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }

    // 2. Strip VPA handle suffixes (e.g. '@okhdfcbank', '@paytm')
    text = text.replaceAll(_vpaSuffixPattern, '');

    // 3. Remove leading transfer tokens: "to vpa ", "paid to ", "transferred to ", "at ", etc.
    text = text.replaceAll(
      RegExp(r'^(?:paid\s+to|transfer\s+to|transferred\s+to|to\s+vpa|to|vpa|at|info)\s+', caseSensitive: false),
      '',
    );

    // 4. Remove merchant tech suffixes like ".paytm", "-upi", etc.
    text = text.replaceAll(RegExp(r'[._-](?:paytm|upi|merchant|retail|online|b2b|nodal|pos)$', caseSensitive: false), '');

    // 5. Replace underscores, dots, hyphens, and slashes with spaces
    text = text.replaceAll(RegExp(r'[-_./]'), ' ');

    // 6. Strip trailing or leading reference IDs (sequences of 4+ digits)
    text = text.replaceAll(RegExp(r'\b\d{4,}\b'), '');

    // 7. Normalize excess whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return 'Unknown Merchant';

    // 8. Capitalize into Title Case
    return _toTitleCase(text);
  }

  static String _toTitleCase(String text) {
    final words = text.toLowerCase().split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      if (w.length == 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1);
    });
    return capitalized.join(' ').trim();
  }
}
