import 'package:flutter/material.dart';

import '../../domain/models/otp_category.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rounded-square icon tile representing an OTP category. Color is derived
/// deterministically from the category so the same category always looks
/// the same, using a restrained, desaturated palette.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.category,
    this.size = 44,
  });

  final OtpCategory category;
  final double size;

  static const List<Color> _palette = [
    AppColors.indigo500,
    Color(0xFF0891B2), // cyan-600
    Color(0xFF7C3AED), // violet-600
    Color(0xFF059669), // emerald-600
    Color(0xFFD97706), // amber-600
    Color(0xFFDB2777), // pink-600
    Color(0xFF2563EB), // blue-600
    Color(0xFF65A30D), // lime-600
  ];

  Color get _color => _palette[category.index % _palette.length];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = _color;
    final bg = base.withValues(alpha: isDark ? 0.20 : 0.10);
    final fg = isDark ? Color.lerp(base, Colors.white, 0.35)! : base;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(category.icon, size: size * 0.5, color: fg),
    );
  }
}
