import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'status_badge.dart';
import 'ts_dropdown_decorations.dart';

Widget tsDropdownWithSectionLabel(
  BuildContext context, {
  required String? sectionLabel,
  required Widget dropdown,
}) {
  if (sectionLabel == null || sectionLabel.isEmpty) return dropdown;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        sectionLabel,
        style: tsDropdownSectionLabelStyle(context),
      ),
      const SizedBox(height: 6),
      dropdown,
    ],
  );
}

Widget _tsDropdownSelectedRow(
  BuildContext context, {
  required String label,
  IconData? leadingIcon,
  Color? leadingIconColor,
}) {
  final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );
  return Row(
    children: [
      if (leadingIcon != null) ...[
        Icon(
          leadingIcon,
          size: 20,
          color: leadingIconColor ?? AppColors.error,
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
    ],
  );
}

/// Dropdown dạng pill — nền xanh nhạt, không viền (giống chọn địa chỉ DMX).
class TsDropdownField<T> extends StatelessWidget {
  const TsDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.isExpanded = true,
    this.enabled = true,
    this.toneFor,
    this.leadingIcon,
    this.leadingIconColor,
    /// Badge chỉ trong menu; ô đóng hiển thị chữ (mặc định).
    this.badgeInMenuOnly = true,
  });

  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final bool isExpanded;
  final bool enabled;
  final StatusBadgeTone Function(T value)? toneFor;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool badgeInMenuOnly;

  StatusBadgeTone _tone(T v) => toneFor?.call(v) ?? StatusBadgeTone.neutral;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      value: value,
      isExpanded: isExpanded,
      decoration: tsDropdownDecoration(
        context,
        hintText: hintText,
      ),
      dropdownColor: tsDropdownMenuColor,
      borderRadius: BorderRadius.circular(tsDropdownMenuRadius),
      elevation: 8,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? AppColors.primary : AppColors.onSurfaceVariant,
        size: 24,
      ),
      selectedItemBuilder: (context) {
        return items
            .map(
              (v) => Align(
                alignment: Alignment.centerLeft,
                child: badgeInMenuOnly || toneFor == null
                    ? _tsDropdownSelectedRow(
                        context,
                        label: itemLabel(v),
                        leadingIcon: leadingIcon,
                        leadingIconColor: leadingIconColor,
                      )
                    : StatusBadge(
                        label: itemLabel(v),
                        tone: _tone(v),
                      ),
              ),
            )
            .toList();
      },
      items: items
          .map(
            (v) => DropdownMenuItem<T>(
              value: v,
              child: toneFor != null && !badgeInMenuOnly
                  ? StatusBadge(
                      label: itemLabel(v),
                      tone: _tone(v),
                      expand: true,
                    )
                  : Text(itemLabel(v)),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
    return tsDropdownWithSectionLabel(
      context,
      sectionLabel: labelText,
      dropdown: field,
    );
  }
}

/// Nullable value variant (e.g. assignee unassigned).
class TsDropdownFieldNullable<T> extends StatelessWidget {
  const TsDropdownFieldNullable({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.onChanged,
    this.labelText,
    this.isExpanded = true,
    this.enabled = true,
    this.toneFor,
    this.leadingIcon,
    this.leadingIconColor,
    this.badgeInMenuOnly = true,
  });

  final T? value;
  final List<T?> items;
  final String Function(T? value) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final bool isExpanded;
  final bool enabled;
  final StatusBadgeTone Function(T? value)? toneFor;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool badgeInMenuOnly;

  StatusBadgeTone _tone(T? v) => toneFor?.call(v) ?? StatusBadgeTone.neutral;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T?>(
      value: value,
      isExpanded: isExpanded,
      decoration: tsDropdownDecoration(context),
      dropdownColor: tsDropdownMenuColor,
      borderRadius: BorderRadius.circular(tsDropdownMenuRadius),
      elevation: 8,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? AppColors.primary : AppColors.onSurfaceVariant,
        size: 24,
      ),
      selectedItemBuilder: (context) {
        return items
            .map(
              (v) => Align(
                alignment: Alignment.centerLeft,
                child: badgeInMenuOnly || toneFor == null
                    ? _tsDropdownSelectedRow(
                        context,
                        label: itemLabel(v),
                        leadingIcon: leadingIcon,
                        leadingIconColor: leadingIconColor,
                      )
                    : StatusBadge(
                        label: itemLabel(v),
                        tone: _tone(v),
                      ),
              ),
            )
            .toList();
      },
      items: items
          .map(
            (v) => DropdownMenuItem<T?>(
              value: v,
              child: toneFor != null && !badgeInMenuOnly
                  ? StatusBadge(
                      label: itemLabel(v),
                      tone: _tone(v),
                      expand: true,
                    )
                  : Text(itemLabel(v)),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
    return tsDropdownWithSectionLabel(
      context,
      sectionLabel: labelText,
      dropdown: field,
    );
  }
}
