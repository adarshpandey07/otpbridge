import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/core/widgets/widgets.dart';

/// A titled group of setting rows presented inside a [GlassCard], with
/// hairline dividers between rows. Used across the Settings screen.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(height: 1, indent: 64, endIndent: AppSpacing.md));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// A single tappable settings row: leading icon tile, title, optional
/// subtitle and trailing widget. Minimum 48dp touch target.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Renders the row with danger tinting (e.g. "Reset app").
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final titleColor = destructive ? t.danger : t.textPrimary;
    final iconBg = destructive ? t.dangerSubtle : t.surfaceSunken;
    final iconFg = destructive ? t.danger : t.textSecondary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSpacing.touchTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 20, color: iconFg),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: text.bodyLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: text.bodySmall
                                ?.copyWith(color: t.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [SettingTile] with a trailing [Switch]. Tapping anywhere on the row
/// toggles the value.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// Chevron used by navigation rows.
class SettingChevron extends StatelessWidget {
  const SettingChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 22,
      color: context.tokens.textTertiary,
    );
  }
}
