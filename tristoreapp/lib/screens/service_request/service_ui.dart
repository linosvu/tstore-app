import 'package:flutter/material.dart';
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
  'Tiếp nhận',
  'Hỗ trợ',
  'Thanh toán',
];

/// 0 = Tiếp nhận, 1 = Hỗ trợ, 2 = Thanh toán; >=3 = tất cả xong.
/// Tiếp nhận xong khi phiếu đã tạo; Hỗ trợ xong khi done; Thanh toán xong khi
/// miễn phí hoặc đã thu (không phải unpaid).
int supportStepIndex({
  required String status,
  required bool isFree,
  String? costMode,
  String? paymentMethod,
  int feeAmount = 0,
}) {
  final free = costMode == 'free' || (costMode == null && isFree);
  final method = (paymentMethod ?? '').trim();

  switch (status) {
    case 'processing':
    case 'contact_failed':
      return 1;
    case 'failed':
    case 'cancelled':
    case 'taken':
      return 1;
    case 'done':
      if (free) return 3;
      // Chưa thu → còn bước Thanh toán; còn lại (đã thu / HTO không có HTTT) = xong.
      if (method == 'unpaid') return 2;
      return 3;
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

/// «Hẹn 11/08 17:00» từ appointmentDate + slot.
String appointmentHintLabel(String? date, String? slot) {
  final d = (date ?? '').trim();
  if (d.isEmpty) return '';
  String ddMm = d;
  final parsed = DateTime.tryParse(d.length == 10 ? '${d}T00:00:00' : d);
  if (parsed != null) {
    ddMm =
        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }
  final s = (slot ?? '').trim();
  String time = '';
  if (s.isNotEmpty) {
    final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(s);
    time = m?.group(1) ?? s;
  }
  return time.isEmpty ? 'Hẹn $ddMm' : 'Hẹn $ddMm $time';
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
