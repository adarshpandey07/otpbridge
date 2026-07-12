import 'package:flutter_test/flutter_test.dart';
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

  group('investment', () {
    test('Groww SIP confirmation → investment', () {
      final c = engine.classifySync(sms('VM-GROWWI',
          'Your SIP of Rs 5000 in Axis Bluechip Fund via Groww is successful. Folio 123.'));
      expect(c.category, OtpCategory.investment);
      expect(c.brand, 'Groww');
      expect(c.amount, 5000);
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Zerodha demat update → investment even with transaction words', () {
      final c = engine.classifySync(sms('VM-ZERODH',
          'Your demat account: 10 shares of TCS credited. Portfolio updated. -Zerodha'));
      expect(c.category, OtpCategory.investment);
      expect(c.brand, 'Zerodha');
    });

    test('Paytm Money resolves before Paytm', () {
      final c = engine.classifySync(sms('BX-110022',
          'Units allotted in your mutual fund order via Paytm Money. NAV Rs 89.50.'));
      expect(c.category, OtpCategory.investment);
      expect(c.brand, 'Paytm Money');
    });

    test('keyword-only mutual fund message → investment (medium band)', () {
      final c = engine.classifySync(sms('BP-565656',
          'Your SIP of Rs 2000 was processed. Units allotted: 12.4, folio 88231.'));
      expect(c.category, OtpCategory.investment);
      expect(c.confidence, greaterThanOrEqualTo(0.5));
      expect(c.confidence, lessThan(0.9));
    });
  });

  group('insurance', () {
    test('LIC premium due → insurance', () {
      final c = engine.classifySync(sms('VM-LICIND',
          'LIC premium of Rs 12,500 for policy 456 is due on 15-Aug.'));
      expect(c.category, OtpCategory.insurance);
      expect(c.brand, 'LIC');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Star Health claim settled → insurance', () {
      final c = engine.classifySync(sms('VD-STARHL',
          'Claim no 789 for your Star Health policy has been settled. Sum assured Rs 5,00,000.'));
      expect(c.category, OtpCategory.insurance);
      expect(c.brand, 'Star Health');
    });

    test('HDFC Life resolves before HDFC Bank', () {
      final c = engine.classifySync(sms('QP-778811',
          'Your HDFC Life policy renewal premium of Rs 8,000 is due on 01-Sep.'));
      expect(c.category, OtpCategory.insurance);
      expect(c.brand, 'HDFC Life');
    });

    test('keyword-only premium reminder → insurance', () {
      final c = engine.classifySync(sms('BZ-889900',
          'Your policy premium of Rs 4,999 is due on 01-Sep. Renew to keep your sum assured.'));
      expect(c.category, OtpCategory.insurance);
      expect(c.confidence, lessThan(0.9));
    });
  });

  group('tax', () {
    test('Income Tax refund → tax (rerouted from government)', () {
      final c = engine.classifySync(sms('VD-ITDEPT',
          'Your Income Tax refund of Rs 8,540 for AY 2024-25 has been processed.'));
      expect(c.category, OtpCategory.tax);
      expect(c.brand, 'Income Tax Dept');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('GST return reminder → tax', () {
      final c = engine.classifySync(sms('VD-GSTNIN',
          'GSTR-3B return for June is due. File on the GST portal before 20-Jul.'));
      expect(c.category, OtpCategory.tax);
      expect(c.brand, 'GSTN');
    });

    test('TDS / PAN keyword message → tax', () {
      final c = engine.classifySync(sms('BX-778899',
          'TDS of Rs 1,200 deducted. Download Form 16 and link your PAN for e-filing.'));
      expect(c.category, OtpCategory.tax);
    });

    test('Aadhaar OTP still → government, not tax', () {
      final c = engine.classifySync(sms('VD-UIDAII',
          'Your Aadhaar OTP is 882211. Do not share it with anyone.'));
      expect(c.category, OtpCategory.government);
      expect(c.otp, '882211');
    });
  });

  group('recharge', () {
    test('Airtel prepaid recharge confirmation → recharge, not telecom', () {
      final c = engine.classifySync(sms('VD-AIRTEL',
          'Recharge of Rs 239 successful. Validity 28 days, 1.5GB/day. -Airtel'));
      expect(c.category, OtpCategory.recharge);
      expect(c.brand, 'Airtel');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('telecom account login OTP stays telecom', () {
      final c = engine.classifySync(sms('VD-AIRTEL',
          'Your OTP for Airtel Thanks login is 445211. Do not share it.'));
      expect(c.category, OtpCategory.telecom);
      expect(c.otp, '445211');
      expect(c.brand, 'Airtel');
    });

    test('Tata Play DTH recharge → recharge', () {
      final c = engine.classifySync(sms('VM-TATAPL',
          'Your Tata Play DTH recharge of Rs 300 is successful. Next due 12-Aug.'));
      expect(c.category, OtpCategory.recharge);
      expect(c.brand, 'Tata Play');
    });

    test('keyword-only recharge confirmation → recharge', () {
      final c = engine.classifySync(sms('BP-334455',
          'Recharge successful! Talktime Rs 50 added. Validity unlimited.'));
      expect(c.category, OtpCategory.recharge);
      expect(c.confidence, lessThan(0.9));
    });
  });

  group('promotions', () {
    test('Myntra sale blast → promotions with no OTP', () {
      final c = engine.classifySync(sms('VM-MYNTRA',
          'FLAT 60% OFF! Myntra End of Reason Sale is live. Shop now!'));
      expect(c.category, OtpCategory.promotions);
      expect(c.hasOtp, isFalse);
      expect(c.otp, isNull);
      expect(c.confidence, lessThanOrEqualTo(0.7)); // modest, by design
    });

    test('generic coupon spam → promotions', () {
      final c = engine.classifySync(sms('BP-654321',
          'Get FLAT Rs 200 OFF + free delivery on your first order. '
          'Use coupon NEW200. Limited time offer!'));
      expect(c.category, OtpCategory.promotions);
      expect(c.hasOtp, isFalse);
    });

    test('real bank OTP is NEVER promotions, even with promo wording', () {
      final c = engine.classifySync(sms('AX-HDFCBK',
          'OTP 445566 for HDFC Bank txn of Rs 4,999 at Myntra. '
          'Offer: 10% cashback on your next sale purchase. Do not share.'));
      expect(c.category, isNot(OtpCategory.promotions));
      expect(c.category.isFinancial, isTrue);
      expect(c.otp, '445566');
    });

    test('plain banking OTP still classifies as banking', () {
      final c = engine.classifySync(sms('AX-HDFCBK',
          'Your OTP is 665544 for HDFC Bank internet banking login.'));
      expect(c.category, OtpCategory.bankingLogin);
      expect(c.otp, '665544');
      expect(c.confidence, greaterThanOrEqualTo(0.9));
    });

    test('UPI transaction with an offer line keeps its financial category',
        () {
      final c = engine.classifySync(sms('VM-PAYTMB',
          'Rs 250 debited via UPI to Cafe Blue. Cashback offer inside the app!'));
      expect(c.category, isNot(OtpCategory.promotions));
      expect(c.category.isFinancial, isTrue);
    });
  });
}
