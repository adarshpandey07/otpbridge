import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/domain/models/models.dart';

import 'rule_summary.dart';

enum _Preset { anyTime, everyDay, weekdays, weekends, officeHours }

extension on _Preset {
  String get label => switch (this) {
        _Preset.anyTime => 'Any time',
        _Preset.everyDay => 'Every day',
        _Preset.weekdays => 'Weekdays',
        _Preset.weekends => 'Weekends',
        _Preset.officeHours => 'Office hours (9–6)',
      };

  IconData get icon => switch (this) {
        _Preset.anyTime => Icons.all_inclusive_rounded,
        _Preset.everyDay => Icons.today_outlined,
        _Preset.weekdays => Icons.date_range_outlined,
        _Preset.weekends => Icons.weekend_outlined,
        _Preset.officeHours => Icons.schedule_rounded,
      };

  ScheduleKind get kind => switch (this) {
        _Preset.anyTime || _Preset.everyDay => ScheduleKind.always,
        _Preset.weekdays => ScheduleKind.weekdays,
        _Preset.weekends => ScheduleKind.weekends,
        _Preset.officeHours => ScheduleKind.workingHours,
      };
}

/// "When?" picker built around big one-tap presets. An "Advanced" expander
/// reveals a compact custom day/time picker; most users never open it.
/// Advanced can be gated behind premium via [advancedUnlocked].
class SchedulePresets extends StatefulWidget {
  const SchedulePresets({
    super.key,
    required this.schedule,
    required this.onChanged,
    this.advancedUnlocked = true,
    this.onAdvancedLocked,
  });

  final RuleSchedule schedule;
  final ValueChanged<RuleSchedule> onChanged;

  /// Whether the user's plan includes advanced (custom) schedules.
  final bool advancedUnlocked;

  /// Called when Advanced is tapped while locked (route to paywall).
  final VoidCallback? onAdvancedLocked;

  @override
  State<SchedulePresets> createState() => _SchedulePresetsState();
}

class _SchedulePresetsState extends State<SchedulePresets> {
  late bool _advancedOpen;

  /// Disambiguates "Any time" vs "Every day" — both map to
  /// [ScheduleKind.always].
  bool _everyDayChosen = false;

  @override
  void initState() {
    super.initState();
    _advancedOpen = widget.schedule.kind == ScheduleKind.custom ||
        widget.schedule.kind == ScheduleKind.dateRange;
  }

  _Preset? get _selected {
    if (_advancedOpen) return null;
    return switch (widget.schedule.kind) {
      ScheduleKind.always =>
        _everyDayChosen ? _Preset.everyDay : _Preset.anyTime,
      ScheduleKind.weekdays => _Preset.weekdays,
      ScheduleKind.weekends => _Preset.weekends,
      ScheduleKind.workingHours => _Preset.officeHours,
      _ => null,
    };
  }

  void _pick(_Preset preset) {
    setState(() {
      _advancedOpen = false;
      _everyDayChosen = preset == _Preset.everyDay;
    });
    widget.onChanged(RuleSchedule(kind: preset.kind));
  }

  void _toggleAdvanced() {
    if (!widget.advancedUnlocked) {
      widget.onAdvancedLocked?.call();
      return;
    }
    final opening = !_advancedOpen;
    setState(() => _advancedOpen = opening);
    if (opening &&
        widget.schedule.kind != ScheduleKind.custom &&
        widget.schedule.kind != ScheduleKind.dateRange) {
      widget.onChanged(const RuleSchedule(
        kind: ScheduleKind.custom,
        days: {1, 2, 3, 4, 5, 6, 7},
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 18, minute: 0),
      ));
    } else if (!opening && widget.schedule.kind == ScheduleKind.custom) {
      // Collapsing advanced = "never mind" → back to any time.
      _everyDayChosen = false;
      widget.onChanged(RuleSchedule.always);
    }
  }

  void _toggleDay(int weekday) {
    final next = {...widget.schedule.days};
    next.contains(weekday) ? next.remove(weekday) : next.add(weekday);
    widget.onChanged(widget.schedule.copyWith(days: next));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final schedule = widget.schedule;
    final initial = (isStart ? schedule.start : schedule.end) ??
        TimeOfDay(hour: isStart ? 9 : 18, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    widget.onChanged(
      isStart
          ? schedule.copyWith(start: picked)
          : schedule.copyWith(end: picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final preset in _Preset.values)
              ChoiceChip(
                avatar: Icon(
                  preset.icon,
                  size: 16,
                  color: selected == preset
                      ? t.onPrimarySubtle
                      : t.textSecondary,
                ),
                label: Text(preset.label),
                selected: selected == preset,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm,
                ),
                onSelected: (_) => _pick(preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _AdvancedTile(
          open: _advancedOpen,
          locked: !widget.advancedUnlocked,
          onTap: _toggleAdvanced,
        ),
        AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: !_advancedOpen
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text('Days', style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (var weekday = 1; weekday <= 7; weekday++)
                          FilterChip(
                            label: Text(dayAbbreviations[weekday - 1]),
                            selected:
                                widget.schedule.days.contains(weekday),
                            showCheckmark: false,
                            onSelected: (_) => _toggleDay(weekday),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Starts',
                            value: widget.schedule.start == null
                                ? 'Any time'
                                : loc.formatTimeOfDay(widget.schedule.start!),
                            onTap: () => _pickTime(isStart: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TimeTile(
                            label: 'Ends',
                            value: widget.schedule.end == null
                                ? 'Any time'
                                : loc.formatTimeOfDay(widget.schedule.end!),
                            onTap: () => _pickTime(isStart: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: t.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: t.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Active: ${scheduleSummary(context, widget.schedule)}',
                  style:
                      textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvancedTile extends StatelessWidget {
  const _AdvancedTile({
    required this.open,
    required this.locked,
    required this.onTap,
  });

  final bool open;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: t.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Advanced', style: textTheme.titleSmall),
                    Text(
                      'Custom days and hours',
                      style: textTheme.bodySmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline_rounded,
                    size: 18, color: t.textTertiary)
              else
                AnimatedRotation(
                  duration: AppMotion.base,
                  curve: AppMotion.enter,
                  turns: open ? 0.5 : 0,
                  child: Icon(Icons.expand_more_rounded,
                      size: 22, color: t.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: t.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.labelSmall),
                    Text(
                      value,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
