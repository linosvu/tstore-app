import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_ui_extension.dart';

/// Compact 3×2 shortcut grid for home (icon + label, minimal padding).
class TsCompactServiceGrid extends StatelessWidget {
  const TsCompactServiceGrid({
    super.key,
    required this.items,
  });

  final List<TsCompactServiceItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.space2,
        crossAxisSpacing: AppSpacing.space2,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui.radiusMd),
          ),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(ui.radiusMd),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui.radiusMd),
                border: Border.all(
                  color: AppColors.chipBorder,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: item.iconColor, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.2,
                            color: AppColors.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TsCompactServiceItem {
  const TsCompactServiceItem({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}
