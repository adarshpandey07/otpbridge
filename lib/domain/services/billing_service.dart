import 'package:equatable/equatable.dart';

/// A purchasable plan.
class PremiumPlan extends Equatable {
  const PremiumPlan({
    required this.id,
    required this.name,
    required this.priceInPaise,
    required this.periodLabel,
    required this.durationDays,
  });

  final String id;
  final String name;
  final int priceInPaise; // ₹99 = 9900
  final String periodLabel; // "month"
  final int durationDays;

  String get displayPrice => '₹${(priceInPaise / 100).toStringAsFixed(0)}';

  static const monthly = PremiumPlan(
    id: 'premium_monthly',
    name: 'OTPBridge Premium',
    priceInPaise: 9900,
    periodLabel: 'month',
    durationDays: 30,
  );

  static const yearly = PremiumPlan(
    id: 'premium_yearly',
    name: 'OTPBridge Premium (Annual)',
    priceInPaise: 99900,
    periodLabel: 'year',
    durationDays: 365,
  );

  @override
  List<Object?> get props => [id, priceInPaise, durationDays];
}

enum BillingStatus { success, failed, cancelled, unsupported }

class BillingResult {
  const BillingResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
  });

  final BillingStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;

  bool get isSuccess => status == BillingStatus.success;

  const BillingResult.cancelled()
      : this(status: BillingStatus.cancelled, message: 'Payment cancelled');
  const BillingResult.unsupported()
      : this(
            status: BillingStatus.unsupported,
            message: 'Payments are not available on this platform');
}

/// Payment gateway abstraction. The Razorpay implementation lives in
/// data/billing; a no-op is used on unsupported platforms / tests.
///
/// SECURITY NOTE: in production the payment must be verified server-side
/// (Razorpay order creation + signature verification via an Edge Function)
/// before premium is granted. [BillingResult.signature] carries the value to
/// verify. See docs/BACKEND.md → /functions/v1/verify-purchase.
abstract interface class BillingService {
  /// True when a real gateway key is configured (vs. demo/simulated mode).
  bool get isConfigured;

  /// Launch the checkout UI and complete when the user finishes or aborts.
  Future<BillingResult> checkout({
    required PremiumPlan plan,
    required String userName,
    String? email,
    String? phone,
  });

  void dispose();
}

class NoopBillingService implements BillingService {
  @override
  bool get isConfigured => false;
  @override
  Future<BillingResult> checkout({
    required PremiumPlan plan,
    required String userName,
    String? email,
    String? phone,
  }) async =>
      const BillingResult.unsupported();
  @override
  void dispose() {}
}
