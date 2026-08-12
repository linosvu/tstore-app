import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';

import '../service_ui.dart';
import 'countdown_banner.dart';
import 'edit_request_info_sheet.dart';
import 'locked_request_info_card.dart';

/// Khối trên cùng: Thời gian hẹn khách + Hạn xử lý (dùng chung HTO / HTN).
class TicketAppointmentSlaHeader extends StatelessWidget {
  const TicketAppointmentSlaHeader({
    super.key,
    required this.ticket,
    this.canEdit = false,
    this.onUpdated,
  });

  final ServiceTicketPublic ticket;
  final bool canEdit;
  final ValueChanged<ServiceTicketPublic>? onUpdated;

  String get _apptLabel {
    final d = (ticket.appointmentDate ?? '').trim();
    final s = (ticket.appointmentSlot ?? '').trim();
    if (d.isEmpty && s.isEmpty) return '—';
    return [if (d.isNotEmpty) d, if (s.isNotEmpty) s].join(' ');
  }

  Future<void> _editAppointment(BuildContext context) async {
    var date = DateTime.tryParse(ticket.appointmentDate ?? '') ??
        DateTime.now().add(const Duration(days: 1));
    final slotCtrl = TextEditingController(
      text: (ticket.appointmentSlot ?? '').trim().isEmpty
          ? '09:00-11:00'
          : ticket.appointmentSlot!,
    );
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Thời gian hẹn khách'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ngày hẹn'),
                    subtitle: Text(yyyyMmDd(date)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                  ),
                  TextField(
                    controller: slotCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Khung giờ hẹn',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
    final slot = slotCtrl.text.trim();
    slotCtrl.dispose();
    if (go != true || !context.mounted) return;
    if (slot.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập khung giờ hẹn.')),
      );
      return;
    }
    try {
      final updated =
          await context.read<ServiceRequestsProvider>().patchTicketAppointment(
                ticket.id,
                appointmentDate: yyyyMmDd(date),
                appointmentSlot: slot,
              );
      if (!context.mounted) return;
      if (updated != null) {
        onUpdated?.call(updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã cập nhật lịch hẹn.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDeadline = (ticket.deadlineAt ?? '').trim().isNotEmpty &&
        ticket.status != 'contact_failed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: canEdit ? () => _editAppointment(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thời gian hẹn khách',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        Text(
                          _apptLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Sửa lịch hẹn',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editAppointment(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDeadline) ...[
          const SizedBox(height: 8),
          CountdownBanner(
            deadlineAt: ticket.deadlineAt,
            isOverdue: ticket.isOverdue,
          ),
        ],
      ],
    );
  }
}

/// Khối Thông tin yêu cầu dùng chung HTO/HTN (pencil → sheet sửa + request_updated).
class SharedRequestInfoSection extends StatelessWidget {
  const SharedRequestInfoSection({
    super.key,
    required this.ticket,
    this.canEdit = false,
    this.onUpdated,
  });

  final ServiceTicketPublic ticket;
  final bool canEdit;
  final ValueChanged<ServiceTicketPublic>? onUpdated;

  @override
  Widget build(BuildContext context) {
    final req = ticket.request;
    if (req == null) return const SizedBox.shrink();
    final allowEdit =
        canEdit && canEditTicketRequestInfoFromContext(context, ticket);
    return LockedRequestInfoCard(
      request: req,
      appointmentDate: ticket.appointmentDate,
      appointmentSlot: ticket.appointmentSlot,
      onEdit: !allowEdit
          ? null
          : () async {
              final updated = await showEditRequestInfoSheet(
                context: context,
                ticket: ticket,
              );
              if (updated != null) onUpdated?.call(updated);
            },
    );
  }
}
