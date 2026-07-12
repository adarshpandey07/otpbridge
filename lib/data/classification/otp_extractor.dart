import 'package:otpbridge/domain/models/models.dart';

/// Result of running [OtpExtractor.extract] over a raw SMS body.
///
/// A small immutable struct; every field is best-effort and may be null
/// when the corresponding signal was not found.
class OtpExtractionResult {
  const OtpExtractionResult({
    this.otp,
    this.amount,
    this.merchant,
    this.transactionType = TransactionType.unknown,
    this.hasOtpKeyword = false,
    this.candidateCount = 0,
  });

  static const OtpExtractionResult empty = OtpExtractionResult();

  /// The extracted one-time password (4–8 digits), or null.
  final String? otp;

  /// Monetary amount in rupees (may carry paise), or null.
  final double? amount;

  /// Best-effort merchant/payee name, or null.
  final String? merchant;

  /// Detected transaction direction, [TransactionType.unknown] when absent.
  final TransactionType transactionType;

  /// Whether the body contained any OTP-ish keyword at all
  /// ("OTP", "code", "one time password", "verification code", "PIN", …).
  final bool hasOtpKeyword;

  /// Number of surviving numeric candidates considered for the OTP slot.
  final int candidateCount;

  bool get hasOtp => otp != null && otp!.isNotEmpty;
}

/// Deterministic, offline regex-based extractor for Indian SMS formats.
///
/// Responsibilities:
///  * find the OTP code (4–8 digits) while rejecting look-alikes:
///    amounts (`Rs 4,500.00`), masked accounts (`XX3421`), reference /
///    order / transaction numbers, card last-4, phone numbers, years;
///  * parse amounts written as `Rs.`, `Rs`, `INR`, `₹`, `MRP`,
///    with Indian comma grouping and optional paise;
///  * detect the transaction type (debit / credit / transfer / refund /
///    payment);
///  * pull a best-effort merchant name.
class OtpExtractor {
  const OtpExtractor();

  // ---------------------------------------------------------------------
  // Keywords that mark a message as carrying a one-time code. Without at
  // least one of these in the body we never report an OTP — a bare number
  // ("Ref: 998812") must not be forwardable.
  // ---------------------------------------------------------------------
  static final RegExp _otpKeyword = RegExp(
    r'\b(?:otp|one[\s-]?time\s+(?:password|passcode|pin|code)|'
    r'verification\s+(?:code|pin)|verify|verifying|'
    r'security\s+code|auth(?:entication|orization)?\s+code|'
    r'login\s+code|confirmation\s+code|activation\s+code|'
    r'passcode|\bpin\b|code)\b',
    caseSensitive: false,
  );

  /// Standalone run of 4–8 digits (never a slice of a longer number, so
  /// 10-digit phone numbers and 16-digit cards are excluded for free).
  static final RegExp _candidate = RegExp(r'(?<!\d)(\d{4,8})(?!\d)');

  /// `123-456` / `123 456` style split OTPs — treated as one 6-digit code.
  static final RegExp _splitCandidate =
      RegExp(r'(?<!\d)(\d{3})[-\s](\d{3})(?!\d)');

  // Currency amount: prefix form (`Rs 4,500.00`, `INR 250`, `₹99`).
  static final RegExp _amountPrefix = RegExp(
    r'(?:\b(?:rs\.?|inr|mrp)|₹)\s*\.?\s*'
    r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Currency amount: suffix form (`4500 INR`, `250 rupees`).
  static final RegExp _amountSuffix = RegExp(
    r'(?<!\d)(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)'
    r'\s*(?:rs\b|inr\b|rupees\b|/-)',
    caseSensitive: false,
  );

  // Words that, appearing shortly BEFORE a number, mark it as a reference
  // and never an OTP.
  static final RegExp _refContext = RegExp(
    r'(?:\bref(?:erence)?\s*(?:no|num|number|id)?\b|'
    r'\border\s*(?:no|num|number|id)?\b|'
    r'\btxn\s*(?:no|id)?\b|\btransaction\s*(?:no|id)?\b|'
    r'\btracking\s*(?:no|id|number)?\b|\bawb\b|\bconsignment\b|'
    r'\binvoice\s*(?:no)?\b|\bbill\s*(?:no)?\b|\bticket\s*(?:no)?\b|'
    r'\bpnr\b|\bcomplaint\s*(?:no)?\b|\brequest\s*(?:no|id)?\b|'
    r'\bapplication\s*(?:no|id)?\b|\baccount\b|\ba/c\b|\bacct\b|'
    r'\bcard\s+(?:no\.?\s+)?(?:ending|ending\s+in|xx)\b|\bending\s+(?:in\s+)?)'
    r'[\s:#.\-]*$',
    caseSensitive: false,
  );

  /// Run the full extraction over [body].
  OtpExtractionResult extract(String body) {
    if (body.trim().isEmpty) return OtpExtractionResult.empty;

    final amount = _extractAmount(body);
    final transactionType = _extractTransactionType(body);
    final merchant = _extractMerchant(body);
    final hasKeyword = _otpKeyword.hasMatch(body);

    String? otp;
    var candidateCount = 0;
    if (hasKeyword) {
      final picked = _pickOtp(body);
      otp = picked.$1;
      candidateCount = picked.$2;
    }

    return OtpExtractionResult(
      otp: otp,
      amount: amount,
      merchant: merchant,
      transactionType: transactionType,
      hasOtpKeyword: hasKeyword,
      candidateCount: candidateCount,
    );
  }

  // -------------------------------------------------------------- OTP ---

  (String?, int) _pickOtp(String body) {
    final keywordSpans = _otpKeyword
        .allMatches(body)
        .map((m) => (m.start, m.end))
        .toList(growable: false);
    if (keywordSpans.isEmpty) return (null, 0);

    final candidates = <_OtpCandidate>[];

    void addCandidate(String digits, int start, int end) {
      if (!_isPlausibleOtp(body, digits, start, end)) return;
      var best = 1 << 30;
      for (final (ks, ke) in keywordSpans) {
        final d = start >= ke
            ? start - ke
            : (end <= ks ? ks - end : 0);
        if (d < best) best = d;
      }
      candidates.add(_OtpCandidate(digits, start, best));
    }

    // Split codes first ("123 456" / "123-456") so their halves don't get
    // double-counted; remember covered ranges.
    final covered = <(int, int)>[];
    for (final m in _splitCandidate.allMatches(body)) {
      // Only treat as split OTP when hugging a keyword closely; otherwise
      // "123 456" is more likely two unrelated numbers.
      final digits = '${m.group(1)!}${m.group(2)!}';
      final nearKeyword = keywordSpans.any((s) =>
          (m.start - s.$2).abs() <= 12 || (s.$1 - m.end).abs() <= 12);
      if (nearKeyword) {
        addCandidate(digits, m.start, m.end);
        covered.add((m.start, m.end));
      }
    }

    for (final m in _candidate.allMatches(body)) {
      final insideCovered =
          covered.any((c) => m.start >= c.$1 && m.end <= c.$2);
      if (insideCovered) continue;
      addCandidate(m.group(1)!, m.start, m.end);
    }

    if (candidates.isEmpty) return (null, 0);

    candidates.sort((a, b) {
      // 1. closest to an OTP keyword wins;
      final byDistance = a.keywordDistance.compareTo(b.keywordDistance);
      if (byDistance != 0) return byDistance;
      // 2. prefer the canonical OTP lengths (6, then 4);
      final byLength =
          _lengthRank(a.digits.length).compareTo(_lengthRank(b.digits.length));
      if (byLength != 0) return byLength;
      // 3. stable: earliest in the message.
      return a.start.compareTo(b.start);
    });

    return (candidates.first.digits, candidates.length);
  }

  static int _lengthRank(int length) => switch (length) {
        6 => 0,
        4 => 1,
        5 => 2,
        8 => 3,
        _ => 4,
      };

  /// Reject candidates that are clearly NOT one-time codes.
  bool _isPlausibleOtp(String body, String digits, int start, int end) {
    final before = body.substring(0, start);
    final tail =
        before.length > 24 ? before.substring(before.length - 24) : before;
    final after =
        body.substring(end, end + 6 > body.length ? body.length : end + 6);

    // Masked account / card fragment: "XX3421", "**1234", "x-3421".
    if (RegExp(r'[Xx*][Xx*\-]?\s?$').hasMatch(before)) return false;

    // Currency amount: "Rs 4500", "INR4500", "₹ 4500", or "4500/-", "4500 INR".
    if (RegExp(r'(?:\b(?:rs\.?|inr|mrp)|₹)\s*\.?\s*$', caseSensitive: false)
        .hasMatch(tail)) {
      return false;
    }
    if (RegExp(r'^\s*(?:/-|rs\b|inr\b|rupees\b)', caseSensitive: false)
        .hasMatch(after)) {
      return false;
    }
    // Decimal fragment of an amount ("4500.00" → skip the "00"/whole part).
    if (before.endsWith('.') && RegExp(r'\d\.$').hasMatch(before)) {
      return false;
    }
    if (RegExp(r'^\.\d').hasMatch(after)) return false;
    // Part of a comma-grouped amount ("4,500").
    if (RegExp(r'\d,$').hasMatch(before) ||
        RegExp(r'^,\d').hasMatch(after)) {
      return false;
    }

    // Reference / order / txn / tracking / account context just before.
    if (_refContext.hasMatch(tail)) return false;

    // Phone-number context: "+91 98765..." never matches (10+ digits), but
    // "call 1800..." short-codes should not be OTPs either.
    if (RegExp(r'(?:call|dial|sms|helpline|toll\s*free)[\s:.-]*$',
            caseSensitive: false)
        .hasMatch(tail)) {
      return false;
    }

    // Years inside dates ("12/07/2026", "2026-07-12") — a digit must sit on
    // the far side of the separator so "OTP is 5501." isn't caught.
    if (digits.length == 4 &&
        (RegExp(r'\d[/\-.]$').hasMatch(before) ||
            RegExp(r'^[/\-.]\d').hasMatch(after))) {
      return false;
    }

    return true;
  }

  // ----------------------------------------------------------- amount ---

  double? _extractAmount(String body) {
    final m = _amountPrefix.firstMatch(body) ?? _amountSuffix.firstMatch(body);
    if (m == null) return null;
    final raw = m.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  // ------------------------------------------------- transaction type ---

  TransactionType _extractTransactionType(String body) {
    final b = body.toLowerCase();
    bool has(String pattern) =>
        RegExp(pattern, caseSensitive: false).hasMatch(b);

    if (has(r'\brefund(?:ed)?\b|\brevers(?:al|ed)\b')) {
      // A refund mention alongside an explicit debit still reads as debit.
      if (has(r'\bdebited\b|\bspent\b|\bwithdrawn\b')) {
        return TransactionType.debit;
      }
      return TransactionType.refund;
    }
    if (has(r'\bdebited\b|\bdebit\s+of\b|\bspent\b|\bwithdrawn\b|'
        r'\bpurchase\s+of\b|\bcharged\b')) {
      return TransactionType.debit;
    }
    if (has(r'\bcredited\b|\bcredit\s+of\b|\breceived\b|\bdeposited\b')) {
      return TransactionType.credit;
    }
    if (has(r'\btransfer(?:red)?\b|\bimps\b|\bneft\b|\brtgs\b')) {
      return TransactionType.transfer;
    }
    if (has(r'\bpayment\b|\bpaid\b|\bpay\s+of\b|\bbill\s+pay\b')) {
      return TransactionType.payment;
    }
    return TransactionType.unknown;
  }

  // ---------------------------------------------------------- merchant ---

  /// Tokens that regularly follow a merchant name but are never part of it.
  static const Set<String> _merchantStopwords = {
    'OTP', 'UPI', 'RS', 'INR', 'REF', 'ON', 'VIA', 'USING', 'DATED', 'PIN',
    'CODE', 'TXN', 'INFO', 'AVL', 'BAL', 'A/C', 'AC',
  };

  String? _extractMerchant(String body) {
    // "at MERCHANT", "to MERCHANT", "towards MERCHANT" — merchant names are
    // usually capitalised or ALL-CAPS tokens after the preposition.
    final m = RegExp(
      r'\b(?:at|to|towards)\s+([A-Z][A-Za-z0-9&\x27_-]*'
      r'(?:\s+[A-Z][A-Za-z0-9&\x27_-]*){0,2})',
    ).firstMatch(body);
    if (m == null) return null;
    // Drop trailing junk tokens that regularly follow the merchant.
    final tokens = m.group(1)!.trim().split(RegExp(r'\s+')).toList();
    while (tokens.isNotEmpty &&
        _merchantStopwords.contains(tokens.last.toUpperCase())) {
      tokens.removeLast();
    }
    if (tokens.isEmpty) return null;
    final name = tokens.join(' ').replaceAll(RegExp(r'[.,;:]+$'), '').trim();
    if (name.length < 2) return null;
    // Avoid grabbing masked accounts ("to XX3421") or pure numbers.
    if (RegExp(r'^[Xx*\d/]+$').hasMatch(name)) return null;
    return name;
  }
}

class _OtpCandidate {
  const _OtpCandidate(this.digits, this.start, this.keywordDistance);

  final String digits;
  final int start;
  final int keywordDistance;
}
