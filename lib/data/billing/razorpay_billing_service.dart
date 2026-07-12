import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/config/app_config.dart';
import '../../domain/services/billing_service.dart';

/// Razorpay-backed [BillingService].
///
/// When [AppConfig.razorpayKeyId] is set, this opens the real Razorpay
/// checkout. When it's empty (no key configured yet), it runs a **demo**
/// checkout that simulates a successful payment after a short delay, so the
/// upgrade → activate flow is fully testable end-to-end without credentials.
/// Swap in the key via `--dart-define=RAZORPAY_KEY_ID=...` for production.
class RazorpayBillingService implements BillingService {
  RazorpayBillingService() {
    if (AppConfig.hasRazorpayKey) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }
  }

  Razorpay? _razorpay;
  Completer<BillingResult>? _pending;

  @override
  bool get isConfigured => AppConfig.hasRazorpayKey;

  @override
  Future<BillingResult> checkout({
    required PremiumPlan plan,
    required String userName,
    String? email,
    String? phone,
  }) async {
    // Demo mode — no key configured. Simulate a real gateway round-trip.
    if (!AppConfig.hasRazorpayKey || _razorpay == null) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return BillingResult(
        status: BillingStatus.success,
        paymentId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Demo payment (no gateway key configured)',
      );
    }

    // Guard against concurrent checkouts.
    if (_pending != null && !_pending!.isCompleted) {
      return const BillingResult(
          status: BillingStatus.failed, message: 'A checkout is already open');
    }
    _pending = Completer<BillingResult>();

    try {
      _razorpay!.open({
        'key': AppConfig.razorpayKeyId,
        'amount': plan.priceInPaise, // in paise
        'currency': 'INR',
        'name': AppConfig.merchantName,
        'description': plan.name,
        'prefill': {
          if (email != null) 'email': email,
          if (phone != null) 'contact': phone,
          'name': userName,
        },
        'theme': {'color': '#4F46E5'},
      });
    } catch (e) {
      _pending!.complete(
          BillingResult(status: BillingStatus.failed, message: e.toString()));
    }

    return _pending!.future;
  }

  void _onSuccess(PaymentSuccessResponse r) {
    _complete(BillingResult(
      status: BillingStatus.success,
      paymentId: r.paymentId,
      orderId: r.orderId,
      signature: r.signature,
    ));
  }

  void _onError(PaymentFailureResponse r) {
    // Razorpay code 2 == payment cancelled by user.
    final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
    _complete(BillingResult(
      status: cancelled ? BillingStatus.cancelled : BillingStatus.failed,
      message: r.message ?? (cancelled ? 'Payment cancelled' : 'Payment failed'),
    ));
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Wallet selected; final result still arrives via success/error.
  }

  void _complete(BillingResult result) {
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(result);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
