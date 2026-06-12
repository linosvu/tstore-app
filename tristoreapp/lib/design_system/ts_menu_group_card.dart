import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_ui_extension.dart';
import '../widgets/ui/menu_group_card.dart';

export '../widgets/ui/menu_group_card.dart' show MenuGroupItem;

/// DMX-style grouped menu list inside a card.
class TsMenuGroupCard extends StatelessWidget {
  const TsMenuGroupCard({
    super.key,
    this.title,
    required this.items,
  });

  final String? title;
  final List<MenuGroupItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ui = context.appUi;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ui.radiusLg),
        boxShadow: ui.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardInnerLg,
                AppSpacing.cardInnerLg,
                AppSpacing.cardInnerLg,
                AppSpacing.space2,
              ),
              child: Text(
                title!,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final isLast = i == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardInnerLg,
                      vertical: AppSpacing.space3,
                    ),
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: 22,
                            color: item.iconColor ?? AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.space3),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (item.trailing != null)
                          item.trailing!
                        else if (item.onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primary.withValues(alpha: 0.5),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: ui.hairline,
                    indent: AppSpacing.cardInnerLg,
                    endIndent: AppSpacing.cardInnerLg,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
