import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/classification/otp_extractor.dart';
import 'package:otpbridge/domain/models/models.dart';

void main() {
  const extractor = OtpExtractor();

  group('OtpExtractor — OTP extraction', () {
    test('extracts a 6-digit OTP after the keyword', () {
      final r = extractor
          .extract('Your Amazon OTP is 563412. Do not share it with anyone.');
      expect(r.otp, '563412');
      expect(r.hasOtp, isTrue);
      expect(r.hasOtpKeyword, isTrue);
    });

    test('extracts OTP before the keyword ("123456 is your OTP")', () {
      final r = extractor.extract(
          '123456 is your OTP for HDFC Bank NetBanking login. Valid for 10 min.');
      expect(r.otp, '123456');
    });

    test('extracts a 4-digit OTP', () {
      final r = extractor.extract('Your Swiggy delivery OTP is 8842');
      expect(r.otp, '8842');
    });

    test('recognises "Use NNN to verify" phrasing', () {
      final r =
          extractor.extract('Use 907845 to verify your WhatsApp account');
      expect(r.otp, '907845');
    });

    test('recognises "verification code" phrasing', () {
      final r = extractor
          .extract('Your verification code is 55123. Enter it to continue.');
      expect(r.otp, '55123');
    });

    test('recognises "one time password" phrasing', () {
      final r = extractor
          .extract('4902 is the one time password for your transaction.');
      expect(r.otp, '4902');
    });

    test('handles split codes like "123-456" next to the keyword', () {
      final r = extractor.extract('Your OTP is 123-456. Valid for 5 minutes.');
      expect(r.otp, '123456');
    });
  });

  group('OtpExtractor — false-positive rejection', () {
    test('a bare reference number is NOT an OTP (no OTP keyword)', () {
      final r =
          extractor.extract('Your order will arrive today. Ref: 998812');
      expect(r.hasOtp, isFalse);
      expect(r.otp, isNull);
      expect(r.hasOtpKeyword, isFalse);
    });

    test('promotional SMS with no code has no OTP', () {
      final r = extractor
          .extract('Mega Sale! Up to 70% off on everything. Shop now!');
      expect(r.hasOtp, isFalse);
      expect(r.otp, isNull);
    });

    test('masked account XX3421 is never read as the OTP', () {
      final r = extractor.extract(
          'Rs 4500 debited from A/c XX3421 via UPI. OTP for reversal 284761 -SBI');
      expect(r.otp, '284761');
    });

    test('amount is not picked as OTP even when 4+ digits', () {
      final r = extractor
          .extract('Rs 4500 debited from A/c XX3421. OTP is 887711 -SBI');
      expect(r.otp, '887711');
      expect(r.amount, 4500);
    });

    test('6-digit amount vs 6-digit code: the code wins', () {
      final r = extractor.extract(
          'Rs 450000 debited from your account. Use OTP 123456 to confirm.');
      expect(r.otp, '123456');
      expect(r.amount, 450000);
    });

    test('card last-4 ("Card XX1234", "ending 1234") is skipped', () {
      final r = extractor.extract(
          'Rs 2,500.00 spent on HDFC Bank Card XX1234 at AMAZON. OTP 334455 to confirm.');
      expect(r.otp, '334455');

      final r2 = extractor.extract(
          'Your card ending 9021 was charged Rs 99. OTP is 776655.');
      expect(r2.otp, '776655');
    });

    test('txn / reference ids near the number are skipped', () {
      final r = extractor.extract(
          'Rs 999 debited via txn 12345678. OTP 445566 to authorize.');
      expect(r.otp, '445566');
    });

    test('years inside dates are not OTPs', () {
      final r = extractor.extract(
          'Payment due on 12-07-2026. Use OTP 456123 to pay your bill.');
      expect(r.otp, '456123');
    });

    test('helpline numbers are not OTPs', () {
      final r = extractor.extract(
          'For help call 1800111999. Your OTP is 240896.');
      expect(r.otp, '240896');
    });

    test('10-digit phone numbers are never candidates', () {
      final r =
          extractor.extract('Your OTP is 5501. Queries? SMS 9876543210.');
      expect(r.otp, '5501');
    });

    test('order number without OTP keyword yields nothing', () {
      final r =
          extractor.extract('Order no. 45789 has been shipped via Ekart.');
      expect(r.hasOtp, isFalse);
    });
  });

  group('OtpExtractor — amounts', () {
    test('parses "Rs 4500"', () {
      expect(extractor.extract('Rs 4500 debited from A/c XX9').amount, 4500);
    });

    test('parses "Rs 4,500.00" with comma and paise', () {
      expect(
          extractor.extract('Rs 4,500.00 spent on your card.').amount, 4500.0);
    });

    test('parses "Rs.2500" with dot and no space', () {
      expect(extractor.extract('Rs.2500 credited to A/c XX1.').amount, 2500);
    });

    test('parses "INR 1,23,456.78" (Indian grouping)', () {
      expect(
        extractor.extract('INR 1,23,456.78 transferred via NEFT.').amount,
        123456.78,
      );
    });

    test('parses rupee symbol "₹99.50"', () {
      expect(extractor.extract('₹99.50 paid for your recharge.').amount, 99.5);
    });

    test('does not read "offers 4500" as an amount', () {
      expect(extractor.extract('Best offers 4500 stores near you!').amount,
          isNull);
    });

    test('no amount → null', () {
      expect(
          extractor.extract('Your OTP is 123456 for login.').amount, isNull);
    });
  });

  group('OtpExtractor — transaction type', () {
    test('debited → debit', () {
      expect(
        extractor.extract('Rs 100 debited from A/c XX1.').transactionType,
        TransactionType.debit,
      );
    });

    test('credited → credit', () {
      expect(
        extractor.extract('Rs 100 credited to A/c XX1.').transactionType,
        TransactionType.credit,
      );
    });

    test('debit wins over a refund/reversal mention', () {
      expect(
        extractor
            .extract('Rs 4500 debited. OTP for reversal 284761 -SBI')
            .transactionType,
        TransactionType.debit,
      );
    });

    test('refund alone → refund', () {
      expect(
        extractor.extract('Refund of Rs 250 initiated.').transactionType,
        TransactionType.refund,
      );
    });

    test('NEFT/transfer → transfer', () {
      expect(
        extractor
            .extract('INR 5,000 transferred via NEFT to Ravi.')
            .transactionType,
        TransactionType.transfer,
      );
    });

    test('no signal → unknown', () {
      expect(
        extractor.extract('Your OTP is 123456.').transactionType,
        TransactionType.unknown,
      );
    });
  });

  group('OtpExtractor — merchant', () {
    test('extracts "at MERCHANT"', () {
      final r = extractor
          .extract('Rs 2,500.00 spent on your card at AMAZON. OTP 334455.');
      expect(r.merchant, 'AMAZON');
    });

    test('does not extract masked accounts as merchants', () {
      final r = extractor.extract('Rs 100 debited, sent to XX3421.');
      expect(r.merchant, isNull);
    });
  });

  group('OtpExtractor — robustness', () {
    test('empty body', () {
      final r = extractor.extract('');
      expect(r.hasOtp, isFalse);
      expect(r.amount, isNull);
      expect(r.merchant, isNull);
      expect(r.transactionType, TransactionType.unknown);
    });

    test('whitespace-only body', () {
      expect(extractor.extract('   \n\t ').hasOtp, isFalse);
    });

    test('unicode / emoji body does not throw', () {
      final r = extractor.extract('🎉🎉 बधाई हो! आपका OTP 774411 है 🎉');
      expect(r.otp, '774411');
    });
  });
}
