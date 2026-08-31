import 'package:flutter/material.dart';

import '../../../../models/service_request.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import '../evidence_section.dart';
import '../../service_ui.dart';

/// Card hạn xử lý + lịch sử dời hạn (SC v3).
class RepairDeadlineCard extends StatefulWidget {
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
  State<RepairDeadlineCard> createState() => _RepairDeadlineCardState();
}

class _RepairDeadlineCardState extends State<RepairDeadlineCard> {
  bool _historyExpanded = false;

  List<TicketEvidencePublic> get _deadlineEvidences => widget.evidences
      .where((e) => e.stage == 'deadline_call')
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final changes = widget.deadlineChanges;

    return SectionCard(
      title: 'Hạn xử lý',
      titleTrailing: widget.readOnly
          ? null
          : TextButton(onPressed: widget.onExtend, child: const Text('Sửa hạn')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.deadlineAt != null)
            Text(
              formatServiceTime(widget.deadlineAt),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            const Text(
              'Chưa đặt hạn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _historyExpanded = !_historyExpanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đã dời hạn ${changes.length} lần',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Icon(
                    _historyExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            if (_historyExpanded)
              for (final c in changes) ...[
                const Divider(height: 16),
                Text(
                  c.oldDeadline != null
                      ? '${formatServiceTime(c.oldDeadline)} → ${formatServiceTime(c.newDeadline)}'
                      : '→ ${formatServiceTime(c.newDeadline)}',
                  style: const TextStyle(fontSize: 13),
                ),
                if ((c.contactNote ?? '').trim().isNotEmpty)
                  Text(c.contactNote!, style: const TextStyle(fontSize: 12)),
                if (c.staffName != null)
                  Text(
                    '${c.staffName} · ${formatServiceTime(c.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
          ],
          if (_deadlineEvidences.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Bằng chứng gọi khách',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _deadlineEvidences.length; i++)
                  MediaTile(
                    url: _deadlineEvidences[i].fileUrl,
                    mediaType: _deadlineEvidences[i].kind,
                    width: 56,
                    height: 56,
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerPage(
                            items: [
                              for (final e in _deadlineEvidences)
                                MediaViewerItem(
                                  url: e.fileUrl,
                                  mediaType: e.kind,
                                ),
                            ],
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
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
            subtitle: Text(formatServiceTime(_newDeadline.toIso8601String())),
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
            title: 'Bằng chứng gọi khách',
          ),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú liên hệ'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving
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
