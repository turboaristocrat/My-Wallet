import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/utils/currency_formatter.dart';
import 'package:my_wallet/core/constants/app_colors.dart';
import 'package:my_wallet/features/dashboard/data/dashboard_providers.dart';

void main() {
  group('Core Formatting Smoke Tests', () {
    test('CurrencyFormatter formats Indian numbering correctly', () {
      expect(CurrencyFormatter.format(124500), '₹1,24,500.00');
      expect(CurrencyFormatter.format(500), '₹500.00');
      expect(CurrencyFormatter.format(10000000), '₹1,00,00,000.00');
    });

    test('CurrencyFormatter respects privacy mask', () {
      expect(CurrencyFormatter.format(124500, hideAmount: true), '₹••••••');
      expect(CurrencyFormatter.formatCompact(124500, hideAmount: true), '₹•••');
    });

    test('AppColors tokens are loaded properly', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.income, isNotNull);
      expect(AppColors.expense, isNotNull);
    });
  });

  group('Dashboard UI State & Mode Tests', () {
    test('MonthlyFlow accurately holds and calculates net flow', () {
      const flow = MonthlyFlow(income: 5000.0, expense: 2000.0);
      expect(flow.income, 5000.0);
      expect(flow.expense, 2000.0);
      expect(flow.income - flow.expense, 3000.0);
    });

    test('AccountsDisplayMode enum values exist and toggle properly', () {
      expect(AccountsDisplayMode.values.length, 2);
      expect(AccountsDisplayMode.carousel.name, 'carousel');
      expect(AccountsDisplayMode.tiles.name, 'tiles');
    });
  });
}
