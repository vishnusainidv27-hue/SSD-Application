import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A consistent section title for long forms and grouped screens (e.g.
/// Add/Edit Customer's "Address" / "Milk subscription" groups, a report's
/// filter groups) — see `docs/DESIGN_SYSTEM.md`. Replaces the handful of
/// screens that used to build their own ad hoc section-title `Text` widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
    this.topGap = true,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  /// Whether to add the usual gap above this header. Set to false for the
  /// first section on a screen, where the surrounding scroll padding already
  /// provides the space.
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: topGap ? AppSpacing.lg : 0,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppTheme.brandNavy),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.brandNavy,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
