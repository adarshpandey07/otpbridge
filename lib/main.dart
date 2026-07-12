import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/storage/local_store.dart';
import 'data/billing/razorpay_billing_service.dart';
import 'data/platform/android_sms_gateway.dart';
import 'data/platform/device_contacts_service.dart';
import 'data/platform/local_notification_service.dart';
import 'domain/services/billing_service.dart';
import 'domain/services/contacts_service.dart';
import 'domain/services/notification_service.dart';
import 'domain/services/sms_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.open();

  final bool isMobile = Platform.isAndroid || Platform.isIOS;

  final SmsGateway gateway =
      Platform.isAndroid ? AndroidSmsGateway() : CompanionSmsGateway();

  final ContactsService contacts =
      isMobile ? DeviceContactsService() : NoopContactsService();

  final BillingService billing =
      isMobile ? RazorpayBillingService() : NoopBillingService();

  final NotificationService notifications = LocalNotificationService();
  await notifications.init();

  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      smsGatewayProvider.overrideWithValue(gateway),
      notificationServiceProvider.overrideWithValue(notifications),
      contactsServiceProvider.overrideWithValue(contacts),
      billingServiceProvider.overrideWithValue(billing),
    ],
  );

  // Start the background forwarding worker and wire the SMS listener.
  container.read(forwardingQueueProvider).start();
  _bindSmsListener(container);
  await _autoStartListening(container, gateway);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OtpBridgeApp(),
    ),
  );
}

/// Feeds incoming platform SMS into the pipeline.
void _bindSmsListener(ProviderContainer container) {
  final gateway = container.read(smsGatewayProvider);
  final pipeline = container.read(smsPipelineProvider);
  gateway.incoming.listen((sms) {
    pipeline.process(sms);
  });
}

/// If the user already granted SMS permission and has listening enabled,
/// bring the foreground listener up on launch (don't wait for a settings
/// toggle). Never prompts — onboarding handles the permission request.
Future<void> _autoStartListening(
  ProviderContainer container,
  SmsGateway gateway,
) async {
  try {
    final settings = await container.read(settingsRepositoryProvider).get();
    if (!settings.listeningEnabled) return;
    if (await gateway.hasPermissions()) {
      await gateway.startListening();
    }
  } catch (_) {
    // Non-fatal — the Settings toggle can start it manually.
  }
}
