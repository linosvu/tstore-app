import 'package:flutter/material.dart';

/// Shared text styles (tabular numbers for money / codes).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle amount(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle dataSecondary(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12);
  }
}
