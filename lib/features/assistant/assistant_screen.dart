import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/data/rules/nl_rule_parser.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/features/rules/widgets/rule_summary.dart';

/// Natural-language rule assistant: describe a rule in one sentence, review
/// what was understood, fill anything missing with a tap, and save.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  static const _examples = [
    'Forward Amazon orders to Rahul',
    'Send all bank OTPs to my CA every month',
    'Block banking messages',
  ];

  final _controller = TextEditingController();

  RuleDraft? _draft;

  /// Effective recipients: starts from the draft, editable via the chips.
  Set<String> _recipientIds = {};

  /// Category picked when the parser couldn't tell "what".
  CategoryGroup? _pickedGroup;

  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  void _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final recipients =
        ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final draft =
        ref.read(nlRuleParserProvider).parse(trimmed, recipients: recipients);
    setState(() {
      _draft = draft;
      _recipientIds = {...draft.recipientIds};
      _pickedGroup = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _useExample(String example) {
    _controller.text = example;
    _parse(example);
  }

  void _reset() {
    setState(() {
      _draft = null;
      _recipientIds = {};
      _pickedGroup = null;
      _controller.clear();
    });
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  bool get _needsWhat =>
      (_draft?.missing.contains('what') ?? false) && _pickedGroup == null;

  bool get _needsRecipient {
    final draft = _draft;
    if (draft == null) return false;
    return draft.action != RuleAction.block && _recipientIds.isEmpty;
  }

  bool get _readyToCreate =>
      _draft != null && !_needsWhat && !_needsRecipient;

  Set<OtpCategory> get _effectiveCategories => {
        ...?_draft?.categories,
        ...?_pickedGroup?.categories,
      };

  String _finalName(ForwardRule rule, List<Recipient> recipients) {
    final byId = {for (final r in recipients) r.id: r};
    final String subject;
    if (rule.brands.isNotEmpty) {
      subject = rule.brands.first;
    } else if (_pickedGroup != null) {
      subject = _pickedGroup!.label;
    } else if (rule.categories.isNotEmpty) {
      subject = rule.categories.first.label;
    } else {
      subject = 'All';
    }
    if (rule.action == RuleAction.block) return 'Block $subject';

    final names = rule.recipientIds
        .map((id) => byId[id]?.name.trim().split(RegExp(r'\s+')).first)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return subject;
    final target = names.length == 1
        ? names.first
        : '${names.first} +${names.length - 1}';
    return '$subject → $target';
  }

  Future<void> _create() async {
    final draft = _draft;
    if (draft == null || _saving || !_readyToCreate) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(rulesRepositoryProvider);
      final existing = await repo.getAll(); // sorted by sortOrder
      final recipients =
          ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];

      var rule = draft.toRule(
        id: const Uuid().v4(),
        sortOrder: existing.isEmpty ? 0 : existing.last.sortOrder + 1,
        now: DateTime.now(),
      );
      if (_pickedGroup != null) {
        rule = rule.copyWith(categories: _effectiveCategories);
      }
      rule = rule.copyWith(recipientIds: _recipientIds.toList());
      if (draft.missing.isNotEmpty || rule.name.contains('…')) {
        rule = rule.copyWith(name: _finalName(rule, recipients));
      }

      await repo.save(rule);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rule “${rule.name}” created')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (draft != null)
            TextButton(
              onPressed: _saving ? null : _reset,
              child: const Text('Start over'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            Text('What do you want to automate?',
                style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Describe it in one sentence — we\'ll set up the rule.',
              style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: _parse,
              decoration: InputDecoration(
                hintText: 'e.g. Forward Amazon orders to Rahul',
                suffixIcon: IconButton(
                  tooltip: 'Go',
                  onPressed: () => _parse(_controller.text),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (draft == null) ...[
              Text(
                'Try one of these',
                style: textTheme.labelLarge?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final example in _examples)
                    ActionChip(
                      avatar: Icon(Icons.auto_awesome_outlined,
                          size: 16, color: t.textSecondary),
                      label: Text(example),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                        vertical: AppSpacing.sm,
                      ),
                      onPressed: () => _useExample(example),
                    ),
                ],
              ),
            ] else
              _ReviewCard(
                draft: draft,
                effectiveCategories: _effectiveCategories,
                recipientIds: _recipientIds,
                pickedGroup: _pickedGroup,
                needsWhat: draft.missing.contains('what'),
                needsRecipient: draft.missing.contains('recipient') ||
                    _needsRecipient,
                saving: _saving,
                readyToCreate: _readyToCreate,
                onToggleRecipient: (id) => setState(() {
                  _recipientIds.contains(id)
                      ? _recipientIds.remove(id)
                      : _recipientIds.add(id);
                }),
                onPickGroup: (g) => setState(() => _pickedGroup = g),
                onCreate: _create,
              ),
          ],
        ),
      ),
    );
  }
}

/// Friendly review of what the parser understood, with tap-to-fix sections
/// for anything it couldn't fill.
class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    required this.draft,
    required this.effectiveCategories,
    required this.recipientIds,
    required this.pickedGroup,
    required this.needsWhat,
    required this.needsRecipient,
    required this.saving,
    required this.readyToCreate,
    required this.onToggleRecipient,
    required this.onPickGroup,
    required this.onCreate,
  });

  final RuleDraft draft;
  final Set<OtpCategory> effectiveCategories;
  final Set<String> recipientIds;
  final CategoryGroup? pickedGroup;
  final bool needsWhat;
  final bool needsRecipient;
  final bool saving;
  final bool readyToCreate;
  final ValueChanged<String> onToggleRecipient;
  final ValueChanged<CategoryGroup> onPickGroup;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final byId = {for (final r in recipients) r.id: r};

    final (actionLabel, actionTone) = switch (draft.action) {
      RuleAction.forward => ('Forward', PillTone.success),
      RuleAction.requireApproval => ('Ask first', PillTone.warning),
      RuleAction.block => ('Block', PillTone.danger),
    };

    // Show groups instead of raw categories — friendlier and more compact.
    final groups = {for (final c in effectiveCategories) c.group};
    final recipientNames = recipientIds
        .map((id) => byId[id]?.name)
        .whereType<String>()
        .toList();

    return GlassCard(
      raised: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20, color: t.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Here\'s what we understood',
                style: textTheme.labelLarge?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(draft.explanation, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusPill(label: actionLabel, tone: actionTone),
              for (final brand in draft.brands)
                StatusPill(
                  label: brand,
                  tone: PillTone.primary,
                  icon: Icons.storefront_outlined,
                ),
              for (final group in groups)
                StatusPill(label: group.label, icon: group.icon),
              for (final name in recipientNames)
                StatusPill(
                  label: name,
                  tone: PillTone.info,
                  icon: Icons.person_outline_rounded,
                ),
              StatusPill(
                label: scheduleSummary(context, draft.schedule),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          if (needsWhat) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('What should it match?', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Try naming an app in your sentence, or pick a category:',
              style: textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final group in CategoryGroup.values)
                  ChoiceChip(
                    avatar: Icon(
                      group.icon,
                      size: 16,
                      color: pickedGroup == group
                          ? t.onPrimarySubtle
                          : t.textSecondary,
                    ),
                    label: Text(group.label),
                    selected: pickedGroup == group,
                    showCheckmark: false,
                    onSelected: (_) => onPickGroup(group),
                  ),
              ],
            ),
          ],
          if (needsRecipient) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Who should receive these?', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final recipient in recipients)
                  FilterChip(
                    label: Text(recipient.name),
                    selected: recipientIds.contains(recipient.id),
                    showCheckmark: false,
                    onSelected: (_) => onToggleRecipient(recipient.id),
                  ),
                ActionChip(
                  avatar: Icon(Icons.person_add_alt_outlined,
                      size: 16, color: t.textSecondary),
                  label: const Text('Add recipient'),
                  onPressed: () => context.push(Routes.recipients),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: (readyToCreate && !saving) ? onCreate : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
            ),
            child: saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.onPrimary,
                    ),
                  )
                : const Text('Create rule'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Not quite right? Edit the sentence above and send it again.',
            style: textTheme.bodySmall?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}
