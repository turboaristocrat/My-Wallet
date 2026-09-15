import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:my_wallet/core/database/app_database.dart';
import 'package:my_wallet/core/parsing/bank_parsers/axis_parser.dart';
import 'package:my_wallet/core/parsing/bank_parsers/hdfc_parser.dart';
import 'package:my_wallet/core/parsing/bank_parsers/icici_parser.dart';
import 'package:my_wallet/core/parsing/bank_parsers/kotak_parser.dart';
import 'package:my_wallet/core/parsing/bank_parsers/sbi_parser.dart';
import 'package:my_wallet/core/parsing/bank_parsers/upi_fintech_parser.dart';
import 'package:my_wallet/core/parsing/dlt_bank_detector.dart';
import 'package:my_wallet/core/parsing/regex_parser.dart';
import 'package:my_wallet/core/parsing/transaction_deduplication.dart';
import 'package:my_wallet/core/parsing/vpa_cleaner.dart';
import 'package:my_wallet/features/rules/data/rules_repository.dart';

void main() {
  group('DLT Telecom Header & Bank Detector Tests', () {
    test('accurately detects banks from TRAI DLT telecom headers', () {
      expect(DltBankDetector.detectBank('AD-HDFCBK', ''), BankType.hdfc);
      expect(DltBankDetector.detectBank('VM-HDFCBK', ''), BankType.hdfc);
      expect(DltBankDetector.detectBank('BZ-SBIINB', ''), BankType.sbi);
      expect(DltBankDetector.detectBank('VK-SBIUPI', ''), BankType.sbi);
      expect(DltBankDetector.detectBank('VK-ICICIB', ''), BankType.icici);
      expect(DltBankDetector.detectBank('VM-AXISBK', ''), BankType.axis);
      expect(DltBankDetector.detectBank('AD-KOTAKB', ''), BankType.kotak);
      expect(DltBankDetector.detectBank('VK-PAYTM', ''), BankType.upiFintech);
      expect(DltBankDetector.detectBank('VM-PHNPE', ''), BankType.upiFintech);
      expect(DltBankDetector.detectBank('AD-GPAY', ''), BankType.upiFintech);
      expect(DltBankDetector.detectBank('VK-CRED', ''), BankType.upiFintech);
    });

    test('detects banks from body fallback when header is generic', () {
      expect(DltBankDetector.detectBank('NOTICE', 'Rs 500 debited from your HDFC Bank A/c'), BankType.hdfc);
      expect(DltBankDetector.detectBank('ALERTS', 'State Bank of India A/c credited with Rs 1000'), BankType.sbi);
      expect(DltBankDetector.detectBank('BANK', 'Dear Customer, your ICICI Bank A/c was debited'), BankType.icici);
    });
  });

  group('VPA Cleaner & Merchant Normalizer Tests', () {
    test('strips UPI VPA handles into clean brand names', () {
      expect(VpaCleaner.cleanMerchant('swiggy.paytm@paytm'), 'Swiggy');
      expect(VpaCleaner.cleanMerchant('zomato-restaurant@icici'), 'Zomato');
      expect(VpaCleaner.cleanMerchant('uber.india@axisbank'), 'Uber');
      expect(VpaCleaner.cleanMerchant('blinkit-groceries@ybl'), 'Blinkit');
      expect(VpaCleaner.cleanMerchant('amazonpay@apl'), 'Amazon');
      expect(VpaCleaner.cleanMerchant('irctc@sbi'), 'IRCTC');
      expect(VpaCleaner.cleanMerchant('netflix.com@okhdfcbank'), 'Netflix');
    });

    test('handles cryptic or unlisted merchant names cleanly', () {
      expect(VpaCleaner.cleanMerchant('CHAI_POINT_KORAMANGALA'), 'Chai Point Koramangala');
      expect(VpaCleaner.cleanMerchant('BLUE_TOKAI_COFFEE'), 'Blue Tokai Coffee');
      expect(VpaCleaner.cleanMerchant('to VPA corner.store@upi'), 'Corner Store');
    });
  });

  group('HDFC Bank Parser Tests', () {
    final parser = HdfcParser();

    test('parses HDFC account debit message with available balance', () {
      const sms = 'Sent Rs.450.00 from HDFC Bank A/C *1234 to SWIGGY on 15-09-26. Ref 123456789. Avl bal INR 15,230.50';
      final res = parser.parse('AD-HDFCBK', sms);
      expect(res, isNotNull);
      expect(res!.isTransaction, isTrue);
      expect(res.amount, 450.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, 'Swiggy');
      expect(res.accountNumberMask, '1234');
      expect(res.balanceAfter, 15230.50);
      expect(res.bankName, 'HDFC Bank');
      expect(res.paymentType, 'upi');
    });

    test('parses HDFC card debit at merchant', () {
      const sms = 'Spent Rs.1,250.00 From HDFC Bank Card x5678 At AMAZON On 15-SEP-26. Bal: Rs 25,000.00';
      final res = parser.parse('VM-HDFCBK', sms);
      expect(res, isNotNull);
      expect(res!.amount, 1250.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, 'Amazon');
      expect(res.accountNumberMask, '5678');
      expect(res.paymentType, 'card');
    });

    test('parses HDFC ATM cash withdrawal with location', () {
      const sms = 'Rs.2,000.00 withdrawn from HDFC Bank A/C *1234 on 15-SEP-26. At ATM KORAMANGALA On 15-SEP-26. Avl Bal Rs.10,000.00';
      final res = parser.parse('AD-HDFCBK', sms);
      expect(res, isNotNull);
      expect(res!.amount, 2000.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, contains('ATM'));
      expect(res.paymentType, 'cash');
    });

    test('parses HDFC refund reversal', () {
      const sms = 'HDFC Bank: Rs.350.00 reversed to Card *1234 By SWIGGY on 15-SEP-26';
      final res = parser.parse('AD-HDFCBK', sms);
      expect(res, isNotNull);
      expect(res!.amount, 350.0);
      expect(res.transactionType, 'income');
      expect(res.merchantName, 'Swiggy');
    });
  });

  group('SBI Bank Parser Tests', () {
    final parser = SbiParser();

    test('parses SBI debit alert with ref number and balance', () {
      const sms = 'Dear SBI User, your A/c ending 1234 debited by Rs 350.00 on 15Sep26 transfer to SWIGGY Ref No 123456789. Avail Bal Rs 18,200.00';
      final res = parser.parse('BZ-SBIINB', sms);
      expect(res, isNotNull);
      expect(res!.amount, 350.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, 'Swiggy');
      expect(res.accountNumberMask, '1234');
      expect(res.balanceAfter, 18200.0);
      expect(res.bankName, 'State Bank of India');
    });

    test('parses SBI credit card spend', () {
      const sms = 'Spent Rs.1,450.00 on SBI Credit Card ending 9012 at FLIPKART on 15-Sep-26. Avail Bal Rs 45,000';
      final res = parser.parse('BZ-SBICRD', sms);
      expect(res, isNotNull);
      expect(res!.amount, 1450.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, 'Flipkart');
      expect(res.accountNumberMask, '9012');
      expect(res.paymentType, 'card');
    });
  });

  group('ICICI Bank Parser Tests', () {
    final parser = IciciParser();

    test('parses ICICI debit with UPI merchant info', () {
      const sms = 'ICICI Bank Acct XX1234 debited for Rs 850.00 on 15-Sep-26. Info: UPI*SWIGGY*12345. Available Balance is Rs 22,450.00';
      final res = parser.parse('VK-ICICIB', sms);
      expect(res, isNotNull);
      expect(res!.amount, 850.0);
      expect(res.transactionType, 'expense');
      expect(res.merchantName, 'Swiggy');
      expect(res.accountNumberMask, '1234');
      expect(res.balanceAfter, 22450.0);
      expect(res.paymentType, 'upi');
    });
  });

  group('Axis and Kotak Bank Parser Tests', () {
    test('Axis Bank card spend', () {
      final parser = AxisParser();
      const sms = 'Spent INR 650.00 on Axis Bank Card ending 1234 at BLINKIT on 15-09-2026. Bal INR 14,000';
      final res = parser.parse('VM-AXISBK', sms);
      expect(res, isNotNull);
      expect(res!.amount, 650.0);
      expect(res.merchantName, 'Blinkit');
      expect(res.accountNumberMask, '1234');
      expect(res.paymentType, 'card');
    });

    test('Kotak Bank debit', () {
      final parser = KotakParser();
      const sms = 'Rs. 420.00 debited from Kotak Bank A/c ...1234 on 15-Sep-26 towards ZOMATO. Avl bal Rs 9,450.00';
      final res = parser.parse('AD-KOTAKB', sms);
      expect(res, isNotNull);
      expect(res!.amount, 420.0);
      expect(res.merchantName, 'Zomato');
      expect(res.accountNumberMask, '1234');
    });
  });

  group('UPI Fintech Parser Tests (GPay, PhonePe, Paytm, CRED)', () {
    final parser = UpiFintechParser();

    test('Google Pay payment confirmation', () {
      const sms = 'Paid ₹180 to Chai Point on Google Pay. UPI transaction ID: 1234567890';
      final res = parser.parse('AD-GPAY', sms);
      expect(res, isNotNull);
      expect(res!.amount, 180.0);
      expect(res.merchantName, 'Chai Point');
      expect(res.transactionType, 'expense');
    });

    test('PhonePe payment confirmation', () {
      const sms = 'You have paid Rs. 320 to Swiggy using PhonePe. Txn ID: T123456';
      final res = parser.parse('VM-PHNPE', sms);
      expect(res, isNotNull);
      expect(res!.amount, 320.0);
      expect(res.merchantName, 'Swiggy');
    });
  });

  group('Unified RegexParser Orchestrator Tests', () {
    final orchestrator = RegexParser();

    test('rejects OTP alerts', () {
      const otp = 'Your OTP for transaction of Rs 500 on HDFC Bank is 123456. Do not share with anyone.';
      final res = orchestrator.parse('AD-HDFCBK', otp);
      expect(res.isTransaction, isFalse);
    });

    test('rejects promotional loan offers', () {
      const promo = 'Congratulations! You are eligible for a pre-approved personal loan of Rs 5,00,000 with zero processing fee. Apply now!';
      final res = orchestrator.parse('AD-HDFCBK', promo);
      expect(res.isTransaction, isFalse);
    });

    test('rejects pure balance inquiry', () {
      const bal = 'Your available balance for HDFC Bank A/c *1234 is Rs. 15,200.00 as on 15-Sep-26.';
      final res = orchestrator.parse('AD-HDFCBK', bal);
      expect(res.isTransaction, isFalse);
    });
  });

  group('Transaction Deduplication Engine Tests', () {
    final deduplication = TransactionDeduplication();

    setUp(() {
      deduplication.clear();
    });

    test('detects collision when both SMS and Push Notification arrive for same txn', () {
      final now = DateTime.now();
      const sms = 'Sent Rs.450.00 from HDFC Bank A/C *1234 to SWIGGY on 15-09-26. Avl bal INR 15,000';
      final push = 'Paid ₹450 to Swiggy on Google Pay';

      final parser = RegexParser();
      final parsedSms = parser.parse('AD-HDFCBK', sms, now);
      final parsedPush = parser.parse('AD-GPAY', push, now);

      expect(parsedSms.isTransaction, isTrue);
      expect(parsedPush.isTransaction, isTrue);

      // First one (SMS) is NOT a duplicate
      expect(deduplication.isDuplicate(parsedSms), isFalse);

      // Second one (Push) with same amount, merchant, and timestamp IS a duplicate!
      expect(deduplication.isDuplicate(parsedPush), isTrue);
    });
  });

  group('Smart Rules Engine Tests (PennyWise enhancements)', () {
    late AppDatabase db;
    late RulesRepository rulesRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      rulesRepo = RulesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('evaluates amount_greater_than threshold', () async {
      await rulesRepo.createRule(
        ruleName: 'High Value Expenses',
        triggerType: 'amount_greater_than',
        triggerValue: '5000',
        actionSetPaymentType: 'net_banking',
        priority: 10,
      );

      final matchUnder = await rulesRepo.evaluateRules(
        text: 'Debit alert',
        amount: 2500.0,
      );
      expect(matchUnder, isNull);

      final matchOver = await rulesRepo.evaluateRules(
        text: 'Debit alert',
        amount: 7500.0,
      );
      expect(matchOver, isNotNull);
      expect(matchOver!.paymentType, 'net_banking');
      expect(matchOver.isBlocked, isFalse);
    });

    test('evaluates block_transaction to discard unwanted messages', () async {
      await rulesRepo.createRule(
        ruleName: 'Ignore Petty Cash Transfers',
        triggerType: 'block_transaction',
        triggerValue: 'PETTYCASH',
        priority: 50,
      );

      final match = await rulesRepo.evaluateRules(
        text: 'Paid Rs 50 to PETTYCASH VPA',
        merchant: 'PETTYCASH',
      );
      expect(match, isNotNull);
      expect(match!.isBlocked, isTrue);
    });
  });
}
