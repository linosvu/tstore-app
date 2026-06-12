import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import 'ts_outlined_retry_button.dart';

/// Empty / error state with illustration area + retry (DMX interrupted app).
class TsEmptyErrorState extends StatelessWidget {
  const TsEmptyErrorState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.cloud_off_outlined,
    this.retryLabel = 'Thử lại',
    this.onRetry,
    this.child,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String retryLabel;
  final VoidCallback? onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (child != null)
            child!
          else
            Icon(
              icon,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          const SizedBox(height: AppSpacing.space6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.space6),
            TsOutlinedRetryButton(
              label: retryLabel,
              onPressed: onRetry!,
            ),
          ],
        ],
      ),
    );
  }
}
