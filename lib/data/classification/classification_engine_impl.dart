import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/services/service_contracts.dart';

import 'category_classifier.dart';
import 'otp_extractor.dart';

/// Default hybrid, offline-first implementation of [ClassificationEngine].
///
/// Pipeline (fully deterministic, zero network):
///   raw SMS → [OtpExtractor] (OTP / amount / merchant / txn type)
///           → [CategoryClassifier] (brand catalog + keyword heuristics)
///           → [SmsClassification] with engine = 'rules'.
///
/// ## ML / cloud seam
/// [classify] is the async upgrade point. A future local model
/// (ONNX Runtime / TFLite text classifier) or an opt-in cloud call slots in
/// there: run the rules result first, and only when its confidence is below
/// a threshold (e.g. < 0.6) consult the model, then return whichever result
/// carries the higher confidence with `engine: 'local-ml'` / `'cloud'`.
/// [classifySync] must stay rules-only — it backs code paths that cannot
/// await (broadcast receivers, isolate-free hot paths).
class DefaultClassificationEngine implements ClassificationEngine {
  /// No required arguments — providers construct this as
  /// `DefaultClassificationEngine()`.
  DefaultClassificationEngine({
    OtpExtractor extractor = const OtpExtractor(),
    CategoryClassifier classifier = const CategoryClassifier(),
  })  : _extractor = extractor,
        _classifier = classifier;

  final OtpExtractor _extractor;
  final CategoryClassifier _classifier;

  static const String _engineId = 'rules';

  @override
  Future<SmsClassification> classify(IncomingSms sms) async {
    // Seam: when a local model / cloud classifier is added, consult it here
    // for low-confidence rule results. Today: rules only.
    return classifySync(sms);
  }

  @override
  SmsClassification classifySync(IncomingSms sms) {
    try {
      final extraction = _extractor.extract(sms.body);
      final result = _classifier.classify(
        sender: sms.sender,
        body: sms.body,
        extraction: extraction,
      );
      return SmsClassification(
        sms: sms,
        category: result.category,
        confidence: result.confidence.clamp(0.0, 1.0).toDouble(),
        otp: extraction.otp,
        brand: result.brand,
        amount: extraction.amount,
        merchant: extraction.merchant,
        transactionType: extraction.transactionType,
        engine: _engineId,
      );
    } catch (_) {
      // Contract: never throw. Fall back to unknown / low confidence.
      return SmsClassification(
        sms: sms,
        category: OtpCategory.unknown,
        confidence: 0.1,
        engine: _engineId,
      );
    }
  }
}
