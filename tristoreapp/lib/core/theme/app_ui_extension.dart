import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Design tokens beyond [ColorScheme] (radius, semantic, list density).
@immutable
class AppUiExtension extends ThemeExtension<AppUiExtension> {
  const AppUiExtension({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.statusPillRadius,
    required this.cardElevation,
    required this.hairline,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.accent,
    required this.denseListTileVerticalPadding,
    required this.pageHeaderSpacing,
    required this.softShadow,
    required this.tabIndicatorHeight,
    required this.chipBorderWidth,
    required this.categoryChipHeight,
    required this.stickyBarMinHeight,
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double statusPillRadius;
  final double cardElevation;
  final double hairline;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color accent;
  final double denseListTileVerticalPadding;
  final double pageHeaderSpacing;
  final List<BoxShadow> softShadow;
  final double tabIndicatorHeight;
  final double chipBorderWidth;
  final double categoryChipHeight;
  final double stickyBarMinHeight;

  static final AppUiExtension light = AppUiExtension(
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 16,
    radiusXl: 20,
    statusPillRadius: 6,
    cardElevation: 0,
    hairline: 1,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.primary,
    accent: AppColors.accent,
    denseListTileVerticalPadding: 6,
    pageHeaderSpacing: 8,
    softShadow: AppColors.softShadow,
    tabIndicatorHeight: 3,
    chipBorderWidth: 1,
    categoryChipHeight: 40,
    stickyBarMinHeight: 52,
  );

  static final AppUiExtension dark = AppUiExtension(
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 16,
    radiusXl: 20,
    statusPillRadius: 6,
    cardElevation: 0,
    hairline: 1,
    success: const Color(0xFF22C55E),
    warning: const Color(0xFFF59E0B),
    error: const Color(0xFFEF4444),
    info: const Color(0xFF60A5FA),
    accent: AppColors.accent,
    denseListTileVerticalPadding: 6,
    pageHeaderSpacing: 8,
    softShadow: AppColors.softShadow,
    tabIndicatorHeight: 3,
    chipBorderWidth: 1,
    categoryChipHeight: 40,
    stickyBarMinHeight: 52,
  );

  @override
  AppUiExtension copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? statusPillRadius,
    double? cardElevation,
    double? hairline,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? accent,
    double? denseListTileVerticalPadding,
    double? pageHeaderSpacing,
    List<BoxShadow>? softShadow,
    double? tabIndicatorHeight,
    double? chipBorderWidth,
    double? categoryChipHeight,
    double? stickyBarMinHeight,
  }) {
    return AppUiExtension(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      statusPillRadius: statusPillRadius ?? this.statusPillRadius,
      cardElevation: cardElevation ?? this.cardElevation,
      hairline: hairline ?? this.hairline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      accent: accent ?? this.accent,
      denseListTileVerticalPadding:
          denseListTileVerticalPadding ?? this.denseListTileVerticalPadding,
      pageHeaderSpacing: pageHeaderSpacing ?? this.pageHeaderSpacing,
      softShadow: softShadow ?? this.softShadow,
      tabIndicatorHeight: tabIndicatorHeight ?? this.tabIndicatorHeight,
      chipBorderWidth: chipBorderWidth ?? this.chipBorderWidth,
      categoryChipHeight: categoryChipHeight ?? this.categoryChipHeight,
      stickyBarMinHeight: stickyBarMinHeight ?? this.stickyBarMinHeight,
    );
  }

  @override
  AppUiExtension lerp(ThemeExtension<AppUiExtension>? other, double t) {
    if (other is! AppUiExtension) return this;
    return AppUiExtension(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      statusPillRadius: lerpDouble(statusPillRadius, other.statusPillRadius, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
      hairline: lerpDouble(hairline, other.hairline, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      denseListTileVerticalPadding: lerpDouble(
        denseListTileVerticalPadding,
        other.denseListTileVerticalPadding,
        t,
      )!,
      pageHeaderSpacing:
          lerpDouble(pageHeaderSpacing, other.pageHeaderSpacing, t)!,
      softShadow: softShadow,
      tabIndicatorHeight:
          lerpDouble(tabIndicatorHeight, other.tabIndicatorHeight, t)!,
      chipBorderWidth: lerpDouble(chipBorderWidth, other.chipBorderWidth, t)!,
      categoryChipHeight:
          lerpDouble(categoryChipHeight, other.categoryChipHeight, t)!,
      stickyBarMinHeight:
          lerpDouble(stickyBarMinHeight, other.stickyBarMinHeight, t)!,
    );
  }
}

extension AppUiExtensionX on BuildContext {
  AppUiExtension get appUi =>
      Theme.of(this).extension<AppUiExtension>() ?? AppUiExtension.light;
}
