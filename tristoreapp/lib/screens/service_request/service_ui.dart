import 'package:flutter/material.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

const serviceRequestChannels = [
  'zalo',
  'facebook',
  'phone',
  'in_person',
  'other',
];

const serviceRequestStatuses = [
  'new',
  'processing',
  'completed',
  'cancelled',
];

const serviceTicketTypes = ['online', 'onsite', 'other', 'repair'];

/** Hướng xử lý khi tạo yêu cầu Hỗ trợ. */
const supportTicketTypes = ['online', 'onsite', 'other'];

const repairTicketStatuses = [
  'received',
  'inspecting',
  'approving',
  'notifying',
  'repairing',
  'delivering',
  'paying',
  'completed',
  'customer_rejected',
  'cancelled',
];

bool isTicketClosed(String type, String status) {
  if (type == 'online' || type == 'other') {
    return status == 'done' || status == 'failed' || status == 'cancelled';
  }
  if (type == 'onsite') {
    return status == 'done' ||
        status == 'failed' ||
        status == 'taken' ||
        status == 'cancelled';
  }
  return status == 'completed' ||
      status == 'customer_rejected' ||
      status == 'cancelled';
}

/// HTN đã hoàn thành vẫn cho sửa phí rồi ghi nhận thanh toán.
bool isOnsiteDone(String type, String status) =>
    type == 'onsite' && status == 'done';

String channelLabel(String c) {
  switch (c) {
    case 'zalo':
      return 'Zalo';
    case 'facebook':
      return 'Facebook';
    case 'phone':
      return 'Điện thoại';
    case 'in_person':
      return 'Tại cửa hàng';
    default:
      return 'Khác';
  }
}

String ticketTypeLabel(String t) {
  switch (t) {
    case 'online':
      return 'Hỗ trợ online';
    case 'onsite':
      return 'Hỗ trợ tại nhà';
    case 'other':
      return 'Hỗ trợ khác';
    case 'repair':
      return 'Sửa chữa';
    default:
      return t;
  }
}

String requestStatusLabel(String s) {
  switch (s) {
    case 'new':
      return 'Mới';
    case 'processing':
      return 'Đang xử lý';
    case 'completed':
      return 'Hoàn tất';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return s;
  }
}

StatusBadgeTone requestStatusTone(String s) {
  switch (s) {
    case 'completed':
      return StatusBadgeTone.success;
    case 'cancelled':
      return StatusBadgeTone.error;
    case 'processing':
      return StatusBadgeTone.info;
    default:
      return StatusBadgeTone.neutral;
  }
}

String ticketStatusLabel(String type, String s) {
  switch (s) {
    case 'processing':
      return 'Đang xử lý';
    case 'done':
      return 'Hoàn thành';
    case 'failed':
      return type == 'online' || type == 'onsite'
          ? 'Không xử lý được'
          : 'Thất bại';
    case 'taken':
      return 'Đã nhận máy';
    case 'cancelled':
      return 'Hủy';
    case 'contact_failed':
      return type == 'onsite'
          ? 'Không gặp được khách'
          : 'Không liên lạc được';
    case 'received':
      return 'Tiếp nhận';
    case 'inspecting':
      return 'Kiểm tra lỗi';
    case 'approving':
      return 'Chờ duyệt';
    case 'notifying':
      return 'Thông báo khách';
    case 'repairing':
      return 'Đang sửa';
    case 'delivering':
      return 'Bàn giao';
    case 'paying':
      return 'Thanh toán & Duyệt';
    case 'completed':
      return 'Hoàn tất';
    case 'customer_rejected':
      return 'Khách từ chối';
    default:
      return s;
  }
}

StatusBadgeTone ticketStatusTone(String s) {
  switch (s) {
    case 'done':
    case 'completed':
      return StatusBadgeTone.success;
    case 'failed':
    case 'customer_rejected':
      return StatusBadgeTone.error;
    case 'cancelled':
      return StatusBadgeTone.neutral;
    case 'approving':
    case 'paying':
    case 'notifying':
    case 'contact_failed':
      return StatusBadgeTone.warning;
    case 'taken':
    case 'processing':
      return StatusBadgeTone.info;
    default:
      return StatusBadgeTone.info;
  }
}

String formatServiceTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// Số tiền VNĐ có dấu chấm hàng nghìn (giống Đơn hàng).
String formatServiceMoney(int v) =>
    formatIntegerWithSeparator(v, ThousandsGroupSeparatorKey.dot);

/// Format giá trị nhật ký có thể chứa số tiền (`1500000`, `cash:1500000`).
String formatTicketLogMoneyValue(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '—';
  if (t == 'free') return t;
  if (t.startsWith('free:')) return t;
  final methodAmount = RegExp(r'^([a-z_]+):(\d+)$').firstMatch(t);
  if (methodAmount != null) {
    final n = int.tryParse(methodAmount.group(2)!);
    if (n == null) return t;
    return '${methodAmount.group(1)}:${formatServiceMoney(n)}';
  }
  if (RegExp(r'^\d+$').hasMatch(t)) {
    final n = int.tryParse(t);
    if (n != null) return formatServiceMoney(n);
  }
  return t;
}

String yyyyMmDd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Repair wizard steps.
int repairStepIndex(String status, {bool customerRejectPending = false}) {
  switch (status) {
    case 'received':
      return 0;
    case 'inspecting':
    case 'approving': // legacy → map Kiểm tra
    case 'notifying':
      return 1;
    case 'repairing':
      return 2;
    case 'delivering':
      return 3;
    case 'paying':
      return 4;
    case 'completed':
    case 'customer_rejected':
    case 'cancelled':
      return 5;
    default:
      return 0;
  }
}

const repairStepLabels = [
  'Tiếp nhận',
  'Kiểm tra',
  'Sửa chữa',
  'Bàn giao',
  'Thanh toán & Duyệt',
  'Xong',
];

const supportFlowStepLabels = [
  'Quản lý',
  'Hỗ trợ',
  'Thanh toán',
];

/// 0 = Quản lý, 1 = Hỗ trợ, 2 = Thanh toán; >=3 = tất cả xong.
/// Quản lý xong khi phiếu đã tạo; Hỗ trợ xong khi done; Thanh toán xong khi
/// miễn phí hoặc đã thu (không phải unpaid).
int supportStepIndex({
  required String status,
  required bool isFree,
  String? costMode,
  String? paymentMethod,
  int feeAmount = 0,
  bool paymentCollected = false,
}) {
  final free = feeAmount <= 0 || costMode == 'free';

  switch (status) {
    case 'processing':
    case 'contact_failed':
      return 1;
    case 'failed':
    case 'cancelled':
    case 'taken':
      return 1;
    case 'done':
      if (free || paymentCollected) return 3;
      return 2;
    default:
      return 1;
  }
}

bool supportStepFailed(String status) =>
    status == 'failed' || status == 'cancelled';

String deadlineRemainingLabel(String? iso, {bool markOverdue = false}) {
  if (iso == null || iso.isEmpty) return '';
  final deadline = DateTime.tryParse(iso);
  if (deadline == null) return '';
  final now = DateTime.now();
  final overdue = markOverdue || deadline.isBefore(now);
  if (overdue) {
    final late = now.difference(deadline);
    return 'Quá hạn ${late.inHours}h ${late.inMinutes.remainder(60)}p';
  }
  final diff = deadline.difference(now);
  if (diff.inDays >= 1) {
    return 'Còn ${diff.inDays} ngày ${diff.inHours.remainder(24)}h';
  }
  return 'Còn ${diff.inHours}h ${diff.inMinutes.remainder(60)}p';
}

/// «Hẹn 11/08 17:00» từ appointmentDate + giờ cụ thể.
String appointmentHintLabel(String? date, String? slot) {
  final d = (date ?? '').trim();
  if (d.isEmpty) return '';
  String ddMm = d;
  final parsed = DateTime.tryParse(d.length == 10 ? '${d}T00:00:00' : d);
  if (parsed != null) {
    ddMm =
        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }
  final time = normalizeAppointmentTimeLabel(slot);
  return time.isEmpty ? 'Hẹn $ddMm' : 'Hẹn $ddMm $time';
}

const defaultAppointmentTime = TimeOfDay(hour: 9, minute: 0);

String formatAppointmentTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Chuẩn hoá «09:00» hoặc legacy «09:00-11:00» → «09:00».
String normalizeAppointmentTimeLabel(String? raw) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch((raw ?? '').trim());
  if (m == null) return '';
  final h = int.tryParse(m.group(1)!);
  final min = int.tryParse(m.group(2)!);
  if (h == null || min == null) return '';
  return '${h.clamp(0, 23).toString().padLeft(2, '0')}:'
      '${min.clamp(0, 59).toString().padLeft(2, '0')}';
}

TimeOfDay parseAppointmentTimeOfDay(
  String? raw, {
  TimeOfDay fallback = defaultAppointmentTime,
}) {
  final label = normalizeAppointmentTimeLabel(raw);
  if (label.isEmpty) return fallback;
  final parts = label.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

Future<TimeOfDay?> pickAppointmentTimeOfDay(
  BuildContext context, {
  TimeOfDay? initial,
}) {
  return showTimePicker(
    context: context,
    initialTime: initial ?? defaultAppointmentTime,
  );
}

/// Thời gian đã sửa: từ [isoStart] đến hiện tại (ngày + giờ + phút).
String formatRepairElapsed(String? isoStart, {String? fallbackIso}) {
  final raw = (isoStart != null && isoStart.isNotEmpty) ? isoStart : fallbackIso;
  if (raw == null || raw.isEmpty) return '—';
  final start = DateTime.tryParse(raw);
  if (start == null) return '—';
  final d = DateTime.now().difference(start.toLocal());
  if (d.isNegative) return '0 ngày 0 giờ';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  if (days > 0) return '$days ngày $hours giờ $mins phút';
  if (hours > 0) return '$hours giờ $mins phút';
  return '$mins phút';
}

String repairMethodLabel(String? method) {
  switch (method) {
    case 'store':
      return 'Tại cửa hàng';
    case 'warranty_center':
      return 'Trung tâm bảo hành';
    case 'external':
      return 'Sửa ngoài';
    case 'other':
      return 'Khác';
    default:
      return method ?? '—';
  }
}

Future<String?> promptReason(
  BuildContext context, {
  String title = 'Nhập lý do',
  String hint = 'Lý do',
}) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(hintText: hint),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true || text.isEmpty) return null;
  return text;
}
