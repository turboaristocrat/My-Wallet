import 'package:intl/intl.dart';

/// Currency formatter with support for Indian numbering format (Lakhs & Crores)
/// Example: ₹1,24,500.00 instead of ₹124,500.00
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _indianCurrencyWithDecimals =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static final NumberFormat _indianCurrencyCompact =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  /// Format amount to standard Indian currency string (e.g. ₹1,24,500.00)
  /// If [showDecimals] is false, drops the paise (e.g. ₹1,24,500)
  /// If [hideAmount] is true, masks the number for screen privacy (e.g. ₹••••••)
  static String format(
    double amount, {
    bool showDecimals = true,
    bool hideAmount = false,
    bool showSign = false,
  }) {
    if (hideAmount) {
      return '₹••••••';
    }

    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final formatted = showDecimals
        ? _indianCurrencyWithDecimals.format(absAmount)
        : _indianCurrencyCompact.format(absAmount);

    if (isNegative) {
      return '-$formatted';
    } else if (showSign && amount > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Compact representation for charts or small badges (e.g., ₹1.2L, ₹45K, ₹2.5Cr)
  static String formatCompact(double amount, {bool hideAmount = false}) {
    if (hideAmount) return '₹•••';

    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (abs >= 10000000) {
      return '$sign₹${(abs / 10000000).toStringAsFixed(1)}Cr';
    } else if (abs >= 100000) {
      return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
    } else if (abs >= 1000) {
      return '$sign₹${(abs / 1000).toStringAsFixed(1)}K';
    }
    return '$sign₹${abs.toStringAsFixed(0)}';
  }
}
