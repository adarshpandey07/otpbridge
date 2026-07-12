import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

import 'widgets/chip_input_field.dart';
import 'widgets/recipient_selector.dart';
import 'widgets/schedule_presets.dart';

/// Compact editor for an existing rule. Reuses the wizard's pieces
/// (category groups, schedule presets) so it stays tidy — the rarely-used
/// filters (senders, keywords) live behind a "More filters" expander.
class RuleEditForm extends ConsumerStatefulWidget {
  const RuleEditForm({super.key, required this.rule});

  final ForwardRule rule;

  @override
  ConsumerState<RuleEditForm> createState() => _RuleEditFormState();
}

class _RuleEditFormState extends ConsumerState<RuleEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late Set<OtpCategory> _categories;
  late List<String> _brands;
  late List<String> _senders;
  late List<String> _keywords;
  late RuleSchedule _schedule;
  late RuleAction _action;
  late Set<String> _recipientIds;
  late bool _showMoreFilters;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule.name);
    final maxAmount = rule.maxAmount;
    _amountController = TextEditingController(
      text: maxAmount == null
          ? ''
          : (maxAmount == maxAmount.roundToDouble()
              ? maxAmount.toStringAsFixed(0)
              : maxAmount.toString()),
    );
    _categories = {...rule.categories};
    _brands = [...rule.brands];
    _senders = [...rule.senders];
    _keywords = [...rule.keywords];
    _schedule = rule.schedule;
    _action = rule.action;
    _recipientIds = {...rule.recipientIds};
    _showMoreFilters = _senders.isNotEmpty || _keywords.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool _groupSelected(CategoryGroup group) =>
      group.categories.any(_categories.contains);

  void _toggleGroup(CategoryGroup group) {
    setState(() {
      if (_groupSelected(group)) {
        _categories.removeAll(group.categories);
      } else {
        _categories.addAll(group.categories);
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_action == RuleAction.forward && _recipientIds.isEmpty) {
      _showSnack('Choose at least one recipient to forward to.');
      return;
    }

    setState(() => _saving = true);
    try {
      double? maxAmount;
      if (_action == RuleAction.forward) {
        final raw = _amountController.text.trim().replaceAll(',', '');
        maxAmount = raw.isEmpty ? null : double.tryParse(raw);
      }

      final rule = ForwardRule(
        id: widget.rule.id,
        name: _nameController.text.trim(),
        enabled: widget.rule.enabled,
        sortOrder: widget.rule.sortOrder,
        categories: _categories,
        brands: _brands,
        senders: _senders,
        keywords: _keywords,
        schedule: _schedule,
        maxAmount: maxAmount,
        action: _action,
        recipientIds: _recipientIds.toList(),
        groupIds: widget.rule.groupIds,
        timesTriggered: widget.rule.timesTriggered,
        createdAt: widget.rule.createdAt,
      );
      await ref.read(rulesRepositoryProvider).save(rule);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text(
          '“${rule.name}” will stop matching OTPs. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(rulesRepositoryProvider).remove(rule.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final limits =
        ref.watch(subscriptionProvider).valueOrNull?.limits ?? TierLimits.free;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit rule'),
        actions: [
          IconButton(
            tooltip: 'Delete rule',
            onPressed: _delete,
            icon: Icon(Icons.delete_outline_rounded, color: t.danger),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Rule name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give this rule a name'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              title: 'What it matches',
              subtitle: 'Empty means any.',
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final group in CategoryGroup.values)
                  FilterChip(
                    avatar: Icon(
                      group.icon,
                      size: 16,
                      color: _groupSelected(group)
                          ? t.onPrimarySubtle
                          : t.textSecondary,
                    ),
                    label: Text(group.label),
                    selected: _groupSelected(group),
                    showCheckmark: false,
                    onSelected: (_) => _toggleGroup(group),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ChipInputField(
              label: 'Brands',
              hint: 'e.g. Amazon',
              helper: 'Match by the brand the message belongs to.',
              values: _brands,
              onChanged: (v) => setState(() => _brands = v),
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showMoreFilters = !_showMoreFilters),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.touchTarget),
                foregroundColor: t.textSecondary,
                alignment: Alignment.centerLeft,
              ),
              icon: AnimatedRotation(
                duration: AppMotion.base,
                curve: AppMotion.enter,
                turns: _showMoreFilters ? 0.5 : 0,
                child: const Icon(Icons.expand_more_rounded, size: 20),
              ),
              label: Text(
                'More filters',
                style: textTheme.titleSmall?.copyWith(color: t.textSecondary),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.base,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: !_showMoreFilters
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xs),
                        ChipInputField(
                          label: 'Senders',
                          hint: 'e.g. VM-AMAZON',
                          helper: 'Match by SMS sender id or prefix.',
                          values: _senders,
                          onChanged: (v) => setState(() => _senders = v),
                          capitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ChipInputField(
                          label: 'Keywords',
                          hint: 'e.g. delivery',
                          helper: 'The message must contain these words.',
                          values: _keywords,
                          onChanged: (v) => setState(() => _keywords = v),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              title: 'Action',
              subtitle: 'What happens when a message matches.',
            ),
            SegmentedButton<RuleAction>(
              segments: const [
                ButtonSegment(
                  value: RuleAction.forward,
                  label: Text('Forward'),
                ),
                ButtonSegment(
                  value: RuleAction.requireApproval,
                  label: Text('Ask first'),
                ),
                ButtonSegment(
                  value: RuleAction.block,
                  label: Text('Block'),
                ),
              ],
              selected: {_action},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: t.primarySubtle,
                selectedForegroundColor: t.onPrimarySubtle,
                foregroundColor: t.textSecondary,
                side: BorderSide(color: t.border),
                minimumSize: const Size(0, AppSpacing.touchTarget),
              ),
              onSelectionChanged: (selection) =>
                  setState(() => _action = selection.first),
            ),
            if (_action == RuleAction.forward) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Max amount (optional)',
                  prefixText: '₹ ',
                  helperText: 'Above this, ask me first.',
                ),
                validator: (value) {
                  final raw = value?.trim().replaceAll(',', '') ?? '';
                  if (raw.isEmpty) return null;
                  final parsed = double.tryParse(raw);
                  return (parsed == null || parsed <= 0)
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SectionHeader(
              title: 'Send to',
              subtitle: 'Who receives the forwarded message.',
              trailing: TextButton(
                onPressed: () => context.push(Routes.recipients),
                child: const Text('Manage'),
              ),
            ),
            RecipientSelector(
              selectedIds: _recipientIds,
              onChanged: (v) => setState(() => _recipientIds = v),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              title: 'When',
              subtitle: 'When this rule is active.',
            ),
            SchedulePresets(
              schedule: _schedule,
              onChanged: (v) => setState(() => _schedule = v),
              advancedUnlocked: limits.advancedSchedules,
              onAdvancedLocked: () => context.push(Routes.paywall),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          ),
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.onPrimary,
                  ),
                )
              : const Text('Save changes'),
        ),
      ),
    );
  }
}
