import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/app_date_time.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

String deliveryStatusLabel(String s, AppLocalizations l10n) {
  switch (s) {
    case 'pending':
    case 'awaiting_confirm':
    case 'preparing':
    case 'ready':
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
      return s;
  }
}

/// Trạng thái đích hợp lệ (khớp backend `DeliveryService.validateStatusTransition`).
List<String> deliveryAllowedStatusTargets(String from) {
  switch (from) {
    case 'pending':
    case 'awaiting_confirm':
    case 'preparing':
    case 'ready':
      return ['delivering', 'cancelled'];
    case 'delivering':
      return ['completed', 'failed', 'cancelled'];
    default:
      return [];
  }
}

/// Giá trị hiển thị trong dropdown đổi trạng thái (hiện tại + các bước tiếp theo).
List<String> deliveryStatusDropdownOptions(String current) {
  final normalized = _normalizeDeliveryStatus(current);
  final next = deliveryAllowedStatusTargets(normalized);
  if (next.isEmpty) return [normalized];
  return [normalized, ...next];
}

String _normalizeDeliveryStatus(String status) {
  switch (status) {
    case 'awaiting_confirm':
    case 'preparing':
    case 'ready':
      return 'pending';
    default:
      return status;
  }
}

bool deliveryStatusChangeNeedsReason(String to) =>
    to == 'failed' || to == 'cancelled';

const List<String> kDeliveryManagerStatusOptions = [
  'pending',
  'delivering',
  'completed',
  'failed',
  'cancelled',
];

/// Trạng thái chọn được khi quản lý đổi nhảy cóc.
List<String> deliveryManagerSelectableStatuses(String current) {
  final normalized = _normalizeDeliveryStatus(current);
  return kDeliveryManagerStatusOptions
      .where((s) => s != normalized)
      .toList();
}

bool deliveryTerminalStatus(String status) =>
    _normalizeDeliveryStatus(status) == 'completed' ||
    _normalizeDeliveryStatus(status) == 'failed' ||
    _normalizeDeliveryStatus(status) == 'cancelled';

StatusBadgeTone deliveryStatusTone(String status) {
  switch (_normalizeDeliveryStatus(status)) {
    case 'completed':
      return StatusBadgeTone.success;
    case 'delivering':
      return StatusBadgeTone.info;
    case 'failed':
    case 'cancelled':
      return StatusBadgeTone.error;
    default:
      return StatusBadgeTone.warning;
  }
}

StatusBadgeTone deliveryPriorityTone(String priority) {
  switch (priority) {
    case 'urgent':
    case 'high':
      return StatusBadgeTone.error;
    case 'low':
      return StatusBadgeTone.neutral;
    default:
      return StatusBadgeTone.info;
  }
}

Future<String?> promptDeliveryStatusReason(
  BuildContext context,
  AppLocalizations l10n,
) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deliveryReason),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(hintText: l10n.deliveryReason),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true) return null;
  return text;
}

String deliveryPriorityLabel(String priority, AppLocalizations l10n) {
  switch (priority) {
    case 'low':
      return l10n.deliveryPriorityLow;
    case 'normal':
      return l10n.deliveryPriorityNormal;
    case 'high':
      return l10n.deliveryPriorityHigh;
    case 'urgent':
      return l10n.deliveryPriorityUrgent;
    default:
      return priority;
  }
}

/// Thứ tự chip lọc trạng thái (tab Đơn của tôi).
const List<String> kDeliveryMineStatusFilterOrder = [
  'pending',
  'delivering',
  'completed',
  'failed',
  'cancelled',
];

Color deliveryStatusColor(String status, ThemeData theme) {
  final scheme = theme.colorScheme;
  switch (_normalizeDeliveryStatus(status)) {
    case 'pending':
      return scheme.onSurfaceVariant;
    case 'delivering':
      return const Color(0xFF1565C0);
    case 'completed':
      return const Color(0xFF2E7D32);
    case 'failed':
      return scheme.error;
    case 'cancelled':
      return scheme.outline;
    default:
      return scheme.onSurfaceVariant;
  }
}

String deliveryAddressLine(DeliveryPublic d) {
  final snap = d.saleOrder?.deliveryAddressSnapshot ?? const {};
  final h = snap['houseNumber']?.toString().trim() ?? '';
  final w = snap['wardId']?.toString().trim() ?? '';
  final p = snap['provinceId']?.toString().trim() ?? '';
  return [h, w, p].where((e) => e.isNotEmpty).join(', ');
}

String deliveryFormatMoney(int v) {
  return '${v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      )} đ';
}

String? deliveryScheduledFormatted(String? iso) {
  final raw = iso?.trim();
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;
  return DateFormat('dd/MM/yyyy HH:mm').format(AppDateTime.toVn(dt));
}

/// Rút gọn cho card danh sách đơn: `01/06 - 09:00`.
String? orderExpectedDeliveryCompact(String? iso) {
  final raw = iso?.trim();
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;
  return DateFormat('dd/MM - HH:mm').format(AppDateTime.toVn(dt));
}

/// Đếm ngược / quá hạn tới giờ hẹn giao; tự refresh mỗi 30 giây.
class DeliveryCountdownTicker extends StatefulWidget {
  const DeliveryCountdownTicker({
    super.key,
    required this.scheduledAtIso,
    required this.l10n,
    this.style,
  });

  final String? scheduledAtIso;
  final AppLocalizations l10n;
  final TextStyle? style;

  @override
  State<DeliveryCountdownTicker> createState() => _DeliveryCountdownTickerState();
}

class _DeliveryCountdownTickerState extends State<DeliveryCountdownTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _countdownText(widget.scheduledAtIso, widget.l10n);
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String? _countdownText(String? iso, AppLocalizations l10n) {
    final raw = iso?.trim();
    if (raw == null || raw.isEmpty) return null;
    final target = DateTime.tryParse(raw)?.toLocal();
    if (target == null) return null;

    final now = DateTime.now();
    final diff = target.difference(now);
    if (!diff.isNegative) {
      if (diff.inDays >= 2) return l10n.deliveryCountdownDays(diff.inDays);
      if (diff.inDays == 1) return l10n.deliveryCountdownOneDay;
      if (diff.inHours >= 1) {
        return l10n.deliveryCountdownHrsMin(diff.inHours, diff.inMinutes % 60);
      }
      if (diff.inMinutes >= 5) return l10n.deliveryCountdownMinutes(diff.inMinutes);
      return l10n.deliveryCountdownSoon;
    }

    final overdue = now.difference(target);
    if (overdue.inDays >= 2) return l10n.deliveryCountdownOverDays(overdue.inDays);
    if (overdue.inDays == 1) return l10n.deliveryCountdownOverOneDay;
    if (overdue.inHours >= 1) {
      return l10n.deliveryCountdownOverHrsMin(
        overdue.inHours,
        overdue.inMinutes % 60,
      );
    }
    final mins = overdue.inMinutes < 1 ? 1 : overdue.inMinutes;
    return l10n.deliveryCountdownOverMinutes(mins);
  }
}
