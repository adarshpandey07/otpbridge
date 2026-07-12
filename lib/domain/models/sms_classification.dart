import 'package:equatable/equatable.dart';

import 'incoming_sms.dart';
import 'otp_category.dart';

enum TransactionType { debit, credit, transfer, payment, refund, unknown }

/// Full structured result of the classification pipeline.
class SmsClassification extends Equatable {
  const SmsClassification({
    required this.sms,
    required this.category,
    required this.confidence,
    this.otp,
    this.brand,
    this.amount,
    this.merchant,
    this.transactionType = TransactionType.unknown,
    this.engine = 'rules',
  });

  final IncomingSms sms;
  final OtpCategory category;

  /// 0.0 – 1.0.
  final double confidence;
  final String? otp;
  final String? brand;

  /// Amount in the smallest displayed unit (rupees, may have paise).
  final double? amount;
  final String? merchant;
  final TransactionType transactionType;

  /// Which engine produced this ('rules', 'local-ml', 'cloud').
  final String engine;

  bool get hasOtp => otp != null && otp!.isNotEmpty;

  SmsClassification copyWith({
    OtpCategory? category,
    double? confidence,
    String? otp,
    String? brand,
    double? amount,
    String? merchant,
    TransactionType? transactionType,
    String? engine,
  }) =>
      SmsClassification(
        sms: sms,
        category: category ?? this.category,
        confidence: confidence ?? this.confidence,
        otp: otp ?? this.otp,
        brand: brand ?? this.brand,
        amount: amount ?? this.amount,
        merchant: merchant ?? this.merchant,
        transactionType: transactionType ?? this.transactionType,
        engine: engine ?? this.engine,
      );

  Map<String, dynamic> toJson() => {
        'sms': sms.toJson(),
        'category': category.name,
        'confidence': confidence,
        'otp': otp,
        'brand': brand,
        'amount': amount,
        'merchant': merchant,
        'transactionType': transactionType.name,
        'engine': engine,
      };

  factory SmsClassification.fromJson(Map<String, dynamic> json) =>
      SmsClassification(
        sms: IncomingSms.fromJson(
            Map<String, dynamic>.from(json['sms'] as Map)),
        category: OtpCategory.fromId(json['category'] as String?),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        otp: json['otp'] as String?,
        brand: json['brand'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        merchant: json['merchant'] as String?,
        transactionType: TransactionType.values.firstWhere(
          (t) => t.name == json['transactionType'],
          orElse: () => TransactionType.unknown,
        ),
        engine: json['engine'] as String? ?? 'rules',
      );

  @override
  List<Object?> get props =>
      [sms, category, confidence, otp, brand, amount, merchant, transactionType];
}
