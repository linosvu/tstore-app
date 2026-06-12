import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_ui_extension.dart';

/// Shimmer placeholders aligned with real list cards (orders, fulfillment, products).
enum ListSkeletonVariant {
  /// Matches [_OrderRowCard] on [OrdersListScreen].
  orderRow,

  /// Matches [_FulfillmentCard] on [OrderFulfillmentHubScreen].
  fulfillment,

  /// Compact product / repair list rows.
  compact,
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.rows = 6,
    this.variant = ListSkeletonVariant.orderRow,
  });

  final int rows;
  final ListSkeletonVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surface;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.space3,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.space2),
        itemBuilder: (_, __) => switch (variant) {
          ListSkeletonVariant.orderRow => const _OrderRowSkeleton(),
          ListSkeletonVariant.fulfillment => const _FulfillmentCardSkeleton(),
          ListSkeletonVariant.compact => const _CompactRowSkeleton(),
        },
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _OrderRowSkeleton extends StatelessWidget {
  const _OrderRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardInnerLg,
          vertical: AppSpacing.space3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ShimmerBox(width: 120, height: 18, radius: 6),
                      const SizedBox(height: AppSpacing.space1),
                      const _ShimmerBox(width: 160, height: 14, radius: 6),
                      const SizedBox(height: 4),
                      const _ShimmerBox(width: 200, height: 14, radius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _ShimmerBox(width: 72, height: 22, radius: 6),
                    const SizedBox(height: 6),
                    const _ShimmerBox(width: 88, height: 16, radius: 6),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            const _ShimmerBox(width: double.infinity, height: 6, radius: 3),
          ],
        ),
      ),
    );
  }
}

class _FulfillmentCardSkeleton extends StatelessWidget {
  const _FulfillmentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui.radiusLg),
        boxShadow: ui.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ShimmerBox(width: 140, height: 18, radius: 6),
                    const SizedBox(height: 6),
                    const _ShimmerBox(width: 100, height: 14, radius: 6),
                    const SizedBox(height: 4),
                    const _ShimmerBox(width: 180, height: 14, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _ShimmerBox(width: 64, height: 22, radius: 6),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ShimmerBox(
                              width: double.infinity,
                              height: 14,
                              radius: 4,
                            ),
                          ),
                          SizedBox(width: 8),
                          _ShimmerBox(width: 56, height: 22, radius: 6),
                        ],
                      ),
                      SizedBox(height: 6),
                      _ShimmerBox(width: double.infinity, height: 12, radius: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ShimmerBox(
                              width: double.infinity,
                              height: 14,
                              radius: 4,
                            ),
                          ),
                          SizedBox(width: 8),
                          _ShimmerBox(width: 56, height: 22, radius: 6),
                        ],
                      ),
                      SizedBox(height: 6),
                      _ShimmerBox(width: double.infinity, height: 12, radius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactRowSkeleton extends StatelessWidget {
  const _CompactRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _ShimmerBox(width: 48, height: 48, radius: 10),
          SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 160, height: 16, radius: 6),
                SizedBox(height: 6),
                _ShimmerBox(width: 120, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
