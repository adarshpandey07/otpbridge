import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/classification/brand_catalog.dart';
import 'package:otpbridge/data/classification/classification_engine_impl.dart';
import 'package:otpbridge/domain/models/models.dart';

IncomingSms sms(String sender, String body) => IncomingSms(
      id: 'test-${body.hashCode}',
      sender: sender,
      body: body,
      receivedAt: DateTime(2026, 7, 12, 10, 30),
    );

void main() {
  final engine = DefaultClassificationEngine();

  group('DefaultClassificationEngine — real-world messages', () {
    test('Amazon OTP → ecommerce, high confidence', () {
      final c = engine.classifySync(sms('VM-AMAZON',
          'Your Amazon OTP is 563412. Do not share it with anyone.'));
      expect(c.category, OtpCategory.ecommerce);
      expect(c.otp, '563412');
      expect(c.hasOtp, isTrue);
      expect(c.brand, 'Amazon');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
      expect(c.engine, 'rules');
    });

    test('SBI debit + UPI reversal → bankingTransaction/upi with amount', () {
      final c = engine.classifySync(sms('JD-SBIINB',
          'Rs 4500 debited from A/c XX3421 via UPI. OTP for reversal 284761 -SBI'));
      expect(
        c.category,
        anyOf(OtpCategory.bankingTransaction, OtpCategory.upi),
      );
      expect(c.otp, '284761');
      expect(c.amount, 4500);
      expect(c.brand, 'SBI');
      expect(c.transactionType, TransactionType.debit);
      expect(c.confidence, greaterThanOrEqualTo(0.9));
      expect(c.category.isFinancial, isTrue);
    });

    test('HDFC NetBanking login → bankingLogin', () {
      final c = engine.classifySync(sms('AX-HDFCBK',
          '123456 is your OTP for HDFC Bank NetBanking login. Valid for 10 min.'));
      expect(c.category, OtpCategory.bankingLogin);
      expect(c.otp, '123456');
      expect(c.brand, 'HDFC Bank');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Swiggy delivery OTP → foodDelivery', () {
      final c = engine
          .classifySync(sms('TX-SWIGGY', 'Your Swiggy delivery OTP is 8842'));
      expect(c.category, OtpCategory.foodDelivery);
      expect(c.otp, '8842');
      expect(c.brand, 'Swiggy');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('WhatsApp verification → login/registration', () {
      final c = engine.classifySync(
          sms('JX-WHTSAP', 'Use 907845 to verify your WhatsApp account'));
      expect(c.category, anyOf(OtpCategory.login, OtpCategory.registration));
      expect(c.otp, '907845');
      expect(c.brand, 'WhatsApp');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('plain reference number is NOT a forwardable OTP', () {
      final c = engine.classifySync(
          sms('BZ-ORDRSH', 'Your order will arrive today. Ref: 998812'));
      expect(c.hasOtp, isFalse);
      expect(c.otp, isNull);
    });

    test('Blinkit order OTP → grocery', () {
      final c = engine.classifySync(
          sms('VK-BLNKIT', 'Blinkit: 4471 is your OTP for order #A12'));
      expect(c.category, OtpCategory.grocery);
      expect(c.otp, '4471');
      expect(c.brand, 'Blinkit');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('promotional SMS with no code → hasOtp false', () {
      final c = engine.classifySync(sms(
          'VM-OFFERS', 'Mega Sale! Up to 70% off on everything. Shop now!'));
      expect(c.hasOtp, isFalse);
      expect(c.otp, isNull);
      expect(c.confidence, lessThan(0.9));
    });
  });

  group('DefaultClassificationEngine — banking login vs transaction', () {
    test('debit + txn words from a bank → bankingTransaction', () {
      final c = engine.classifySync(sms('AX-HDFCBK',
          'Rs 999 debited from your account via txn 12345678. OTP 445566 to authorize.'));
      expect(c.category, OtpCategory.bankingTransaction);
      expect(c.otp, '445566');
      expect(c.amount, 999);
    });

    test('login words from a bank → bankingLogin', () {
      final c = engine.classifySync(sms('VK-ICICIB',
          'Your OTP for ICICI Bank internet banking login is 665544.'));
      expect(c.category, OtpCategory.bankingLogin);
      expect(c.otp, '665544');
      expect(c.brand, 'ICICI Bank');
    });

    test('credit card keywords from a bank → creditCard', () {
      final c = engine.classifySync(sms('VM-KOTAKB',
          'OTP 112233 for your Kotak credit card transaction of Rs 1,999.00'));
      expect(c.category, OtpCategory.creditCard);
      expect(c.otp, '112233');
      expect(c.amount, 1999.0);
    });

    test('multiple numbers: OTP picked, not amount/card/masked account', () {
      final c = engine.classifySync(sms('AX-HDFCBK',
          'Rs 2,500.00 spent on HDFC Bank Card XX1234 at AMAZON. OTP 334455 to confirm.'));
      expect(c.otp, '334455');
      expect(c.amount, 2500.0);
      expect(c.merchant, 'AMAZON');
      expect(c.transactionType, TransactionType.debit);
    });
  });

  group('DefaultClassificationEngine — confidence bands', () {
    test('sender-ID brand match scores highest', () {
      final c = engine.classifySync(
          sms('VM-AMAZON-S', 'Your OTP is 563412 for your recent order.'));
      expect(c.brand, 'Amazon');
      expect(c.confidence, greaterThanOrEqualTo(0.95));
    });

    test('body-only brand match is high but below sender match', () {
      final c = engine.classifySync(
          sms('BX-110011', 'Your Amazon OTP is 563412 for your order.'));
      expect(c.brand, 'Amazon');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('keyword-only heuristic lands in the medium band', () {
      final c = engine.classifySync(sms(
          'QP-303030', 'Your login code is 776612 for your account access.'));
      expect(c.category, OtpCategory.login);
      expect(c.confidence, greaterThanOrEqualTo(0.5));
      expect(c.confidence, lessThan(0.9));
      expect(c.otp, '776612');
    });

    test('unknown sender and body → unknown at 0.3', () {
      final c = engine.classifySync(sms('QZ-999999', 'Hello there.'));
      expect(c.category, OtpCategory.unknown);
      expect(c.confidence, closeTo(0.3, 0.001));
      expect(c.hasOtp, isFalse);
    });

    test('financial heuristics without a known brand → bankingTransaction',
        () {
      final c = engine.classifySync(sms('XX-UNKNWN',
          'Rs 3,000 debited from A/c XX9988. OTP 909012 to proceed.'));
      expect(c.category, OtpCategory.bankingTransaction);
      expect(c.otp, '909012');
      expect(c.amount, 3000);
      expect(c.confidence, greaterThanOrEqualTo(0.5));
    });
  });

  group('DefaultClassificationEngine — contract', () {
    test('constructor takes no required arguments', () {
      expect(DefaultClassificationEngine(), isA<DefaultClassificationEngine>());
    });

    test('classify() delegates to the rules result for now', () async {
      final message = sms('VM-AMAZON', 'Your Amazon OTP is 563412.');
      final async = await engine.classify(message);
      final sync = engine.classifySync(message);
      expect(async, sync);
      expect(async.engine, 'rules');
    });

    test('never throws: empty body and sender', () {
      final c = engine.classifySync(sms('', ''));
      expect(c.category, OtpCategory.unknown);
      expect(c.hasOtp, isFalse);
    });

    test('never throws: pathological body', () {
      final c = engine.classifySync(
          sms('+919812345678', '💥' * 500 + r'\\\((((' '🙂'));
      expect(c, isA<SmsClassification>());
    });
  });

  group('BrandCatalog — sender normalisation and lookup', () {
    const catalog = BrandCatalog();

    test('normalises DLT headers', () {
      expect(BrandCatalog.normalizeSender('VM-AMAZON'), 'AMAZON');
      expect(BrandCatalog.normalizeSender('VM-AMAZON-S'), 'AMAZON');
      expect(BrandCatalog.normalizeSender('AX-HDFCBK'), 'HDFCBK');
      expect(BrandCatalog.normalizeSender('jd-sbiinb'), 'SBIINB');
      expect(BrandCatalog.normalizeSender('+919876543210'), '');
    });

    test('sender match wins over body keywords', () {
      final match = catalog.lookup(
          sender: 'TX-SWIGGY', body: 'Order from Amazon? Your code is 1122.');
      expect(match?.brand, 'Swiggy');
      expect(match?.source, BrandMatchSource.sender);
    });

    test('longer brands match before their prefixes (Uber Eats vs Uber)', () {
      final match = catalog.lookup(
          sender: 'DM-102030',
          body: 'Your Uber Eats order code is 5566.');
      expect(match?.brand, 'Uber Eats');
      expect(match?.category, OtpCategory.foodDelivery);
    });

    test('unknown sender and body → null', () {
      expect(
        catalog.lookup(sender: 'ZZ-NOBODY', body: 'Nothing to see here.'),
        isNull,
      );
    });

    test('catalog covers 60+ brands', () {
      expect(BrandCatalog.entries.length, greaterThanOrEqualTo(60));
    });
  });
}
