import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Bo góc pill cho dropdown (stadium).
const double tsDropdownPillRadius = 24;

/// Nền ô chọn (xanh nhạt, không viền).
Color get tsDropdownFillColor => AppColors.primaryTint;

/// Shared menu surface for dropdown overlays.
double get tsDropdownMenuRadius => 12;

Color get tsDropdownMenuColor => AppColors.surface;

/// Nhãn phía trên ô dropdown (giống «Người quản lý» trong chi tiết đơn).
TextStyle? tsDropdownSectionLabelStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

/// Pill dropdown — không viền, nền [tsDropdownFillColor].
InputDecoration tsDropdownDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final radius = BorderRadius.circular(tsDropdownPillRadius);
  const borderSide = BorderSide.none;
  return InputDecoration(
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: tsDropdownFillColor,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
    disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
    focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
    errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
    focusedErrorBorder:
        OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
  );
}
