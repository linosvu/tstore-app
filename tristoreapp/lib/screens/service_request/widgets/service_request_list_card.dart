import 'package:flutter/material.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

import '../service_ui.dart';
import 'ticket_flow_progress_bar.dart';

/// Thẻ list dùng chung Support (HTO/HTN) và Sửa chữa — cùng bố cục/khoảng cách/badge.
class ServiceRequestListCard extends StatelessWidget {
  const ServiceRequestListCard({
    super.key,
    required this.request,
    required this.onOpen,
    required this.onOpenTicket,
  });

  final ServiceRequestPublic request;
  final VoidCallback onOpen;
  final void Function(ServiceTicketBrief) onOpenTicket;

  ({String? label, bool overdue, bool showScheduleIcon}) _repairSecondarySchedule(
    ServiceTicketBrief ticket,
  ) {
    final step = repairStepIndex(ticket.status);
    if (step >= 5) {
      return (label: null, overdue: false, showScheduleIcon: false);
    }

    String? labeledCountdown(String? iso, {required String prefix}) {
      final rem = deadlineRemainingLabel(iso);
      if (rem.isNotEmpty) return '$prefix · $rem';
      if (iso != null && iso.trim().isNotEmpty) {
        return '$prefix · ${formatServiceTime(iso)}';
      }
      return null;
    }

    bool isPast(String? iso) {
      if (iso == null || iso.trim().isEmpty) return false;
      final dt = DateTime.tryParse(iso);
      return dt != null && dt.isBefore(DateTime.now());
    }

    String? etaDateLabel(String? etaDate) {
      final raw = (etaDate ?? '').trim();
      if (raw.isEmpty) return null;
      String displayDate = raw;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        displayDate =
            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
      }
      return 'ETA · $displayDate';
    }

    switch (step) {
      case 0: {
        final iso = ticket.contactDeadlineAt;
        final label = labeledCountdown(iso, prefix: 'Hẹn gọi');
        return (
          label: label,
          overdue: isPast(iso),
          showScheduleIcon: label != null,
        );
      }
      case 1: {
        final iso = ticket.deadlineAt;
        final rem = deadlineRemainingLabel(iso, markOverdue: ticket.isOverdue);
        return (
          label: rem.isEmpty ? null : rem,
          overdue: ticket.isOverdue || isPast(iso),
          showScheduleIcon: false,
        );
      }
      case 2: {
        final eta = etaDateLabel(ticket.etaDate);
        if (eta != null) {
          final etaIso = (ticket.etaDate ?? '').trim();
          final endOfDay = DateTime.tryParse(
            etaIso.length == 10 ? '${etaIso}T23:59:59' : etaIso,
          );
          return (
            label: eta,
            overdue: endOfDay != null && endOfDay.isBefore(DateTime.now()),
            showScheduleIcon: true,
          );
        }
        final iso = ticket.deadlineAt;
        final rem = deadlineRemainingLabel(iso, markOverdue: ticket.isOverdue);
        return (
          label: rem.isEmpty ? null : 'ETA · $rem',
          overdue: ticket.isOverdue || isPast(iso),
          showScheduleIcon: rem.isNotEmpty,
        );
      }
      case 3: {
        final iso = (ticket.deliveryEta ?? '').trim().isNotEmpty
            ? ticket.deliveryEta
            : ticket.deadlineAt;
        final label = labeledCountdown(iso, prefix: 'Hẹn giao');
        return (
          label: label,
          overdue: isPast(iso),
          showScheduleIcon: label != null,
        );
      }
      case 4: {
        final iso = ticket.deadlineAt;
        final rem = deadlineRemainingLabel(iso, markOverdue: ticket.isOverdue);
        return (
          label: rem.isEmpty ? null : rem,
          overdue: ticket.isOverdue || isPast(iso),
          showScheduleIcon: false,
        );
      }
      default:
        return (label: null, overdue: false, showScheduleIcon: false);
    }
  }

  ({String? label, bool overdue}) _supportTime(ServiceTicketBrief ticket) {
    final closed = ticket.status == 'done' ||
        ticket.status == 'failed' ||
        ticket.status == 'cancelled' ||
        ticket.status == 'taken';
    if (ticket.status == 'contact_failed') {
      final hint = appointmentHintLabel(
        ticket.appointmentDate,
        ticket.appointmentSlot,
      );
      return (label: hint.isEmpty ? null : hint, overdue: false);
    }
    if (closed) {
      final doneAt = formatServiceTime(
        ticket.statusChangedAt ?? ticket.createdAt,
      );
      return (label: doneAt == '—' ? null : doneAt, overdue: false);
    }
    final rem = deadlineRemainingLabel(
      ticket.deadlineAt,
      markOverdue: ticket.isOverdue,
    );
    return (
      label: rem.isEmpty ? null : rem,
      overdue: ticket.isOverdue,
    );
  }

  Widget _moneyText(BuildContext context, ServiceTicketBrief ticket) {
    if (ticket.listMoneyIsFree) {
      return Text(
        'Miễn phí',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF059669),
        ),
        textAlign: TextAlign.right,
      );
    }
    final amount = ticket.listMoneyAmount;
    if (amount <= 0) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.right,
      );
    }
    return Text(
      '${formatIntegerWithSeparator(amount, ThousandsGroupSeparatorKey.dot)} đ',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      textAlign: TextAlign.right,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = request.latestTicket;
    final isRepair = request.isRepairDirection || latest?.type == 'repair';
    final creator = (request.createdByName ?? '').trim();
    final manager = (request.managerName ?? '').trim();

    String? timeLabel;
    var timeOverdue = false;
    var showScheduleIcon = false;
    if (isRepair && latest != null) {
      final schedule = _repairSecondarySchedule(latest);
      timeLabel = schedule.label;
      timeOverdue = schedule.overdue;
      showScheduleIcon = schedule.showScheduleIcon;
      if (repairStepIndex(latest.status) >= 5) {
        final doneAt = formatServiceTime(
          latest.statusChangedAt ?? latest.createdAt,
        );
        timeLabel = doneAt == '—' ? timeLabel : doneAt;
        timeOverdue = false;
        showScheduleIcon = false;
      }
    } else if (latest != null) {
      final t = _supportTime(latest);
      timeLabel = t.label;
      timeOverdue = t.overdue;
    }

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.displayCode,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${request.customerName} · ${request.customerPhone}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          request.productName,
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.issueDescription.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Lỗi: ${request.issueDescription.trim()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (creator.isNotEmpty || manager.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          if (creator.isNotEmpty)
                            Text(
                              'Người tạo: $creator',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (manager.isNotEmpty)
                            Text(
                              'NV quản lý: $manager',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                        if (latest != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            isRepair
                                ? 'KTV: ${(latest.staffName ?? '').trim().isNotEmpty ? latest.staffName!.trim() : '—'}'
                                : '${latest.type == 'onsite' ? 'NV hỗ trợ' : 'KTV'}: ${(latest.staffName ?? '').trim().isNotEmpty ? latest.staffName!.trim() : '—'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (latest != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          label: ticketStatusLabel(latest.type, latest.status),
                          tone: ticketStatusTone(latest.status),
                        ),
                        if (timeLabel != null) ...[
                          const SizedBox(height: 6),
                          if (showScheduleIcon)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: timeOverdue
                                      ? Colors.red
                                      : scheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: timeOverdue
                                        ? Colors.red
                                        : scheme.primary,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: timeOverdue
                                    ? Colors.red
                                    : scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.right,
                            ),
                        ],
                        const SizedBox(height: 6),
                        _moneyText(context, latest),
                        if (latest.isOverdue) ...[
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: Colors.red,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 10),
                if (isRepair && latest.type == 'repair')
                  TicketFlowProgressBar(
                    labels: const [
                      'Tiếp nhận',
                      'Kiểm tra',
                      'Sửa chữa',
                      'Bàn giao',
                      'Thanh toán',
                    ],
                    activeIndex: () {
                      final failed = latest.status == 'cancelled' ||
                          latest.status == 'customer_rejected';
                      final raw = repairStepIndex(latest.status);
                      if (failed) {
                        return raw >= 5 ? 4 : raw.clamp(0, 4);
                      }
                      return raw >= 5 ? 5 : raw;
                    }(),
                    failed: latest.status == 'cancelled' ||
                        latest.status == 'customer_rejected',
                    stepSubtitles: [
                      latest.receiveStaffName,
                      latest.staffName,
                      latest.staffName,
                      latest.deliveryStaffName,
                      request.managerName,
                    ],
                  )
                else if (!isRepair)
                  TicketFlowProgressBar(
                    labels: supportFlowStepLabels,
                    activeIndex: () {
                      final failed = supportStepFailed(latest.status);
                      final raw = supportStepIndex(
                        status: latest.status,
                        isFree: latest.isFree,
                        costMode: latest.costMode,
                        paymentMethod: latest.paymentMethod,
                        feeAmount: latest.feeAmount,
                      );
                      if (failed) {
                        return raw.clamp(0, supportFlowStepLabels.length - 1);
                      }
                      return raw;
                    }(),
                    failed: supportStepFailed(latest.status),
                    stepSubtitles: [
                      request.createdByName,
                      latest.staffName,
                      request.managerName,
                    ],
                  ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => onOpenTicket(latest),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          latest.type == 'repair'
                              ? Icons.build_outlined
                              : latest.type == 'onsite'
                                  ? Icons.home_repair_service_outlined
                                  : Icons.headset_mic_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${latest.displayCode} · ${ticketTypeLabel(latest.type)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
