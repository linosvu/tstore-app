import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

const List<String> kPreparationMineStatusFilterOrder = [
  'pending',
  'in_progress',
  'ready',
  'cancelled',
];

/// Chuẩn hóa mã cũ `done` → `ready` (sau khi gộp trạng thái).
String normalizePreparationStatus(String status) {
  switch (status) {
    case 'done':
      return 'ready';
    default:
      return status;
  }
}

String preparationStatusLabel(String status, AppLocalizations l10n) {
  switch (normalizePreparationStatus(status)) {
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
}

List<String> preparationAllowedStatusTargets(String from) {
  switch (normalizePreparationStatus(from)) {
    case 'pending':
      return ['in_progress', 'cancelled'];
    case 'in_progress':
      return ['ready', 'cancelled'];
    case 'ready':
      return ['cancelled'];
    default:
      return [];
  }
}

List<String> preparationStatusDropdownOptions(String current) {
  final normalized = normalizePreparationStatus(current);
  final next = preparationAllowedStatusTargets(normalized);
  if (next.isEmpty) return [normalized];
  return [normalized, ...next];
}

/// Trạng thái chọn được khi quản lý đổi nhảy cóc (khớp tab lọc + backend).
List<String> preparationManagerSelectableStatuses(String current) {
  final normalized = normalizePreparationStatus(current);
  return kPreparationMineStatusFilterOrder
      .where((s) => s != normalized)
      .toList();
}

/// Quản lý vẫn đổi được trạng thái sau khi huỷ (mở lại phiếu nhỡ huỷ nhầm).
bool preparationManagerCanChangeStatus(String status) =>
    preparationManagerSelectableStatuses(status).isNotEmpty;

bool preparationTerminalStatus(String status) {
  final normalized = normalizePreparationStatus(status);
  return normalized == 'ready' || normalized == 'cancelled';
}

StatusBadgeTone preparationStatusTone(String status) {
  switch (normalizePreparationStatus(status)) {
    case 'ready':
      return StatusBadgeTone.success;
    case 'in_progress':
      return StatusBadgeTone.warning;
    case 'cancelled':
      return StatusBadgeTone.error;
    default:
      return StatusBadgeTone.neutral;
  }
}

String preparationAddressLine(PreparationOrderPublic p) {
  final snap = p.saleOrder?.deliveryAddressSnapshot ?? const {};
  final h = snap['houseNumber']?.toString().trim() ?? '';
  final w = snap['wardId']?.toString().trim() ?? '';
  final pr = snap['provinceId']?.toString().trim() ?? '';
  return [h, w, pr].where((e) => e.isNotEmpty).join(', ');
}
