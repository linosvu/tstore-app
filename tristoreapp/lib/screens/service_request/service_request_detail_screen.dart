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
import 'online_ticket_screen.dart';
import 'onsite_ticket_screen.dart';
import 'repair_ticket_screen.dart';
import 'service_ui.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends State<ServiceRequestDetailScreen> {
  ServiceRequestPublic? _item;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await context
          .read<ServiceRequestsProvider>()
          .fetchRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _error = item == null ? 'Không tải được phiếu.' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openTicket(ServiceTicketBrief t) {
    Widget screen;
    switch (t.type) {
      case 'online':
        screen = OnlineTicketScreen(ticketId: t.id);
      case 'onsite':
        screen = OnsiteTicketScreen(ticketId: t.id);
      case 'repair':
        screen = RepairTicketScreen(ticketId: t.id);
      default:
        screen = OnlineTicketScreen(ticketId: t.id);
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    ).then((_) => _load());
  }

  Future<void> _complete() async {
    final item = _item;
    if (item == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .completeRequest(item.id);
      if (updated != null && mounted) {
        setState(() => _item = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã hoàn tất yêu cầu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final item = _item;
    if (item == null || _busy) return;
    final reason = await promptReason(context, title: 'Lý do hủy yêu cầu');
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .cancelRequest(item.id, reason);
      if (updated != null && mounted) {
        setState(() => _item = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã hủy yêu cầu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _escalate() async {
    final item = _item;
    if (item == null) return;
    final prev = item.latestTicket;
    final created = await Navigator.push<ServiceTicketPublic>(
      context,
      MaterialPageRoute(
        builder: (_) => EscalateTicketScreen(
          requestId: item.id,
          previousTicketId: prev?.id,
          suggestedType: prev?.type == 'online'
              ? 'onsite'
              : prev?.type == 'onsite'
                  ? 'repair'
                  : 'repair',
        ),
      ),
    );
    if (created != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item?.displayCode ?? l10n.serviceRequestDetail),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error ?? '—'))
              : item == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(
                          AppSpacing.screenHorizontal,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.displayCode,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              StatusBadge(
                                label: requestStatusLabel(item.status),
                                tone: requestStatusTone(item.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: 'Thông tin khách / sản phẩm',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kênh: ${channelLabel(item.channel)}'),
                                Text('Khách: ${item.customerName}'),
                                Text('SĐT: ${item.customerPhone}'),
                                if (item.customerPhone2 != null)
                                  Text('SĐT 2: ${item.customerPhone2}'),
                                if (item.customerAddress != null)
                                  Text('Địa chỉ: ${item.customerAddress}'),
                                Text('SP: ${item.productName}'),
                                if (item.productSerial != null)
                                  Text('Serial: ${item.productSerial}'),
                                Text('Lỗi: ${item.issueDescription}'),
                                if (item.managerName != null)
                                  Text('QL: ${item.managerName}'),
                                if (item.cancelReason != null)
                                  Text(
                                    'Huỷ: ${item.cancelReason}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: 'Phiếu con (${item.tickets.length})',
                            titleTrailing: item.status != 'completed' &&
                                    item.status != 'cancelled'
                                ? TextButton(
                                    onPressed: _escalate,
                                    child: Text(l10n.serviceEscalate),
                                  )
                                : null,
                            child: item.tickets.isEmpty
                                ? const Text('Chưa có phiếu con.')
                                : Column(
                                    children: [
                                      for (final t in item.tickets)
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            t.type == 'repair'
                                                ? Icons.build_outlined
                                                : t.type == 'onsite'
                                                    ? Icons.home_outlined
                                                    : Icons.headset_mic_outlined,
                                          ),
                                          title: Text(
                                            '${t.displayCode} · ${ticketTypeLabel(t.type)}',
                                          ),
                                          subtitle: Text(
                                            '${t.staffName ?? '—'} · ${t.appointmentDate ?? ''}',
                                          ),
                                          trailing: StatusBadge(
                                            label: ticketStatusLabel(
                                              t.type,
                                              t.status,
                                            ),
                                            tone: ticketStatusTone(t.status),
                                          ),
                                          onTap: () => _openTicket(t),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          if (item.status != 'completed' &&
                              item.status != 'cancelled') ...[
                            if (item.canComplete)
                              FilledButton(
                                onPressed: _busy ? null : _complete,
                                child: Text(l10n.serviceCompleteRequest),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _busy ? null : _cancel,
                              child: Text(l10n.serviceCancelRequest),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}
