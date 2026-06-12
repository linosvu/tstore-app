import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_ui_extension.dart';

/// Home-style 2-column service shortcut grid (DMX-inspired).
class ServiceTileGrid extends StatelessWidget {
  const ServiceTileGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 2,
  });

  final List<ServiceTileItem> items;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.cardOuter,
        crossAxisSpacing: AppSpacing.cardOuter,
        childAspectRatio: 1.05,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui.radiusLg),
          ),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(ui.radiusLg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui.radiusLg),
                boxShadow: ui.softShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 26),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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

class ServiceTileItem {
  const ServiceTileItem({
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
