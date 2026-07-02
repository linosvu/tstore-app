import 'package:flutter/material.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_quick_access.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';

class ManagementQuickAccessSection extends StatelessWidget {
  const ManagementQuickAccessSection({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onDelete,
  });

  final List<ManagementQuickAccess> items;
  final void Function(ManagementQuickAccess item) onOpen;
  final void Function(ManagementQuickAccess item) onDelete;

  String _entityLabel(ManagementEntity entity, AppLocalizations l10n) {
    switch (entity) {
      case ManagementEntity.saleOrders:
        return l10n.managementCardOrders;
      case ManagementEntity.deliveries:
        return l10n.managementCardDeliveries;
      case ManagementEntity.preparations:
        return l10n.managementCardPreparations;
      case ManagementEntity.tasks:
        return l10n.managementCardTasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space3,
        AppSpacing.space3,
        AppSpacing.space3,
        AppSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.managementQuickAccessTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  '${items.length}/${ManagementQuickAccess.maxSaved}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          SizedBox(
            height: 88,
            child: items.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.managementQuickAccessEmpty,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _QuickAccessTile(
                        item: item,
                        entityLabel: _entityLabel(item.entity, l10n),
                        onTap: () => onOpen(item),
                        onLongPress: () => onDelete(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.item,
    required this.entityLabel,
    required this.onTap,
    required this.onLongPress,
  });

  final ManagementQuickAccess item;
  final String entityLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 148,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                entityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
