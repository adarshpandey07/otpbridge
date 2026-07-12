import 'package:flutter/material.dart';

/// Risk tier drives default handling: high-risk OTPs require manual
/// approval unless a rule explicitly allows them.
enum RiskTier { standard, elevated, high }

/// Every category the classifier can emit.
enum OtpCategory {
  grocery('Grocery', Icons.local_grocery_store_outlined, RiskTier.standard),
  ecommerce('E-commerce', Icons.shopping_bag_outlined, RiskTier.standard),
  bankingLogin('Banking Login', Icons.account_balance_outlined, RiskTier.elevated),
  bankingTransaction(
      'Bank Transaction', Icons.currency_rupee_rounded, RiskTier.high),
  upi('UPI', Icons.qr_code_rounded, RiskTier.high),
  creditCard('Credit Card', Icons.credit_card_outlined, RiskTier.high),
  debitCard('Debit Card', Icons.credit_card_outlined, RiskTier.high),
  registration('Registration', Icons.person_add_alt_outlined, RiskTier.standard),
  login('Login', Icons.login_rounded, RiskTier.elevated),
  passwordReset('Password Reset', Icons.lock_reset_rounded, RiskTier.elevated),
  courier('Courier / Delivery', Icons.local_shipping_outlined, RiskTier.standard),
  foodDelivery('Food Delivery', Icons.restaurant_outlined, RiskTier.standard),
  rideBooking('Ride Booking', Icons.directions_car_outlined, RiskTier.standard),
  travel('Travel', Icons.flight_outlined, RiskTier.standard),
  hotel('Hotel', Icons.hotel_outlined, RiskTier.standard),
  utilityBills('Utility Bills', Icons.bolt_outlined, RiskTier.standard),
  government('Government', Icons.account_balance_wallet_outlined, RiskTier.elevated),
  telecom('Telecom', Icons.sim_card_outlined, RiskTier.standard),
  recharge('Recharge', Icons.phonelink_ring_outlined, RiskTier.standard),
  healthcare('Healthcare', Icons.medical_services_outlined, RiskTier.standard),
  insurance('Insurance', Icons.health_and_safety_outlined, RiskTier.elevated),
  tax('Tax', Icons.receipt_long_outlined, RiskTier.elevated),
  investment('Investments', Icons.trending_up_rounded, RiskTier.high),
  entertainment('Entertainment', Icons.movie_outlined, RiskTier.standard),
  promotions('Promotions', Icons.local_offer_outlined, RiskTier.standard),
  work('Work', Icons.work_outline_rounded, RiskTier.standard),
  personal('Personal', Icons.person_outline_rounded, RiskTier.standard),
  unknown('Unknown', Icons.help_outline_rounded, RiskTier.elevated);

  const OtpCategory(this.label, this.icon, this.risk);

  final String label;
  final IconData icon;
  final RiskTier risk;

  bool get isFinancial => switch (this) {
        bankingLogin ||
        bankingTransaction ||
        upi ||
        creditCard ||
        debitCard =>
          true,
        _ => false,
      };

  static OtpCategory fromId(String? id) => OtpCategory.values.firstWhere(
        (c) => c.name == id,
        orElse: () => OtpCategory.unknown,
      );

  CategoryGroup get group => CategoryGroup.of(this);
}

/// High-level, human-friendly buckets shown in the rule wizard's first step.
/// Each maps to a set of detailed [OtpCategory] values so the user picks
/// "Shopping" instead of choosing ecommerce + courier by hand.
enum CategoryGroup {
  shopping('Shopping', Icons.shopping_bag_outlined,
      {OtpCategory.ecommerce, OtpCategory.courier}),
  grocery('Grocery', Icons.local_grocery_store_outlined,
      {OtpCategory.grocery}),
  food('Food', Icons.restaurant_outlined, {OtpCategory.foodDelivery}),
  banking('Banking', Icons.account_balance_outlined,
      {OtpCategory.bankingLogin, OtpCategory.bankingTransaction}),
  finance('Finance', Icons.currency_rupee_rounded, {
    OtpCategory.upi,
    OtpCategory.creditCard,
    OtpCategory.debitCard,
    OtpCategory.investment,
  }),
  bills('Bills & Recharge', Icons.bolt_outlined,
      {OtpCategory.utilityBills, OtpCategory.telecom, OtpCategory.recharge}),
  travel('Travel', Icons.flight_outlined,
      {OtpCategory.travel, OtpCategory.hotel, OtpCategory.rideBooking}),
  health('Health', Icons.medical_services_outlined,
      {OtpCategory.healthcare, OtpCategory.insurance}),
  government('Government & Tax', Icons.account_balance_wallet_outlined,
      {OtpCategory.government, OtpCategory.tax}),
  accounts('Logins & OTPs', Icons.login_rounded, {
    OtpCategory.login,
    OtpCategory.registration,
    OtpCategory.passwordReset,
  }),
  entertainment('Entertainment', Icons.movie_outlined,
      {OtpCategory.entertainment}),
  promotions('Promotions', Icons.local_offer_outlined,
      {OtpCategory.promotions}),
  other('Other', Icons.apps_outlined,
      {OtpCategory.work, OtpCategory.personal, OtpCategory.unknown});

  const CategoryGroup(this.label, this.icon, this.categories);

  final String label;
  final IconData icon;
  final Set<OtpCategory> categories;

  static CategoryGroup of(OtpCategory category) => CategoryGroup.values
      .firstWhere((g) => g.categories.contains(category),
          orElse: () => CategoryGroup.other);
}
