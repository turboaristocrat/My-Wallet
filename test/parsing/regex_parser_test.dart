import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/parsing/regex_parser.dart';

void main() {
  late RegexParser parser;

  setUp(() {
    parser = RegexParser();
  });

  group('RegexParser Indian Bank SMS Tests', () {
    // --- HDFC BANK TESTS ---
    test('HDFC 1: UPI debit with VPA', () {
      const sms = 'Sent Rs.450.00 from HDFC Bank A/C **1234 to SWIGGY@ICICI on 11-09-26. Ref 425123456789. Avl Bal Rs.84200.50.';
      final r = parser.parse('AD-HDFCBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 450.0);
      expect(r.bankName, 'HDFC Bank');
      expect(r.accountNumberMask, '1234');
      expect(r.merchantName, 'Swiggy');
      expect(r.balanceAfter, 84200.50);
    });

    test('HDFC 2: ATM cash withdrawal', () {
      const sms = 'Rs.5,000.00 withdrawn from HDFC Bank ATM using Card ending 7890 on 09-09-26. Avl Bal: Rs.42,100.00.';
      final r = parser.parse('VM-HDFCBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 5000.0);
      expect(r.accountNumberMask, '7890');
      expect(r.balanceAfter, 42100.0);
    });

    test('HDFC 3: In-store POS purchase', () {
      const sms = 'Alert: You have spent Rs.1,299.00 on HDFC Bank Card ending 1234 at RELIANCE FRESH on 10-09-26. Avl Bal: Rs.82,901.50.';
      final r = parser.parse('AD-HDFCBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 1299.0);
      expect(r.merchantName, 'Reliance Fresh');
    });

    test('HDFC 4: Salary credit', () {
      const sms = 'Salary of Rs.95,000.00 credited to your HDFC Bank A/c **1234 on 31-Aug-26. Avl Bal: Rs.1,82,000.00.';
      final r = parser.parse('AD-HDFCBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 95000.0);
      expect(r.balanceAfter, 182000.0);
    });

    test('HDFC 5: OTP alert rejection', () {
      const sms = '458921 is your OTP for purchase of Rs.1,500.00 at AMAZON using HDFC Bank Card 1234. Do not share OTP with anyone.';
      final r = parser.parse('AD-HDFCBK', sms);
      expect(r.isTransaction, isFalse);
    });

    // --- SBI (STATE BANK OF INDIA) TESTS ---
    test('SBI 1: UPI debit to merchant', () {
      const sms = 'Dear SBI User, your A/C ending with 5678 has been debited by Rs 280.00 on 10Sep26 transfer to UBER Ref No 425345678901. Bal: Rs 15420.00';
      final r = parser.parse('VK-SBIINB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 280.0);
      expect(r.bankName, 'State Bank of India');
      expect(r.accountNumberMask, '5678');
      expect(r.merchantName, 'Uber');
      expect(r.balanceAfter, 15420.0);
    });

    test('SBI 2: ATM cash withdrawal', () {
      const sms = 'Your A/C ending 5678 debited by Rs 10000.00 on 08Sep26 at SBI ATM. Avl Bal: Rs 5,420.00.';
      final r = parser.parse('VK-SBIINB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 10000.0);
      expect(r.balanceAfter, 5420.0);
    });

    test('SBI 3: UPI credit received', () {
      const sms = 'Dear SBI User, your A/C 5678 has been credited by Rs 3,500.00 on 07Sep26 by transfer from Priya. Avl Bal: Rs 18,920.00.';
      final r = parser.parse('VK-SBIINB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 3500.0);
    });

    test('SBI 4: Verification code rejection', () {
      const sms = 'Dear SBI Customer, 982143 is your one time password for internet banking login. Valid for 5 mins. Do not share.';
      final r = parser.parse('VK-SBIINB', sms);
      expect(r.isTransaction, isFalse);
    });

    // --- ICICI BANK TESTS ---
    test('ICICI 1: Credit card online transaction', () {
      const sms = 'Your ICICI Bank Credit Card ending 4012 has been spent for INR 2,499.00 at AMAZON PAY on 11-Sep-26. Avl Lmt: INR 1,95,000.00.';
      final r = parser.parse('BZ-ICICIB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 2499.0);
      expect(r.bankName, 'ICICI Bank');
      expect(r.accountNumberMask, '4012');
      expect(r.merchantName, 'Amazon Pay');
    });

    test('ICICI 2: Savings debit alert', () {
      const sms = 'ICICI Bank Acct XX3011 debited with INR 650.00 on 10-Sep-26. Info: UPI-ZOMATO. Avl Bal INR 24,150.00.';
      final r = parser.parse('BZ-ICICIB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 650.0);
      expect(r.accountNumberMask, '3011');
      expect(r.balanceAfter, 24150.0);
    });

    test('ICICI 3: Refund credit', () {
      const sms = 'Refund of INR 399.00 has been credited to your ICICI Bank A/C XX4012 on 10-Sep-26. Avl Bal: INR 12,399.00.';
      final r = parser.parse('ICICIB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 399.0);
      expect(r.balanceAfter, 12399.0);
    });

    test('ICICI 4: OTP alert rejection', () {
      const sms = '772183 is your secret code for txn at Flipkart with ICICI Bank Card 4012. Do not share.';
      final r = parser.parse('ICICIB', sms);
      expect(r.isTransaction, isFalse);
    });

    // --- AXIS BANK TESTS ---
    test('Axis 1: Salary credit', () {
      const sms = 'INR 65,000.00 credited to your Axis Bank A/C XX9876 on 01-Sep-26 towards Salary. Avl Bal: INR 1,24,500.00.';
      final r = parser.parse('AD-AXISBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 65000.0);
      expect(r.bankName, 'Axis Bank');
      expect(r.accountNumberMask, '9876');
      expect(r.balanceAfter, 124500.0);
    });

    test('Axis 2: POS Debit', () {
      const sms = 'Your Axis Bank Card no. 9876 was spent for INR 850.00 at CCD on 09-Sep-26. Avl Bal: INR 1,23,650.00.';
      final r = parser.parse('AD-AXISBK', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 850.0);
      expect(r.accountNumberMask, '9876');
      expect(r.merchantName, 'Ccd');
    });

    // --- KOTAK MAHINDRA BANK TESTS ---
    test('Kotak 1: UPI debit', () {
      const sms = 'Sent Rs. 150.00 from Kotak Bank AC *6543 to CHAI POINT on 11-09-26. Bal Rs. 8450.00.';
      final r = parser.parse('KOTAKB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 150.0);
      expect(r.bankName, 'Kotak Mahindra');
      expect(r.accountNumberMask, '6543');
    });

    test('Kotak 2: Bill payment debit', () {
      const sms = 'Rs 1,499.00 debited from Kotak Bank A/c 6543 towards AIRTEL BROADBAND on 05-Sep-26. Bal: Rs 6,951.00.';
      final r = parser.parse('KOTAKB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 1499.0);
    });

    // --- DIGITAL WALLETS & UPI APPS ---
    test('Paytm 1: UPI payment received', () {
      const sms = 'You have received Rs 1,200.00 in your Paytm Payments Bank A/c 3344 from Rahul via UPI. Ref: 425678901234';
      final r = parser.parse('PAYTM', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 1200.0);
      expect(r.bankName, 'Paytm Payments Bank');
      expect(r.accountNumberMask, '3344');
    });

    test('Paytm 2: Wallet payment debit', () {
      const sms = 'Paid Rs. 35.00 from Paytm Wallet to METRO QR on 11-Sep-26. Updated Paytm balance: Rs 420.00.';
      final r = parser.parse('PAYTM', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 35.0);
      expect(r.merchantName, 'Metro Qr');
    });

    // --- OTHER BANKS & EDGE CASES ---
    test('Bank of Baroda debit alert', () {
      const sms = 'A/C 7788 debited for Rs 1250.00 on 09-09-26 through UPI. Bal: Rs 4210.00. Bank of Baroda.';
      final r = parser.parse('BOB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'expense');
      expect(r.amount, 1250.0);
      expect(r.bankName, 'Bank of Baroda');
    });

    test('Punjab National Bank credit', () {
      const sms = 'A/C 1122 credited by Rs 5000.00 on 04-Sep-26 by NEFT. Avl Bal: Rs 15000.00. PNB.';
      final r = parser.parse('PNB', sms);
      expect(r.isTransaction, isTrue);
      expect(r.transactionType, 'income');
      expect(r.amount, 5000.0);
      expect(r.bankName, 'Punjab National Bank');
    });

    test('Promo SMS with amount rejected', () {
      const sms = 'Congratulations! Pre-approved personal loan of Rs 5,00,000 awaits you. Click here to claim in 2 mins.';
      final r = parser.parse('DM-KOTAK', sms);
      expect(r.isTransaction, isFalse);
    });

    test('Spam investment message rejected', () {
      const sms = 'Invest Rs 1000 daily and earn Rs 5000 daily with zero risk. WhatsApp us now.';
      final r = parser.parse('VK-INVEST', sms);
      expect(r.isTransaction, isFalse);
    });
  });
}
