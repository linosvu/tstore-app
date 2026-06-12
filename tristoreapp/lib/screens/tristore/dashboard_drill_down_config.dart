import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';

/// Các tile Dashboard có thể drill-down sang màn danh sách.
enum DashboardDrillDownKind {
  ordersToday,
  prepToday,
  deliveryToday,
  overdueOrders,
  dueWithin24h,
  scheduledDelivery24h,
  noPrepAssignee,
  noDeliveryAssignee,
  draftOrTemp,
  prepToDo,
  deliveryToDo,
  scheduledPayment,
}

class DashboardDrillDownConfig {
  const DashboardDrillDownConfig({
    required this.entity,
    required this.filters,
    required this.listScope,
    required this.title,
  });

  final ManagementEntity entity;
  final ManagementFilters filters;
  final String listScope;
  final String title;

  static String todayDateStr([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DashboardDrillDownConfig fromKind(
    DashboardDrillDownKind kind, {
    required AppLocalizations l10n,
    required bool isElevated,
  }) {
    final today = todayDateStr();
    switch (kind) {
      case DashboardDrillDownKind.ordersToday:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.saleOrders,
          filters: ManagementFilters(from: today, to: today),
          listScope: isElevated ? 'all' : 'created',
          title: l10n.dashboardStatOrdersToday,
        );
      case DashboardDrillDownKind.prepToday:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.preparations,
          filters: ManagementFilters(from: today, to: today),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardStatPrepToday,
        );
      case DashboardDrillDownKind.deliveryToday:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.deliveries,
          filters: ManagementFilters(from: today, to: today),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardStatDeliveryToday,
        );
      case DashboardDrillDownKind.overdueOrders:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.saleOrders,
          filters: const ManagementFilters(
            expectedDeliveryFilter: 'overdue',
          ),
          listScope: isElevated ? 'all' : 'involved',
          title: l10n.dashboardReminderOverdue,
        );
      case DashboardDrillDownKind.dueWithin24h:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.saleOrders,
          filters: const ManagementFilters(
            expectedDeliveryFilter: 'due_soon',
          ),
          listScope: isElevated ? 'all' : 'involved',
          title: l10n.dashboardReminderDueWithin24h,
        );
      case DashboardDrillDownKind.scheduledDelivery24h:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.deliveries,
          filters: const ManagementFilters(deliveryScheduledSoon: true),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardReminderScheduledDelivery24h,
        );
      case DashboardDrillDownKind.noPrepAssignee:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.preparations,
          filters: const ManagementFilters(
            assigneeUnassigned: true,
            prepActive: true,
          ),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardReminderNoPrepAssignee,
        );
      case DashboardDrillDownKind.noDeliveryAssignee:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.deliveries,
          filters: const ManagementFilters(
            assigneeUnassigned: true,
            deliveryActive: true,
          ),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardReminderNoDeliveryAssignee,
        );
      case DashboardDrillDownKind.draftOrTemp:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.saleOrders,
          filters: const ManagementFilters(
            statusIn: ['draft', 'confirmed'],
          ),
          listScope: isElevated ? 'all' : 'created',
          title: l10n.dashboardReminderDraft,
        );
      case DashboardDrillDownKind.prepToDo:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.preparations,
          filters: const ManagementFilters(prepActive: true),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardReminderPrep,
        );
      case DashboardDrillDownKind.deliveryToDo:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.deliveries,
          filters: const ManagementFilters(deliveryActive: true),
          listScope: isElevated ? 'all' : 'mine',
          title: l10n.dashboardReminderDelivery,
        );
      case DashboardDrillDownKind.scheduledPayment:
        return DashboardDrillDownConfig(
          entity: ManagementEntity.saleOrders,
          filters: const ManagementFilters(paymentFilter: 'scheduled'),
          listScope: isElevated ? 'all' : 'created',
          title: l10n.dashboardReminderScheduledPayment,
        );
    }
  }
}
