import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_ui_extension.dart';

class TsOutlinedRetryButton extends StatelessWidget {
  const TsOutlinedRetryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        minimumSize: const Size(200, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radiusMd),
        ),
        side: BorderSide(
          color: AppColors.onSurface.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
    );
  }
}
