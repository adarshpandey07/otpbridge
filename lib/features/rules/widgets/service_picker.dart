import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

/// Curated fallback brands per group, shown when inbox detection finds
/// nothing (fresh emulator, iOS, or no SMS permission) — so the wizard is
/// never a dead end.
const Map<CategoryGroup, List<String>> kPopularBrands = {
  CategoryGroup.shopping: ['Amazon', 'Flipkart', 'Myntra', 'Ajio', 'Meesho'],
  CategoryGroup.grocery: [
    'Blinkit', 'Zepto', 'Instamart', 'BigBasket', 'JioMart', //
  ],
  CategoryGroup.food: ['Swiggy', 'Zomato', 'Dominos', 'KFC'],
  CategoryGroup.banking: ['SBI', 'HDFC', 'ICICI', 'Axis', 'Kotak'],
  CategoryGroup.finance: ['Paytm', 'PhonePe', 'GPay', 'CRED', 'Zerodha'],
  CategoryGroup.bills: ['Airtel', 'Jio', 'Vi', 'Tata Power', 'BSNL'],
  CategoryGroup.travel: [
    'MakeMyTrip', 'IRCTC', 'Uber', 'Ola', 'RedBus', 'Rapido', //
  ],
  CategoryGroup.health: ['Practo', 'PharmEasy', 'Tata 1mg', 'Apollo'],
  CategoryGroup.government: ['DigiLocker', 'UIDAI', 'Income Tax', 'EPFO'],
  CategoryGroup.accounts: ['Google', 'WhatsApp', 'Instagram', 'Facebook'],
  CategoryGroup.entertainment: [
    'Netflix', 'Hotstar', 'Prime Video', 'BookMyShow', 'Spotify', //
  ],
  CategoryGroup.promotions: [],
  CategoryGroup.other: [],
};

/// Step 2 of the wizard: services detected from the user's real inbox for
/// the chosen group (preselected checkboxes), with a curated popular-brand
/// fallback and an "Add another" chip when detection is empty.
class ServicePicker extends ConsumerWidget {
  const ServicePicker({
    super.key,
    required this.group,
    required this.selected,
    required this.customBrands,
    required this.onToggle,
    required this.onAdd,
  });

  final CategoryGroup group;

  /// Currently selected brand names.
  final Set<String> selected;

  /// Brands the user added by hand via "Add another".
  final List<String> customBrands;

  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAdd;

  Future<void> _promptAdd(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a service'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'e.g. Nykaa'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final brand = value?.trim();
    if (brand != null && brand.isNotEmpty) onAdd(brand);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(detectedServicesProvider);

    return servicesAsync.when(
      loading: () => const GlassCard(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Scanning your messages…')),
          ],
        ),
      ),
      error: (_, __) => _fallback(context),
      data: (services) {
        final detected =
            services.where((s) => s.group == group).toList(growable: false);
        if (detected.isEmpty) return _fallback(context);
        return _detectedList(context, detected);
      },
    );
  }

  /// Detection succeeded: checkbox rows of services that actually message
  /// the user, plus extra popular/custom brands as chips underneath.
  Widget _detectedList(BuildContext context, List<DetectedService> detected) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final detectedBrands =
        detected.map((s) => s.brand.toLowerCase()).toSet();
    final extras = _extraBrands(exclude: detectedBrands);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found in your inbox',
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < detected.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                  _ServiceRow(
                    service: detected[i],
                    selected: selected.contains(detected[i].brand),
                    onTap: () => onToggle(detected[i].brand),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('More services', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _brandChips(context, extras),
        const SizedBox(height: AppSpacing.md),
        _selectNoneHint(context, t),
      ],
    );
  }

  /// No detection (empty inbox / iOS / no permission): curated popular
  /// brands as chips so the flow still takes seconds.
  Widget _fallback(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: t.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pick the ${group.label} apps you use — '
                  'we\'ll auto-detect more as messages arrive.',
                  style: textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _brandChips(context, _extraBrands(exclude: const {})),
        const SizedBox(height: AppSpacing.md),
        _selectNoneHint(context, t),
      ],
    );
  }

  /// Popular brands for [group] (minus [exclude]) merged with the user's
  /// custom additions, deduplicated case-insensitively.
  List<String> _extraBrands({required Set<String> exclude}) {
    final seen = {...exclude};
    final result = <String>[];
    for (final brand in [
      ...kPopularBrands[group] ?? const <String>[],
      ...customBrands,
    ]) {
      if (seen.add(brand.toLowerCase())) result.add(brand);
    }
    return result;
  }

  Widget _brandChips(BuildContext context, List<String> brands) {
    final t = context.tokens;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final brand in brands)
          FilterChip(
            label: Text(brand),
            selected: selected.contains(brand),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            onSelected: (_) => onToggle(brand),
          ),
        ActionChip(
          avatar: Icon(Icons.add_rounded, size: 18, color: t.textSecondary),
          label: const Text('Add another'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          onPressed: () => _promptAdd(context),
        ),
      ],
    );
  }

  Widget _selectNoneHint(BuildContext context, AppTokens t) => Text(
        'Select none to match every ${group.label} message.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: t.textTertiary),
      );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final DetectedService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final count = service.messageCount;

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
            CategoryAvatar(category: service.category, size: 40),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.brand,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$count message${count == 1 ? '' : 's'}',
                    style:
                        textTheme.bodySmall?.copyWith(color: t.textSecondary),
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
