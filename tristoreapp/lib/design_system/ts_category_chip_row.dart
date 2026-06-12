import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_ui_extension.dart';

class TsCategoryChipItem {
  const TsCategoryChipItem({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final IconData? icon;
}

/// Horizontal category chips with blue border when selected.
class TsCategoryChipRow extends StatelessWidget {
  const TsCategoryChipRow({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<TsCategoryChipItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return SizedBox(
      height: ui.categoryChipHeight + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.space2),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.id == selectedId;
          return _CategoryChip(
            label: item.label,
            icon: item.icon,
            selected: selected,
            onTap: () => onSelected(item.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    final borderColor = selected ? AppColors.primary : AppColors.chipBorder;
    final fg = selected ? AppColors.primary : AppColors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radiusSm),
        child: Container(
          height: ui.categoryChipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryTint : AppColors.surface,
            borderRadius: BorderRadius.circular(ui.radiusSm),
            border: Border.all(color: borderColor, width: ui.chipBorderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
