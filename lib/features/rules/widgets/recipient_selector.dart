import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

/// Multi-select checkbox list of recipients for the rule editor.
/// Prompts to add a recipient when none exist yet.
class RecipientSelector extends ConsumerWidget {
  const RecipientSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  void _toggle(String id) {
    final next = {...selectedIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final recipientsAsync = ref.watch(recipientsProvider);

    return recipientsAsync.when(
      loading: () => const GlassCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => GlassCard(
        child: Text(
          'Couldn’t load recipients.',
          style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        ),
      ),
      data: (recipients) {
        if (recipients.isEmpty) {
          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No recipients yet', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Add the person who should receive your forwarded OTPs.',
                  style: textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => context.push(Routes.recipients),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.touchTarget),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                  ),
                  icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                  label: const Text('Add recipient'),
                ),
              ],
            ),
          );
        }

        return GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < recipients.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                  _RecipientRow(
                    recipient: recipients[i],
                    selected: selectedIds.contains(recipients[i].id),
                    onTap: () => _toggle(recipients[i].id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.selected,
    required this.onTap,
  });

  final Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            _InitialsAvatar(initials: recipient.initials),
            const SizedBox(width: AppSpacing.sm),
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
            Checkbox(value: selected, onChanged: (_) => onTap()),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: t.onPrimarySubtle,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
