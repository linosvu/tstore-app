import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

import 'service_ui.dart';
import 'widgets/evidence_section.dart';
import 'widgets/locked_request_info_card.dart';
import 'widgets/ticket_log_list.dart';

/// Hỗ trợ khác — luồng tối giản: đang xử lý → xong / hủy.
class OtherTicketScreen extends StatefulWidget {
  const OtherTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<OtherTicketScreen> createState() => _OtherTicketScreenState();
}

class _OtherTicketScreenState extends State<OtherTicketScreen> {
  ServiceTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = false}) async {
    if (showSpinner || _ticket == null) {
      setState(() => _loading = true);
    }
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .fetchTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        if (t?.note != null) _noteCtrl.text = t!.note!;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
        );
      }
    }
  }

  Future<void> _action(String action, {Map<String, dynamic>? body}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .ticketAction(widget.ticketId, action, body: body);
      if (updated != null && mounted) {
        setState(() => _ticket = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã cập nhật.')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final open = t?.status == 'processing';

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ?? 'Hỗ trợ khác'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading || t == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                StatusBadge(
                  label: ticketStatusLabel(t.type, t.status),
                  tone: ticketStatusTone(t.status),
                ),
                const SizedBox(height: 12),
                if (t.request != null)
                  LockedRequestInfoCard(request: t.request!),
                const SizedBox(height: 12),
                EvidenceSection(
                  ticketId: t.id,
                  stage: 'work',
                  evidences: t.evidences,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Bằng chứng (tuỳ chọn)',
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Ghi chú',
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung hỗ trợ / ghi chú',
                    ),
                    maxLines: 3,
                    enabled: open,
                  ),
                ),
                if (open) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _action(
                              'complete-other',
                              body: {
                                if (_noteCtrl.text.trim().isNotEmpty)
                                  'note': _noteCtrl.text.trim(),
                              },
                            ),
                    child: const Text('Xử lý xong'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final r = await promptReason(
                              context,
                              title: 'Lý do hủy hỗ trợ khác',
                            );
                            if (r != null) {
                              await _action(
                                'cancel-other',
                                body: {'reason': r},
                              );
                            }
                          },
                    child: const Text('Hủy phiếu'),
                  ),
                ],
                const SizedBox(height: 12),
                TicketLogList(logs: t.logs),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
