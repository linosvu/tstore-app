import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_ui_extension.dart';

/// Today overview row: icon → number → labels (DMX-style horizontal).
class TsTodayOverviewList extends StatelessWidget {
  const TsTodayOverviewList({
    super.key,
    required this.items,
  });

  final List<TsTodayOverviewItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui.radiusLg),
        boxShadow: ui.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardInnerLg,
                      vertical: AppSpacing.space3,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Text(
                          item.value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.hint.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.hint,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (item.onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: AppSpacing.cardInnerLg + 40 + AppSpacing.space3,
                  endIndent: AppSpacing.cardInnerLg,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class TsTodayOverviewItem {
  const TsTodayOverviewItem({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}
