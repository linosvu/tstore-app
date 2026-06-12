import 'package:flutter/material.dart';

/// Global spacing tokens (8pt grid). Tune density in one place.
class AppSpacing {
  AppSpacing._();

  /// 8pt grid steps
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  /// Screen edges (enterprise default 16h).
  static const double screenHorizontal = space4;
  static const double screenVertical = space3;

  static const double sectionGap = space6;
  static const double headerBottom = space4;
  static const double cardOuter = space3;
  static const double cardInnerLg = space4;
  static const double controlMinHeight = 52;
  static const double searchBarHeight = 48;

  /// Default inner padding for cards and [GlassContainer] when not overridden.
  static const double cardInner = 14;

  static EdgeInsets get screenPadding => const EdgeInsets.symmetric(
        horizontal: screenHorizontal,
        vertical: screenVertical,
      );

  static EdgeInsets get screenPaddingAll =>
      const EdgeInsets.all(screenHorizontal);
}
