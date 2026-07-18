import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

import 'escalate_ticket_screen.dart';
import 'service_ui.dart';
import 'widgets/countdown_banner.dart';
import 'widgets/locked_request_info_card.dart';
import 'widgets/ticket_log_list.dart';

class OnlineTicketScreen extends StatefulWidget {
  const OnlineTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<OnlineTicketScreen> createState() => _OnlineTicketScreenState();
}

class _OnlineTicketScreenState extends State<OnlineTicketScreen> {
  ServiceTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  final _guideCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _guideCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .fetchTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        if (t?.guideContent != null) _guideCtrl.text = t!.guideContent!;
        if (t?.note != null) _noteCtrl.text = t!.note!;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _escalate() async {
    final t = _ticket;
    if (t == null) return;
    await Navigator.push<ServiceTicketPublic>(
      context,
      MaterialPageRoute(
        builder: (_) => EscalateTicketScreen(
          requestId: t.requestId,
          previousTicketId: t.id,
          suggestedType: 'onsite',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    final open = t?.status == 'processing';

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ?? l10n.serviceOnlineTicket),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading || t == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: ticketStatusLabel(t.type, t.status),
                      tone: ticketStatusTone(t.status),
                    ),
                    const Spacer(),
                    Text(ticketTypeLabel(t.type)),
                  ],
                ),
                const SizedBox(height: 8),
                CountdownBanner(
                  deadlineAt: t.deadlineAt,
                  isOverdue: t.isOverdue,
                ),
                const SizedBox(height: 12),
                if (t.request != null) LockedRequestInfoCard(request: t.request!),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Hướng dẫn / xử lý',
                  child: Column(
                    children: [
                      TextField(
                        controller: _guideCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung hướng dẫn',
                        ),
                        minLines: 3,
                        maxLines: 6,
                        enabled: open,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteCtrl,
                        decoration: InputDecoration(labelText: l10n.repairNotes),
                        maxLines: 2,
                        enabled: open,
                      ),
                    ],
                  ),
                ),
                if (open) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _action('complete-online', body: {
                              'guideContent': _guideCtrl.text.trim(),
                              if (_noteCtrl.text.trim().isNotEmpty)
                                'note': _noteCtrl.text.trim(),
                            }),
                    child: const Text('Xử lý xong'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _action('fail-online', body: {
                              if (_guideCtrl.text.trim().isNotEmpty)
                                'guideContent': _guideCtrl.text.trim(),
                              if (_noteCtrl.text.trim().isNotEmpty)
                                'note': _noteCtrl.text.trim(),
                            }),
                    child: const Text('Thất bại — leo thang'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final r = await promptReason(
                              context,
                              title: 'Lý do hủy (không liên lạc được)',
                            );
                            if (r != null) {
                              await _action('cancel-online', body: {'reason': r});
                            }
                          },
                    child: const Text('Hủy phiếu'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _escalate,
                    child: Text(l10n.serviceEscalate),
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
