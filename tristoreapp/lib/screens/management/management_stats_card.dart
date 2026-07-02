import 'package:flutter/material.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_ui_extension.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/models/management_stats.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';

import 'management_status_labels.dart';

class ManagementStatsCard extends StatelessWidget {
  const ManagementStatsCard({
    super.key,
    required this.title,
    required this.entity,
    required this.stats,
    required this.filters,
    required this.loading,
    required this.error,
    required this.onFilterTap,
    required this.onStatusTap,
    required this.onRetry,
  });

  final String title;
  final ManagementEntity entity;
  final ManagementStatsResponse? stats;
  final ManagementFilters filters;
  final bool loading;
  final String? error;
  final VoidCallback onFilterTap;
  final void Function(String status) onStatusTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final keys = statusKeysForEntity(entity);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (filters.hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filters.activeCount}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: l10n.managementFilterTitle,
                onPressed: onFilterTap,
                icon: const Icon(Icons.filter_list_rounded),
              ),
            ],
          ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
            TextButton(onPressed: onRetry, child: Text(l10n.productsRetry)),
          ]           else if (loading)
            const SizedBox(
              height: 132,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(
              '${l10n.managementTotal}: ${stats?.total ?? 0}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: [
                for (final key in keys)
                  _StatusChip(
                    label: managementStatusLabel(entity, key, l10n),
                    count: stats?.byStatus[key] ?? 0,
                    onTap: () => onStatusTap(key),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(ui.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
