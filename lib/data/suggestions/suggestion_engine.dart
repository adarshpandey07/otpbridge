import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:uuid/uuid.dart';

/// Turns inbox insight ([DetectedService]s) into proactive [AiSuggestion]s:
/// "You've received 12 messages from Amazon — forward them automatically?"
///
/// Pure and deterministic: no I/O, no direct `DateTime.now()` (timestamps
/// come from the injected clock), no state. The only non-determinism is the
/// freshly minted rule/suggestion ids.
class SuggestionEngine {
  const SuggestionEngine();

  /// Propose up to [max] rules for the services the user actually receives
  /// messages from, most-messaged first.
  ///
  /// A service is skipped when an existing *enabled* rule already covers its
  /// brand/category. High-risk services (banking, cards, UPI, investments)
  /// propose [RuleAction.requireApproval] instead of auto-forwarding, and
  /// the suggestion body says so. When [recipients] exist the first one is
  /// pre-filled; otherwise `recipientIds` stays empty and the UI asks.
  List<AiSuggestion> generate({
    required List<DetectedService> detectedServices,
    required List<ForwardRule> existingRules,
    required List<Recipient> recipients,
    DateTime Function() clock = DateTime.now,
    int max = 4,
  }) {
    if (max <= 0 || detectedServices.isEmpty) return const [];

    final now = clock();
    final enabledRules =
        existingRules.where((r) => r.enabled).toList(growable: false);

    final candidates = detectedServices
        .where((s) => s.messageCount > 0)
        .where((s) => !enabledRules.any((r) => _covers(r, s)))
        .toList()
      ..sort((a, b) {
        final byCount = b.messageCount.compareTo(a.messageCount);
        if (byCount != 0) return byCount;
        final byRecency = b.lastSeen.compareTo(a.lastSeen);
        if (byRecency != 0) return byRecency;
        return a.brand.compareTo(b.brand); // stable tie-break
      });

    final suggestions = <AiSuggestion>[];
    final seenBrands = <String>{};
    for (final service in candidates) {
      if (suggestions.length >= max) break;
      if (!seenBrands.add(service.brand.toLowerCase())) continue;
      suggestions.add(_suggestionFor(service, recipients, now));
    }
    return suggestions;
  }

  /// Whether an (enabled) rule already handles messages from [service]:
  /// its brand filter admits the brand AND its category filter admits the
  /// category — an empty filter matches anything, per [ForwardRule] semantics.
  static bool _covers(ForwardRule rule, DetectedService service) {
    final brandCovered = rule.brands.isEmpty ||
        rule.brands
            .any((b) => b.toLowerCase() == service.brand.toLowerCase());
    final categoryCovered =
        rule.categories.isEmpty || rule.categories.contains(service.category);
    return brandCovered && categoryCovered;
  }

  /// Banking/card/UPI/investment OTPs are too sensitive to auto-forward.
  static bool _isHighRisk(OtpCategory category) =>
      category.risk == RiskTier.high || category.isFinancial;

  AiSuggestion _suggestionFor(
    DetectedService service,
    List<Recipient> recipients,
    DateTime now,
  ) {
    const uuid = Uuid();
    final highRisk = _isHighRisk(service.category);
    final action = highRisk ? RuleAction.requireApproval : RuleAction.forward;
    final recipientIds =
        recipients.isEmpty ? const <String>[] : [recipients.first.id];

    final proposedRule = ForwardRule(
      id: uuid.v4(),
      name: highRisk
          ? 'Review ${service.brand} OTPs'
          : 'Forward ${service.brand} updates',
      categories: {service.category},
      brands: [service.brand],
      action: action,
      recipientIds: recipientIds,
      createdAt: now,
    );

    final count = service.messageCount;
    final messages = count == 1 ? '1 message' : '$count messages';
    final String title;
    final String body;
    if (highRisk) {
      title = 'Review ${service.brand} OTPs?';
      body = "You've received $messages from ${service.brand}. "
          '${service.category.label} OTPs are sensitive, so instead of '
          'auto-forwarding we suggest holding each one for your approval. '
          'Create this rule?';
    } else {
      title = 'Forward ${service.brand} updates?';
      body = recipients.isEmpty
          ? "You've received $messages from ${service.brand}. "
              'Create a rule to forward them?'
          : "You've received $messages from ${service.brand}. "
              'Create a rule to forward them to ${recipients.first.name}?';
    }

    return AiSuggestion(
      id: uuid.v4(),
      title: title,
      body: body,
      proposedRule: proposedRule,
      createdAt: now,
    );
  }
}

/// Live suggestions derived from the inbox: detected services minus anything
/// an enabled rule already covers, capped and prioritised by message volume.
final smartSuggestionsProvider = FutureProvider<List<AiSuggestion>>((ref) async {
  final detected = await ref.watch(detectedServicesProvider.future);
  final rules = ref.watch(rulesProvider).valueOrNull ?? const [];
  final recipients = ref.watch(recipientsProvider).valueOrNull ?? const [];
  return const SuggestionEngine().generate(
    detectedServices: detected,
    existingRules: rules,
    recipients: recipients,
  );
});
