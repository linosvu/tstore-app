import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_ui_extension.dart';

/// Inline error with retry for scrollable regions / slivers.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final err = context.appUi.error;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: err.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: err.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: err, size: 32),
              const SizedBox(height: AppSpacing.space3),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
              if (onRetry != null &&
                  retryLabel != null &&
                  retryLabel!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space4),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(retryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
