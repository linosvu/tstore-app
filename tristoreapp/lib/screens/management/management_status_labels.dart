import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/management_entity.dart';

List<String> statusKeysForEntity(ManagementEntity entity) {
  switch (entity) {
    case ManagementEntity.saleOrders:
      return const [
        'draft',
        'confirmed',
        'delivery',
        'completed',
        'cancelled',
        'refund',
      ];
    case ManagementEntity.preparations:
      return const ['pending', 'in_progress', 'ready', 'cancelled'];
    case ManagementEntity.deliveries:
      return const [
        'pending',
        'delivering',
        'completed',
        'failed',
        'cancelled',
      ];
    case ManagementEntity.tasks:
      return const ['pending', 'in_progress', 'completed', 'cancelled'];
  }
}

String managementStatusLabel(
  ManagementEntity entity,
  String status,
  AppLocalizations l10n,
) {
  switch (entity) {
    case ManagementEntity.saleOrders:
      switch (status) {
        case 'draft':
          return l10n.ordersStatusDraft;
        case 'confirmed':
          return l10n.ordersStatusConfirmed;
        case 'delivery':
          return l10n.ordersStatusDelivery;
        case 'completed':
          return l10n.ordersStatusCompleted;
        case 'cancelled':
          return l10n.ordersStatusCancelled;
        case 'refund':
          return l10n.ordersStatusRefund;
        default:
          return status;
      }
    case ManagementEntity.preparations:
      switch (status) {
        case 'pending':
          return l10n.prepStatusPending;
        case 'in_progress':
          return l10n.prepStatusInProgress;
        case 'ready':
          return l10n.prepStatusReady;
        case 'cancelled':
          return l10n.prepStatusCancelled;
        default:
          return status;
      }
    case ManagementEntity.deliveries:
      switch (status) {
        case 'pending':
          return l10n.deliveryStatusPending;
        case 'delivering':
          return l10n.deliveryStatusDelivering;
        case 'completed':
          return l10n.deliveryStatusCompleted;
        case 'failed':
          return l10n.deliveryStatusFailed;
        case 'cancelled':
          return l10n.deliveryStatusCancelled;
        default:
          return status;
      }
    case ManagementEntity.tasks:
      switch (status) {
        case 'pending':
          return l10n.tasksStatusPending;
        case 'in_progress':
          return l10n.tasksStatusInProgress;
        case 'completed':
          return l10n.tasksStatusCompleted;
        case 'cancelled':
          return l10n.tasksStatusCancelled;
        default:
          return status;
      }
  }
}
