import 'package:flutter/material.dart';

import '../../../../models/service_request.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import '../evidence_section.dart';
import '../../service_ui.dart';

/// Card hạn xử lý + lịch sử dời hạn (SC v3).
class RepairDeadlineCard extends StatelessWidget {
  const RepairDeadlineCard({
    super.key,
    required this.ticketId,
    required this.deadlineAt,
    required this.deadlineChanges,
    required this.evidences,
    required this.readOnly,
    required this.onExtend,
    required this.onReload,
  });

  final String ticketId;
  final String? deadlineAt;
  final List<DeadlineChangePublic> deadlineChanges;
  final List<TicketEvidencePublic> evidences;
  final bool readOnly;
  final VoidCallback onExtend;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final label = deadlineRemainingLabel(deadlineAt, markOverdue: true);
    return SectionCard(
      title: 'Hạn xử lý',
      titleTrailing: readOnly
          ? null
          : TextButton(onPressed: onExtend, child: const Text('Sửa hạn')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.isEmpty ? 'Chưa đặt hạn' : label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: label.contains('Quá hạn')
                  ? Colors.red.shade700
                  : Colors.amber.shade900,
            ),
          ),
          if (deadlineChanges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Đã dời hạn ${deadlineChanges.length} lần',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            for (final c in deadlineChanges) ...[
              const Divider(height: 16),
              Text(
                '→ ${c.newDeadline}',
                style: const TextStyle(fontSize: 13),
              ),
              if ((c.contactNote ?? '').trim().isNotEmpty)
                Text(c.contactNote!, style: const TextStyle(fontSize: 12)),
              if (c.staffName != null)
                Text(
                  '${c.staffName} · ${c.createdAt ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet dời hạn — caller uploads evidence `deadline_call` trước khi gọi API.
class RepairExtendDeadlineSheet extends StatefulWidget {
  const RepairExtendDeadlineSheet({
    super.key,
    required this.ticketId,
    required this.evidences,
    required this.onSaved,
    required this.onReload,
  });

  final String ticketId;
  final List<TicketEvidencePublic> evidences;
  final Future<void> Function(DateTime newDeadline, String? note) onSaved;
  final VoidCallback onReload;

  @override
  State<RepairExtendDeadlineSheet> createState() =>
      _RepairExtendDeadlineSheetState();
}

class _RepairExtendDeadlineSheetState extends State<RepairExtendDeadlineSheet> {
  DateTime _newDeadline = DateTime.now().add(const Duration(hours: 4));
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  bool get _hasEvidence =>
      widget.evidences.any((e) => e.stage == 'deadline_call');

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sửa hạn xử lý',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hạn mới *'),
            subtitle: Text(_newDeadline.toLocal().toString()),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final d0 = await showDatePicker(
                context: context,
                initialDate: _newDeadline,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (d0 == null || !mounted) return;
              final tm = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_newDeadline),
              );
              if (tm == null) return;
              setState(() {
                _newDeadline = DateTime(
                  d0.year,
                  d0.month,
                  d0.day,
                  tm.hour,
                  tm.minute,
                );
              });
            },
          ),
          EvidenceSection(
            ticketId: widget.ticketId,
            stage: 'deadline_call',
            evidences: widget.evidences,
            onChanged: widget.onReload,
            title: 'Bằng chứng gọi khách *',
          ),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú liên hệ'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !_hasEvidence || _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSaved(
                      _newDeadline,
                      _noteCtrl.text.trim().isEmpty
                          ? null
                          : _noteCtrl.text.trim(),
                    );
                    if (mounted) Navigator.pop(context);
                  },
            child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
