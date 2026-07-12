import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultRecipientId,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.appLockAfterMinutes = 0,
    this.bankingAutoForwardCap = 5000,
    this.highRiskRequiresApproval = true,
    this.approvalTtlMinutes = 5,
    this.maskOtpInNotifications = true,
    this.listeningEnabled = true,
    this.onboardingComplete = false,
    this.languageCode = 'en',
  });

  final ThemeMode themeMode;
  final String? defaultRecipientId;
  final bool appLockEnabled;
  final bool biometricEnabled;

  /// Idle minutes before the app re-locks (0 = lock immediately on background).
  final int appLockAfterMinutes;

  /// Financial OTPs above this amount always require manual approval.
  final double bankingAutoForwardCap;

  /// When true, high-risk categories require approval even if a rule matches.
  final bool highRiskRequiresApproval;
  final int approvalTtlMinutes;

  /// Mask OTP digits in our own notifications (security default: on).
  final bool maskOtpInNotifications;

  /// Master switch for SMS listening.
  final bool listeningEnabled;
  final bool onboardingComplete;
  final String languageCode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultRecipientId,
    bool clearDefaultRecipient = false,
    bool? appLockEnabled,
    bool? biometricEnabled,
    int? appLockAfterMinutes,
    double? bankingAutoForwardCap,
    bool? highRiskRequiresApproval,
    int? approvalTtlMinutes,
    bool? maskOtpInNotifications,
    bool? listeningEnabled,
    bool? onboardingComplete,
    String? languageCode,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultRecipientId: clearDefaultRecipient
            ? null
            : (defaultRecipientId ?? this.defaultRecipientId),
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        appLockAfterMinutes: appLockAfterMinutes ?? this.appLockAfterMinutes,
        bankingAutoForwardCap:
            bankingAutoForwardCap ?? this.bankingAutoForwardCap,
        highRiskRequiresApproval:
            highRiskRequiresApproval ?? this.highRiskRequiresApproval,
        approvalTtlMinutes: approvalTtlMinutes ?? this.approvalTtlMinutes,
        maskOtpInNotifications:
            maskOtpInNotifications ?? this.maskOtpInNotifications,
        listeningEnabled: listeningEnabled ?? this.listeningEnabled,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        languageCode: languageCode ?? this.languageCode,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'defaultRecipientId': defaultRecipientId,
        'appLockEnabled': appLockEnabled,
        'biometricEnabled': biometricEnabled,
        'appLockAfterMinutes': appLockAfterMinutes,
        'bankingAutoForwardCap': bankingAutoForwardCap,
        'highRiskRequiresApproval': highRiskRequiresApproval,
        'approvalTtlMinutes': approvalTtlMinutes,
        'maskOtpInNotifications': maskOtpInNotifications,
        'listeningEnabled': listeningEnabled,
        'onboardingComplete': onboardingComplete,
        'languageCode': languageCode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        defaultRecipientId: json['defaultRecipientId'] as String?,
        appLockEnabled: json['appLockEnabled'] as bool? ?? false,
        biometricEnabled: json['biometricEnabled'] as bool? ?? false,
        appLockAfterMinutes: json['appLockAfterMinutes'] as int? ?? 0,
        bankingAutoForwardCap:
            (json['bankingAutoForwardCap'] as num?)?.toDouble() ?? 5000,
        highRiskRequiresApproval:
            json['highRiskRequiresApproval'] as bool? ?? true,
        approvalTtlMinutes: json['approvalTtlMinutes'] as int? ?? 5,
        maskOtpInNotifications:
            json['maskOtpInNotifications'] as bool? ?? true,
        listeningEnabled: json['listeningEnabled'] as bool? ?? true,
        onboardingComplete: json['onboardingComplete'] as bool? ?? false,
        languageCode: json['languageCode'] as String? ?? 'en',
      );

  @override
  List<Object?> get props => [
        themeMode, defaultRecipientId, appLockEnabled, biometricEnabled,
        appLockAfterMinutes,
        bankingAutoForwardCap, highRiskRequiresApproval, approvalTtlMinutes,
        maskOtpInNotifications, listeningEnabled, onboardingComplete,
        languageCode,
      ];
}
