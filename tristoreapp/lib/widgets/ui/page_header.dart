import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

/// Page title row: optional overline, title, subtitle, trailing actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.overline,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String? overline;
  final String title;
  final String? subtitle;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space4,
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                ],
                Text(
                  title,
                  style: text.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: trailing!,
            ),
        ],
      ),
    );
  }
}
