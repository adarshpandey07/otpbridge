import 'package:flutter/material.dart';

import 'package:otpbridge/core/theme/app_colors.dart';
import 'package:otpbridge/core/theme/app_spacing.dart';
import 'package:otpbridge/domain/models/models.dart';

/// Step 1 of the wizard: every [CategoryGroup] as a large tappable card
/// (icon + label). One tap selects — no typing.
class CategoryGroupGrid extends StatelessWidget {
  const CategoryGroupGrid({
    super.key,
    this.selected,
    required this.onSelected,
  });

  final CategoryGroup? selected;
  final ValueChanged<CategoryGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.95,
      ),
      itemCount: CategoryGroup.values.length,
      itemBuilder: (context, index) {
        final group = CategoryGroup.values[index];
        return _GroupCard(
          group: group,
          selected: group == selected,
          onTap: () => onSelected(group),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final CategoryGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(AppRadius.md);

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: selected ? t.primarySubtle : t.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: selected ? t.primary : t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  group.icon,
                  size: 26,
                  color: selected ? t.onPrimarySubtle : t.textSecondary,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  group.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: selected ? t.onPrimarySubtle : t.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
