import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/recipients/contact_picker_screen.dart';

enum _AddChoice { contacts, manual }

/// Full-screen list of forwarding recipients. Tapping a card opens the
/// editor; "+" offers "From contacts" (primary) or manual entry (or routes
/// to the paywall at the free-tier cap).
class RecipientsScreen extends ConsumerWidget {
  const RecipientsScreen({super.key});

  /// "+" flow: let the user pick contacts (multi-select) or type details.
  Future<void> _startAddFlow(
    BuildContext context, {
    required int? remainingSlots,
  }) async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      builder: (sheetContext) => const _AddRecipientSheet(),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case _AddChoice.manual:
        context.push(Routes.recipientEditor);
      case _AddChoice.contacts:
        final result = await ContactPickerScreen.pick(
          context,
          multiSelect: true,
          maxSelectable: remainingSlots,
        );
        if (!context.mounted) return;
        switch (result) {
          case ContactsAdded(:final recipients) when recipients.isNotEmpty:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    recipients.length == 1
                        ? 'Added ${recipients.first.name}'
                        : 'Added ${recipients.length} recipients',
                  ),
                ),
              );
          case ManualEntryRequested():
            context.push(Routes.recipientEditor);
          default:
            break;
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final recipientsAsync = ref.watch(recipientsProvider);
    final recipients = recipientsAsync.valueOrNull ?? const <Recipient>[];
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final limits = subscription?.limits ?? TierLimits.free;
    final atCap = subscription != null &&
        subscription.tier == SubscriptionTier.free &&
        limits.maxRecipients >= 0 &&
        recipients.length >= limits.maxRecipients;
    final int? remainingSlots = subscription != null &&
            subscription.tier == SubscriptionTier.free &&
            limits.maxRecipients >= 0
        ? (limits.maxRecipients - recipients.length).clamp(0, 1 << 31)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipients'),
        actions: [
          IconButton(
            tooltip: atCap
                ? 'Free plan limit reached — upgrade for unlimited recipients'
                : 'Add recipient',
            onPressed: () => atCap
                ? context.push(Routes.paywall)
                : _startAddFlow(context, remainingSlots: remainingSlots),
            style: IconButton.styleFrom(
              backgroundColor: t.primarySubtle,
              foregroundColor: t.onPrimarySubtle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: Icon(
                atCap ? Icons.lock_outline_rounded : Icons.add_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: recipientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Couldn’t load recipients',
          message: '$error',
        ),
        data: (recipients) {
          if (recipients.isEmpty) {
            return EmptyState(
              icon: Icons.people_alt_outlined,
              title: 'No recipients yet',
              message:
                  'Add the people who should receive your forwarded OTPs.',
              action: FilledButton.icon(
                onPressed: () =>
                    _startAddFlow(context, remainingSlots: remainingSlots),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.touchTarget),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                ),
                icon: const Icon(Icons.person_add_alt_outlined, size: 20),
                label: const Text('Add recipient'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.xxl,
            ),
            itemCount: recipients.length + (atCap ? 1 : 0),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == recipients.length) {
                return _UpgradeHint(
                  onTap: () => context.push(Routes.paywall),
                  maxRecipients: limits.maxRecipients,
                );
              }
              return _RecipientCard(recipient: recipients[index]);
            },
          );
        },
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({required this.recipient});

  final Recipient recipient;

  static IconData _channelIcon(ForwardChannel channel) => switch (channel) {
        ForwardChannel.sms => Icons.sms_outlined,
        ForwardChannel.whatsapp => Icons.chat_outlined,
        ForwardChannel.telegram => Icons.send_outlined,
        ForwardChannel.email => Icons.alternate_email_rounded,
        ForwardChannel.push => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      onTap: () => context.push(Routes.recipientEditor, extra: recipient),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primarySubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              recipient.initials,
              style: textTheme.titleMedium?.copyWith(
                color: t.onPrimarySubtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  recipient.phone,
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(
            label: recipient.preferredChannel.label,
            tone: PillTone.info,
            icon: _channelIcon(recipient.preferredChannel),
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Subtle footer shown at the free-tier recipient cap.
class _UpgradeHint extends StatelessWidget {
  const _UpgradeHint({required this.onTap, required this.maxRecipients});

  final VoidCallback onTap;
  final int maxRecipients;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: t.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Free plan includes $maxRecipients '
              'recipient${maxRecipients == 1 ? '' : 's'} — '
              'upgrade for unlimited.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: t.textSecondary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// Bottom sheet offering the two ways to add a recipient — contacts first.
class _AddRecipientSheet extends StatelessWidget {
  const _AddRecipientSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.xs,
          AppSpacing.screenH,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add recipient', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _AddOptionTile(
              icon: Icons.contacts_outlined,
              title: 'From contacts',
              subtitle: 'Pick one or several — details fill in automatically',
              primary: true,
              onTap: () => Navigator.of(context).pop(_AddChoice.contacts),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AddOptionTile(
              icon: Icons.edit_outlined,
              title: 'Enter manually',
              subtitle: 'Type a name and number yourself',
              onTap: () => Navigator.of(context).pop(_AddChoice.manual),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: primary ? t.borderStrong : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? t.primarySubtle : t.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              size: 24,
              color: primary ? t.onPrimarySubtle : t.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }
}
