import 'package:otpbridge/domain/models/models.dart';

import 'brand_catalog.dart';
import 'otp_extractor.dart';

/// Output of [CategoryClassifier.classify].
class CategoryResult {
  const CategoryResult({
    required this.category,
    required this.confidence,
    this.brand,
  });

  final OtpCategory category;

  /// 0.0 – 1.0. Brand-backed ≥ 0.9, keyword heuristics 0.5–0.8,
  /// unknown 0.3.
  final double confidence;
  final String? brand;
}

/// Combines the [BrandCatalog] with keyword heuristics to pick the best
/// [OtpCategory] and a calibrated confidence. Fully deterministic and
/// offline.
class CategoryClassifier {
  const CategoryClassifier({BrandCatalog catalog = const BrandCatalog()})
      : _catalog = catalog;

  final BrandCatalog _catalog;

  // Confidence bands.
  static const double _senderBrandConfidence = 0.95;
  static const double _bodyBrandConfidence = 0.9;
  static const double _unknownConfidence = 0.3;

  CategoryResult classify({
    required String sender,
    required String body,
    OtpExtractionResult extraction = OtpExtractionResult.empty,
  }) {
    // 1. Curated brand match — the strongest signal we have.
    final brandMatch = _catalog.lookup(sender: sender, body: body);

    // 1.5 Marketing blasts. Strong promo wording with NO OTP and NO money
    //     movement is a promotion even when the brand is recognised
    //     ("FLAT 60% OFF! Myntra Sale" is an ad, not an e-commerce OTP).
    //     The guards inside guarantee a real OTP or bank/UPI transaction
    //     is never downgraded to promotions.
    final promotional = _classifyPromotion(body, extraction, brandMatch);
    if (promotional != null) return promotional;

    if (brandMatch != null) {
      return CategoryResult(
        category: brandMatch.category,
        confidence: brandMatch.source == BrandMatchSource.sender
            ? _senderBrandConfidence
            : _bodyBrandConfidence,
        brand: brandMatch.brand,
      );
    }

    // 2. Financial signals without a known brand. Money movement is
    //    weighted carefully: an amount plus a transaction verb (or masked
    //    account) is treated as a bank transaction even from an unknown
    //    sender, because mis-forwarding these is the costliest mistake.
    final financial = _classifyFinancial(body, extraction);
    if (financial != null) return financial;

    // 3. Generic keyword heuristics, most specific first.
    final heuristic = _classifyByKeywords(body);
    if (heuristic != null) return heuristic;

    // 4. Nothing matched.
    return const CategoryResult(
      category: OtpCategory.unknown,
      confidence: _unknownConfidence,
    );
  }

  // ------------------------------------------------------ promotions ---

  /// Promotional signals; each regex counts at most once and ≥2 distinct
  /// signals mark the message as marketing.
  static final List<RegExp> _promoSignals = [
    RegExp(r'\d+\s*%\s*(?:off|discount|cashback)'),
    RegExp(r'\bflat\s+(?:rs\.?|inr|₹)?\s*\d+'),
    RegExp(r'\bsale\b'),
    RegExp(r'\boffers?\b'),
    RegExp(r'\bcoupons?\b|\bpromo\s*code\b'),
    RegExp(r'\bdeals?\b'),
    RegExp(r'\bshop\s+now\b|\bbuy\s+now\b|\bhurry\b|\bgrab\s+(?:it|now|yours)\b'),
    RegExp(r'\blimited\s+(?:time|period|stock)\b'),
    RegExp(r'\bcashback\b'),
    RegExp(r'\bbuy\s*1\s*get\b|\bbogo\b'),
    RegExp(r'\bdiscounts?\b'),
    RegExp(r'\bfree\s+(?:delivery|shipping|gift)\b'),
    RegExp(r'\bexclusive\b|\bmega\b|\bbumper\b'),
  ];

  /// Detects purely promotional/marketing SMS. Deliberately conservative:
  /// anything carrying a real OTP or money movement never lands here —
  /// mis-forwarding a transaction OTP costs far more than mis-filing an ad.
  CategoryResult? _classifyPromotion(
    String body,
    OtpExtractionResult extraction,
    BrandMatch? brandMatch,
  ) {
    if (extraction.hasOtp) return null;
    if (extraction.transactionType != TransactionType.unknown) return null;

    final b = body.toLowerCase();
    // An explicit OTP mention (even without an extractable code) is not spam.
    if (RegExp(r'\botp\b|\bone[\s-]?time\s+pass').hasMatch(b)) return null;
    // Recognised financial/investment senders never downgrade to promotions.
    final matchedCategory = brandMatch?.category;
    if (matchedCategory != null &&
        (matchedCategory.isFinancial ||
            matchedCategory == OtpCategory.investment)) {
      return null;
    }

    var signals = 0;
    for (final signal in _promoSignals) {
      if (signal.hasMatch(b)) signals++;
    }
    if (signals < 2) return null;

    // Modest confidence on purpose — promos are low-stakes.
    return CategoryResult(
      category: OtpCategory.promotions,
      confidence: signals >= 3 ? 0.65 : 0.55,
      brand: brandMatch?.brand,
    );
  }

  // ------------------------------------------------------- financial ---

  CategoryResult? _classifyFinancial(
      String body, OtpExtractionResult extraction) {
    final b = body.toLowerCase();
    bool has(String pattern) => RegExp(pattern).hasMatch(b);

    final hasCard = has(r'\b(?:credit|debit)\s*card\b');
    final hasUpi = has(r'\bupi\b|\bvpa\b');
    final hasTxnVerb = extraction.transactionType != TransactionType.unknown ||
        has(r'\bcredited\b|\bdebited\b|\btxn\b|\btransaction\b|'
            r'\btransfer(?:red)?\b|\bwithdraw(?:al|n)?\b');
    final hasAccount = has(r'\ba/c\b|\bacct\b|\baccount\b');
    final hasBankWord = has(r'\bbank(?:ing)?\b|\bnet\s*banking\b');
    final hasAmount = extraction.amount != null;

    if (hasCard && (hasTxnVerb || hasAmount)) {
      return CategoryResult(
        category: has(r'\bcredit\s*card\b')
            ? OtpCategory.creditCard
            : OtpCategory.debitCard,
        confidence: 0.75,
      );
    }
    if (hasUpi && (hasTxnVerb || hasAmount)) {
      return const CategoryResult(category: OtpCategory.upi, confidence: 0.75);
    }
    if (hasTxnVerb && (hasAmount || hasAccount)) {
      return const CategoryResult(
          category: OtpCategory.bankingTransaction, confidence: 0.75);
    }
    if (hasBankWord && has(r'\blog\s*[io]n\b|\blogin\b|\blogon\b')) {
      return const CategoryResult(
          category: OtpCategory.bankingLogin, confidence: 0.7);
    }
    // Weaker: money words alone.
    if (hasAmount && (hasAccount || hasBankWord)) {
      return const CategoryResult(
          category: OtpCategory.bankingTransaction, confidence: 0.6);
    }
    return null;
  }

  // -------------------------------------------------------- keywords ---

  /// Heuristic keyword table, evaluated top-to-bottom (most specific
  /// categories first). Confidence: 0.5–0.8 per the number/strength of
  /// signals.
  CategoryResult? _classifyByKeywords(String body) {
    final b = body.toLowerCase();
    bool has(String pattern) => RegExp(pattern).hasMatch(b);

    if (has(r'\b(?:password|pin)\s+reset\b|\breset\s+(?:your\s+)?password\b|'
        r'\bforgot\s+password\b')) {
      return const CategoryResult(
          category: OtpCategory.passwordReset, confidence: 0.7);
    }
    // Tax — must outrank the broader government bucket ("PAN card" and
    // "ITR refund" are tax artefacts, not generic govt services).
    if (has(r'\bincome\s*tax\b|\bitr\b|\be-?filing\b|\btds\b|\bgstin\b|'
        r'\bgstn\b|\bgstr-?\d\b|'
        r'\bgst\s+(?:return|filing|portal|registration|payment|refund|no|number)\b|'
        r'\bchallan\b|\btax\s+refund\b|\bassessment\s+year\b|\bay\s*20\d{2}\b|'
        r'\bpan\s+(?:card|number|application|verification)\b|'
        r'\blink\s+(?:your\s+)?pan\b')) {
      return const CategoryResult(category: OtpCategory.tax, confidence: 0.65);
    }
    if (has(r'\bmutual\s+funds?\b|\bsip\b|\bnav\b|\bfolio\b|\bdemat\b|'
        r'\bportfolio\b|\bunits?\s+allott?ed\b|'
        r'\bshares?\s+(?:of|allotted|credited|bought|sold)\b|\bequity\b|'
        r'\bipo\b|\bstock\s+market\b')) {
      return const CategoryResult(
          category: OtpCategory.investment, confidence: 0.6);
    }
    if (has(r'\bpolicy\b|\bpremiums?\s+(?:due|paid|payment|of|amount|receipt)\b|'
        r'\bsum\s+assured\b|\binsurance\b|'
        r'\bclaim\s+(?:no|number|id|amount|settled|registered|approved|intimation)\b')) {
      return const CategoryResult(
          category: OtpCategory.insurance, confidence: 0.6);
    }
    if (has(r'\baadhaar\b|\baadhar\b|\bgovt\b|\bgovernment\b|'
        r'\bvoter\s+id\b|\bpassport\b')) {
      return const CategoryResult(
          category: OtpCategory.government, confidence: 0.65);
    }
    if (has(r'\bdelivery\s+(?:otp|code|pin)\b|\bdelivered\b|\bcourier\b|'
        r'\bshipment\b|\bparcel\b|\bout\s+for\s+delivery\b')) {
      return const CategoryResult(
          category: OtpCategory.courier, confidence: 0.65);
    }
    // Recharge confirmations (prepaid/DTH) vs the telecom account itself.
    if (has(r'\brecharge\b|\bplan\s+activat\w*\b|\bvalidity\b|'
        r'\bdata\s+pack\b|\btalk\s*time\b|\btop[\s-]?up\b|\bdth\b')) {
      return const CategoryResult(
          category: OtpCategory.recharge, confidence: 0.6);
    }
    if (has(r'\bprepaid\s+plan\b|\bpostpaid\b|\bsim\b')) {
      return const CategoryResult(
          category: OtpCategory.telecom, confidence: 0.6);
    }
    if (has(r'\belectricity\s+bill\b|\bgas\s+booking\b|\bwater\s+bill\b|'
        r'\bbill\s+payment\b|\bmeter\b')) {
      return const CategoryResult(
          category: OtpCategory.utilityBills, confidence: 0.6);
    }
    if (has(r'\bcab\b|\bride\b|\bdriver\b|\btrip\s+(?:otp|code|pin)\b')) {
      return const CategoryResult(
          category: OtpCategory.rideBooking, confidence: 0.6);
    }
    if (has(r'\bflight\b|\btrain\b|\bpnr\b|\bbooking\s+(?:id|confirmed)\b|'
        r'\bbus\s+ticket\b')) {
      return const CategoryResult(
          category: OtpCategory.travel, confidence: 0.6);
    }
    if (has(r'\bhotel\b|\bcheck-?in\b|\broom\s+booking\b')) {
      return const CategoryResult(
          category: OtpCategory.hotel, confidence: 0.55);
    }
    if (has(r'\bfood\s+order\b|\brestaurant\b|\bmeal\b')) {
      return const CategoryResult(
          category: OtpCategory.foodDelivery, confidence: 0.55);
    }
    if (has(r'\bgrocery\b|\bgroceries\b')) {
      return const CategoryResult(
          category: OtpCategory.grocery, confidence: 0.55);
    }
    if (has(r'\bappointment\b|\bdoctor\b|\blab\s+test\b|\bpharmacy\b|'
        r'\bmedicine\b')) {
      return const CategoryResult(
          category: OtpCategory.healthcare, confidence: 0.55);
    }
    if (has(r'\bregist(?:er|ration)\b|\bsign\s*up\b|\bcreate\s+(?:your\s+)?'
        r'account\b|\bnew\s+account\b|\bwelcome\b')) {
      return const CategoryResult(
          category: OtpCategory.registration, confidence: 0.6);
    }
    if (has(r'\blogin\b|\blog\s*in\b|\bsign\s*in\b|\blogon\b')) {
      return const CategoryResult(
          category: OtpCategory.login, confidence: 0.6);
    }
    if (has(r'\bverify\b|\bverification\b|\bauthenticate\b|\bconfirm\s+your\b')) {
      // A generic verification code — account access of some kind.
      return const CategoryResult(
          category: OtpCategory.login, confidence: 0.5);
    }
    if (has(r'\border\b|\bcart\b|\bpurchase\b|\bshopping\b')) {
      return const CategoryResult(
          category: OtpCategory.ecommerce, confidence: 0.5);
    }
    return null;
  }
}
