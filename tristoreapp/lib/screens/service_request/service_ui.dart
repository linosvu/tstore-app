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

const serviceTicketTypes = ['online', 'onsite', 'repair'];

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
      return 'Xong';
    case 'failed':
      return 'Thất bại';
    case 'taken':
      return 'Đã nhận máy';
    case 'cancelled':
      return 'Đã hủy';
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
      return 'Thanh toán';
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
    case 'cancelled':
    case 'customer_rejected':
      return StatusBadgeTone.error;
    case 'approving':
    case 'paying':
    case 'notifying':
      return StatusBadgeTone.warning;
    case 'taken':
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

/// Repair wizard steps (M8–M13).
int repairStepIndex(String status, {bool customerRejectPending = false}) {
  switch (status) {
    case 'received':
      return 0;
    case 'inspecting':
      return 1;
    case 'approving':
      return 2;
    case 'notifying':
      return customerRejectPending ? 3 : 3;
    case 'repairing':
      return 4;
    case 'delivering':
      return 5;
    case 'paying':
      return 6;
    case 'completed':
    case 'customer_rejected':
    case 'cancelled':
      return 7;
    default:
      return 0;
  }
}

const repairStepLabels = [
  'Tiếp nhận',
  'Kiểm tra',
  'Duyệt KT',
  'Khách xác nhận',
  'Sửa chữa',
  'Bàn giao',
  'Thanh toán',
  'Xong',
];

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
