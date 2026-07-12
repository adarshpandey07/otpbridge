import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The core surface primitive: a soft, bordered card with an optional
/// frosted-glass backdrop. Subtle by default — trust over flash.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.frosted = false,
    this.raised = false,
    this.borderColor,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool frosted;
  final bool raised;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borderRadius = BorderRadius.circular(radius);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: frosted ? t.glassFill : t.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? (frosted ? t.glassBorder : t.border)),
        boxShadow: raised
            ? [
                BoxShadow(
                  color: t.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    final card = frosted
        ? ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: content,
            ),
          )
        : content;

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.indigo500.withValues(alpha: 0.06),
        highlightColor: AppColors.indigo500.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
