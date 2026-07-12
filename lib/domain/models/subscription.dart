import 'package:equatable/equatable.dart';

enum SubscriptionTier { free, premium }

/// Entitlements per tier. Kept in one place so pricing/limits can change
/// without touching feature code.
class TierLimits extends Equatable {
  const TierLimits({
    required this.monthlyForwards,
    required this.maxRecipients,
    required this.maxRules,
    required this.canCustomizeBankingCap,
    required this.advancedSchedules,
  });

  final int monthlyForwards; // -1 = unlimited
  final int maxRecipients; // -1 = unlimited
  final int maxRules; // -1 = unlimited
  final bool canCustomizeBankingCap;
  final bool advancedSchedules;

  static const TierLimits free = TierLimits(
    monthlyForwards: 50,
    maxRecipients: 1,
    maxRules: 3,
    canCustomizeBankingCap: false,
    advancedSchedules: false,
  );

  static const TierLimits premium = TierLimits(
    monthlyForwards: -1,
    maxRecipients: -1,
    maxRules: -1,
    canCustomizeBankingCap: true,
    advancedSchedules: true,
  );

  @override
  List<Object?> get props => [
        monthlyForwards, maxRecipients, maxRules,
        canCustomizeBankingCap, advancedSchedules,
      ];
}

class SubscriptionState extends Equatable {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.forwardsUsed = 0,
    required this.periodStart,
    this.expiresAt,
  });

  final SubscriptionTier tier;
  final int forwardsUsed;

  /// Start of the current usage month (forwardsUsed resets each period).
  final DateTime periodStart;
  final DateTime? expiresAt;

  TierLimits get limits =>
      tier == SubscriptionTier.premium ? TierLimits.premium : TierLimits.free;

  bool get hasForwardsLeft =>
      limits.monthlyForwards < 0 || forwardsUsed < limits.monthlyForwards;

  int get forwardsRemaining => limits.monthlyForwards < 0
      ? -1
      : (limits.monthlyForwards - forwardsUsed).clamp(0, 1 << 31);

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    int? forwardsUsed,
    DateTime? periodStart,
    DateTime? expiresAt,
  }) =>
      SubscriptionState(
        tier: tier ?? this.tier,
        forwardsUsed: forwardsUsed ?? this.forwardsUsed,
        periodStart: periodStart ?? this.periodStart,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'forwardsUsed': forwardsUsed,
        'periodStart': periodStart.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory SubscriptionState.fromJson(Map<String, dynamic> json) =>
      SubscriptionState(
        tier: SubscriptionTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => SubscriptionTier.free,
        ),
        forwardsUsed: json['forwardsUsed'] as int? ?? 0,
        periodStart: DateTime.tryParse(json['periodStart'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [tier, forwardsUsed, periodStart, expiresAt];
}
