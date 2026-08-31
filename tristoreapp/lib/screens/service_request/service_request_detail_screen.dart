import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'online_ticket_screen.dart';
import 'onsite_ticket_screen.dart';
import 'other_ticket_screen.dart';
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
  List<(String, String)> _users = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _load();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get<Map<String, dynamic>>(
        '/admin/users',
        queryParameters: {'page': 1, 'limit': 100},
      );
      final items = res.data?['items'];
      final list = <(String, String)>[];
      if (items is List) {
        for (final e in items) {
          if (e is! Map<String, dynamic>) continue;
          final id = e['id'] as String?;
          final name = e['fullName'] as String? ?? '';
          final active = e['isActive'] as bool? ?? true;
          if (id != null && active) {
            list.add((id, name.isEmpty ? id : name));
          }
        }
      }
      if (mounted) setState(() => _users = list);
    } catch (_) {
      /* dropdown optional */
    }
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
    final Widget screen = switch (t.type) {
      'online' => OnlineTicketScreen(ticketId: t.id),
      'onsite' => OnsiteTicketScreen(ticketId: t.id),
      'other' => OtherTicketScreen(ticketId: t.id),
      'repair' => RepairTicketScreen(ticketId: t.id),
      _ => OnlineTicketScreen(ticketId: t.id),
    };
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
    final isRepair = item.isRepairDirection;
    final reason = await promptReason(
      context,
      title: isRepair ? 'Lý do hủy yêu cầu SC' : 'Lý do hủy hỗ trợ',
    );
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
          SnackBar(
            content: Text(isRepair ? 'Đã hủy yêu cầu SC.' : 'Đã hủy hỗ trợ.'),
          ),
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

  Future<void> _changeManager(String? managerUserId) async {
    final item = _item;
    if (item == null || managerUserId == null || _busy) return;
    if (managerUserId == item.managerUserId) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchRequest(item.id, {'managerUserId': managerUserId});
      if (updated != null && mounted) {
        setState(() => _item = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã cập nhật nhân viên quản lý.')),
        );
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

  IconData _ticketIcon(String type) {
    switch (type) {
      case 'repair':
        return Icons.build_outlined;
      case 'onsite':
        return Icons.home_outlined;
      case 'other':
        return Icons.more_horiz;
      default:
        return Icons.headset_mic_outlined;
    }
  }

  bool get _canEditManager {
    final item = _item;
    if (item == null) return false;
    return item.status != 'completed' && item.status != 'cancelled';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _item;
    final userIds = _users.map((e) => e.$1).toList();
    final nameOf = {for (final u in _users) u.$1: u.$2};

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
                            title: 'Thông tin yêu cầu',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Người tạo: ${item.createdByName?.trim().isNotEmpty == true ? item.createdByName! : '—'}',
                                ),
                                Text(
                                  'Hướng: ${item.isRepairDirection ? 'Sửa chữa' : 'Hỗ trợ'}',
                                ),
                                Text('Kênh: ${channelLabel(item.channel)}'),
                                const SizedBox(height: 8),
                                Text(
                                  'Khách: ${item.customerName}',
                                ),
                                Text('SĐT: ${item.customerPhone}'),
                                if (item.customerAddress != null &&
                                    item.customerAddress!.isNotEmpty)
                                  Text('Địa chỉ: ${item.customerAddress}'),
                                if (item.customerNote != null &&
                                    item.customerNote!.isNotEmpty)
                                  Text('Ghi chú: ${item.customerNote}'),
                                if (item.buyerName != null &&
                                    item.buyerName!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Người mua: ${item.buyerName}'),
                                  if (item.buyerPhone != null &&
                                      item.buyerPhone!.isNotEmpty)
                                    Text('SĐT mua: ${item.buyerPhone}'),
                                  if (item.buyerAddress != null &&
                                      item.buyerAddress!.isNotEmpty)
                                    Text('Địa chỉ mua: ${item.buyerAddress}'),
                                ],
                                const SizedBox(height: 8),
                                Text('SP: ${item.productName}'),
                                if (item.productSerial != null)
                                  Text('Serial: ${item.productSerial}'),
                                Text('Lỗi: ${item.issueDescription}'),
                                if (item.supportStaffName != null)
                                  Text(
                                    item.isRepairDirection
                                        ? '${l10n.serviceRepairStaff}: ${item.supportStaffName}'
                                        : '${l10n.serviceFilterSupportStaff}: ${item.supportStaffName}',
                                  ),
                                if (item.cancelReason != null)
                                  Text(
                                    'Huỷ: ${item.cancelReason}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nhân viên quản lý',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                if (_canEditManager)
                                  TsDropdownFieldNullable<String>(
                                    value: item.managerUserId,
                                    items: userIds.isEmpty &&
                                            item.managerUserId != null
                                        ? [item.managerUserId!]
                                        : userIds,
                                    itemLabel: (id) {
                                      if (id == null) return '—';
                                      return nameOf[id] ??
                                          (id == item.managerUserId
                                              ? (item.managerName ?? id)
                                              : id);
                                    },
                                    onChanged: _busy
                                        ? null
                                        : (v) => _changeManager(v),
                                  )
                                else
                                  Text(item.managerName ?? '—'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: item.tickets.length <= 1
                                ? 'Phiếu xử lý'
                                : 'Phiếu xử lý (${item.tickets.length})',
                            child: item.tickets.isEmpty
                                ? const Text('Chưa có phiếu xử lý.')
                                : Column(
                                    children: [
                                      for (final t in item.tickets)
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(_ticketIcon(t.type)),
                                          title: Text(
                                            '${t.displayCode} · ${ticketTypeLabel(t.type)}',
                                          ),
                                          subtitle: Text(
                                            'KTV phụ trách: ${t.technicianName ?? t.staffName ?? '—'}'
                                            '${t.appointmentDate != null && t.appointmentDate!.isNotEmpty ? ' · ${t.appointmentDate}' : ''}',
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
                              child: Text(
                                item.isRepairDirection
                                    ? 'Huỷ yêu cầu SC'
                                    : l10n.serviceCancelRequest,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}
