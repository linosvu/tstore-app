import 'package:flutter/material.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

const repairStatuses = [
  'received',
  'diagnosing',
  'repairing',
  'waiting_parts',
  'done',
  'returned',
  'cancelled',
];

const repairPriorities = ['low', 'normal', 'high', 'urgent'];

const supportTicketStatuses = [
  'open',
  'in_progress',
  'waiting_customer',
  'resolved',
  'closed',
  'cancelled',
];

const supportTicketCategories = [
  'warranty',
  'complaint',
  'inquiry',
  'repair_request',
  'other',
];

const supportTicketPriorities = ['low', 'normal', 'high', 'urgent'];

String repairStatusLabel(String s, AppLocalizations l10n) {
  switch (s) {
    case 'received':
      return 'Đã nhận';
    case 'diagnosing':
      return 'Đang kiểm tra';
    case 'repairing':
      return 'Đang sửa';
    case 'waiting_parts':
      return 'Chờ linh kiện';
    case 'done':
      return 'Đã sửa xong';
    case 'returned':
      return 'Đã trả khách';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return s;
  }
}

StatusBadgeTone repairStatusTone(String s) {
  switch (s) {
    case 'done':
    case 'returned':
      return StatusBadgeTone.success;
    case 'cancelled':
      return StatusBadgeTone.error;
    case 'waiting_parts':
      return StatusBadgeTone.warning;
    default:
      return StatusBadgeTone.info;
  }
}

StatusBadgeTone repairPriorityTone(String p) {
  switch (p) {
    case 'urgent':
    case 'high':
      return StatusBadgeTone.error;
    case 'low':
      return StatusBadgeTone.neutral;
    default:
      return StatusBadgeTone.info;
  }
}

String repairPriorityLabel(String p, AppLocalizations l10n) {
  switch (p) {
    case 'low':
      return 'Thấp';
    case 'normal':
      return 'Bình thường';
    case 'high':
      return 'Cao';
    case 'urgent':
      return 'Khẩn';
    default:
      return p;
  }
}

String supportStatusLabel(String s) {
  switch (s) {
    case 'open':
      return 'Mới';
    case 'in_progress':
      return 'Đang xử lý';
    case 'waiting_customer':
      return 'Chờ khách';
    case 'resolved':
      return 'Đã xử lý';
    case 'closed':
      return 'Đóng';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return s;
  }
}

StatusBadgeTone supportStatusTone(String s) {
  switch (s) {
    case 'resolved':
    case 'closed':
      return StatusBadgeTone.success;
    case 'cancelled':
      return StatusBadgeTone.error;
    case 'waiting_customer':
      return StatusBadgeTone.warning;
    default:
      return StatusBadgeTone.info;
  }
}

String supportCategoryLabel(String c) {
  switch (c) {
    case 'warranty':
      return 'Bảo hành';
    case 'complaint':
      return 'Khiếu nại';
    case 'inquiry':
      return 'Hỏi đáp';
    case 'repair_request':
      return 'Yêu cầu sửa';
    default:
      return 'Khác';
  }
}

String formatActivityTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

Widget activityTimeline<T>({
  required List<T> items,
  required String Function(T) contentOf,
  required String Function(T) timeOf,
}) {
  if (items.isEmpty) {
    return const Text('Chưa có hoạt động.');
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history_rounded, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contentOf(item)),
                    Text(
                      timeOf(item),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
