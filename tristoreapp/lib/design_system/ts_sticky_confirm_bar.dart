import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_ui_extension.dart';

/// Fixed bottom navy confirm button (DMX "Xác nhận").
class TsStickyConfirmBar extends StatelessWidget {
  const TsStickyConfirmBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space3,
            AppSpacing.screenHorizontal,
            AppSpacing.space3,
          ),
          child: SizedBox(
            width: double.infinity,
            height: ui.stickyBarMinHeight,
            child: FilledButton(
              onPressed: enabled && !loading ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                disabledBackgroundColor:
                    AppColors.primaryDark.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ui.radiusMd),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
