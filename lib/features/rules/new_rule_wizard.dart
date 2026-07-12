import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:otpbridge/app/providers.dart';
import 'package:otpbridge/app/router.dart';
import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';
import 'package:otpbridge/domain/models/models.dart';

import 'widgets/category_group_grid.dart';
import 'widgets/recipient_selector.dart';
import 'widgets/schedule_presets.dart';
import 'widgets/service_picker.dart';
import 'widgets/wizard_progress.dart';

/// The 4-step new-rule wizard: What? → Which services? → Send to whom? →
/// When? Designed so a rule takes under 30 seconds and needs no typing.
class NewRuleWizard extends ConsumerStatefulWidget {
  const NewRuleWizard({super.key});

  @override
  ConsumerState<NewRuleWizard> createState() => _NewRuleWizardState();
}

class _NewRuleWizardState extends ConsumerState<NewRuleWizard> {
  static const _stepCount = 4;

  final _pageController = PageController();
  int _step = 0;

  CategoryGroup? _group;
  Set<String> _selectedBrands = {};
  final List<String> _customBrands = [];
  bool _pendingPreselect = false;

  Set<String> _recipientIds = {};
  RuleSchedule _schedule = RuleSchedule.always;

  /// User's explicit action choice; null = default derived from the group.
  RuleAction? _actionOverride;

  /// User-edited name via the pencil; null = auto-generated.
  String? _customName;

  bool _saving = false;

  bool get _highRisk =>
      _group == CategoryGroup.banking || _group == CategoryGroup.finance;

  RuleAction get _action =>
      _actionOverride ??
      (_highRisk ? RuleAction.requireApproval : RuleAction.forward);

  bool get _canProceed => switch (_step) {
        0 => _group != null,
        2 => _recipientIds.isNotEmpty,
        _ => true,
      };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: AppMotion.base,
      curve: AppMotion.emphasized,
    );
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _create();
    } else {
      _goTo(_step + 1);
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      _goTo(_step - 1);
    }
  }

  // ── Step 1: group selection ───────────────────────────────────────────────

  void _selectGroup(CategoryGroup group) {
    final changed = group != _group;
    setState(() {
      _group = group;
      if (changed) {
        _customBrands.clear();
        _actionOverride = null;
        _customName = null;
        _preselectBrands();
      }
    });
    // Brief pause so the selection highlight is visible, then advance.
    Future.delayed(AppMotion.fast, () {
      if (mounted && _step == 0) _goTo(1);
    });
  }

  /// Preselect every detected service of the chosen group (the "dynamic app
  /// detection" moment). If detection hasn't finished, do it when it lands.
  void _preselectBrands() {
    final detected = ref.read(detectedServicesProvider).valueOrNull;
    if (detected == null) {
      _selectedBrands = {};
      _pendingPreselect = true;
      return;
    }
    _selectedBrands = detected
        .where((s) => s.group == _group)
        .map((s) => s.brand)
        .toSet();
    _pendingPreselect = false;
  }

  void _toggleBrand(String brand) {
    setState(() {
      _selectedBrands.contains(brand)
          ? _selectedBrands.remove(brand)
          : _selectedBrands.add(brand);
    });
  }

  void _addCustomBrand(String brand) {
    setState(() {
      final exists = _customBrands
          .any((b) => b.toLowerCase() == brand.toLowerCase());
      if (!exists) _customBrands.add(brand);
      _selectedBrands.add(brand);
    });
  }

  // ── Naming & saving ──────────────────────────────────────────────────────

  String _ruleName(List<Recipient> recipients) {
    final custom = _customName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    final brands = _selectedBrands.toList();
    final subject = brands.isEmpty
        ? (_group?.label ?? 'Any OTP')
        : brands.length == 1
            ? brands.first
            : '${brands.first} +${brands.length - 1}';
    if (_action == RuleAction.block) return 'Block $subject';

    final byId = {for (final r in recipients) r.id: r};
    final names = _recipientIds
        .map((id) => byId[id]?.name.trim().split(RegExp(r'\s+')).first)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return subject;
    final target = names.length == 1
        ? names.first
        : '${names.first} +${names.length - 1}';
    return '$subject → $target';
  }

  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rule name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final name = value?.trim();
    if (name != null && name.isNotEmpty) {
      setState(() => _customName = name);
    }
  }

  Future<void> _create() async {
    final group = _group;
    if (_saving || group == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(rulesRepositoryProvider);
      final existing = await repo.getAll(); // sorted by sortOrder
      final recipients =
          ref.read(recipientsProvider).valueOrNull ?? const <Recipient>[];

      final rule = ForwardRule(
        id: const Uuid().v4(),
        name: _ruleName(recipients),
        sortOrder: existing.isEmpty ? 0 : existing.last.sortOrder + 1,
        categories: group.categories,
        brands: _selectedBrands.toList(),
        schedule: _schedule,
        action: _action,
        recipientIds: _recipientIds.toList(),
        createdAt: DateTime.now(),
      );
      await repo.save(rule);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<DetectedService>>>(detectedServicesProvider,
        (previous, next) {
      final services = next.valueOrNull;
      if (_pendingPreselect && services != null) {
        setState(() {
          _selectedBrands = services
              .where((s) => s.group == _group)
              .map((s) => s.brand)
              .toSet();
          _pendingPreselect = false;
        });
      }
    });

    final t = context.tokens;
    final recipients =
        ref.watch(recipientsProvider).valueOrNull ?? const <Recipient>[];
    final limits =
        ref.watch(subscriptionProvider).valueOrNull?.limits ?? TierLimits.free;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New rule'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: WizardProgress(current: _step, total: _stepCount),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _whatPage(),
          _servicesPage(),
          _recipientsPage(recipients),
          _whenPage(recipients, limits),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (_step > 0) ...[
              OutlinedButton(
                onPressed: _saving ? null : _back,
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size(96, AppSpacing.touchTarget),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: FilledButton(
                onPressed: (_canProceed && !_saving) ? _next : null,
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(AppSpacing.touchTarget),
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
                    : Text(
                        _step == _stepCount - 1 ? 'Create rule' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _pagePadding = EdgeInsets.fromLTRB(
    AppSpacing.screenH,
    AppSpacing.sm,
    AppSpacing.screenH,
    AppSpacing.xxl,
  );

  Widget _whatPage() => ListView(
        padding: _pagePadding,
        children: [
          _StepHeader(
            step: 1,
            total: _stepCount,
            title: 'What do you want to forward?',
            subtitle: 'Pick a category — no typing needed.',
          ),
          CategoryGroupGrid(selected: _group, onSelected: _selectGroup),
        ],
      );

  Widget _servicesPage() {
    final group = _group;
    return ListView(
      padding: _pagePadding,
      children: [
        _StepHeader(
          step: 2,
          total: _stepCount,
          title: group == null
              ? 'Which services?'
              : 'Which ${group.label} services?',
          subtitle: 'We only list services that actually message you.',
        ),
        if (group != null)
          ServicePicker(
            group: group,
            selected: _selectedBrands,
            customBrands: _customBrands,
            onToggle: _toggleBrand,
            onAdd: _addCustomBrand,
          ),
      ],
    );
  }

  Widget _recipientsPage(List<Recipient> recipients) => ListView(
        padding: _pagePadding,
        children: [
          _StepHeader(
            step: 3,
            total: _stepCount,
            title: 'Send to whom?',
            subtitle:
                'They receive matching messages the moment they arrive.',
          ),
          RecipientSelector(
            selectedIds: _recipientIds,
            onChanged: (v) => setState(() => _recipientIds = v),
          ),
          if (recipients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.recipients),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
              ),
              icon: const Icon(Icons.person_add_alt_outlined, size: 18),
              label: const Text('Add recipient'),
            ),
          ],
        ],
      );

  Widget _whenPage(List<Recipient> recipients, TierLimits limits) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final name = _ruleName(recipients);

    return ListView(
      padding: _pagePadding,
      children: [
        _StepHeader(
          step: 4,
          total: _stepCount,
          title: 'When should it forward?',
          subtitle: 'Any time works for most rules.',
        ),
        SchedulePresets(
          schedule: _schedule,
          onChanged: (s) => setState(() => _schedule = s),
          advancedUnlocked: limits.advancedSchedules,
          onAdvancedLocked: () => context.push(Routes.paywall),
        ),
        if (_highRisk) ...[
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: t.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('High-risk category',
                          style: textTheme.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'These messages are sensitive — we\'ll ask you first '
                  'before forwarding each one. You can change that here.',
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                      setState(() => _actionOverride = selection.first),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xxs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.label_outline_rounded,
                  size: 20, color: t.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rule name',
                      style: textTheme.labelSmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                    Text(
                      name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit name',
                onPressed: () => _editName(name),
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: t.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final int total;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step $step of $total',
            style: textTheme.labelSmall?.copyWith(color: t.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
