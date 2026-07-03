import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/support_ticket.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/providers/support_tickets_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_status_dropdown_field.dart';

import '../repair/repair_order_detail_screen.dart';
import '../repair/repair_ui.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<SupportTicketDetailScreen> createState() => _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  SupportTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _noteCtrl = TextEditingController();
  List<({String id, String name})> _staff = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadStaff();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    try {
      final mgmt = ManagementProvider(api: context.read<AuthProvider>().api);
      final list = await mgmt.fetchStaffUsers();
      if (!mounted) return;
      setState(() {
        _staff = [for (final u in list) (id: u.id, name: u.name)];
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await context.read<SupportTicketsProvider>().fetchOne(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _loading = false;
        if (t == null) _error = 'Không tìm thấy ticket.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_ticket == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<SupportTicketsProvider>().patchStatus(
            widget.ticketId,
            status,
          );
      if (!mounted) return;
      if (updated != null) setState(() => _ticket = updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(String? userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<SupportTicketsProvider>().patch(
            widget.ticketId,
            {'assignedUserId': userId},
          );
      if (!mounted) return;
      if (updated != null) setState(() => _ticket = updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<SupportTicketsProvider>().addNote(
            widget.ticketId,
            text,
          );
      if (!mounted) return;
      if (updated != null) {
        _noteCtrl.clear();
        setState(() => _ticket = updated);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convertToRepair() async {
    if (_ticket == null || _busy) return;
    if (_ticket!.repairOrderId != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RepairOrderDetailScreen(orderId: _ticket!.repairOrderId!),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<SupportTicketsProvider>().convertToRepair(
            widget.ticketId,
          );
      if (!mounted || result == null) return;
      setState(() => _ticket = result.ticket);
      final repairId = result.repairOrder['id'] as String?;
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Đã chuyển thành đơn sửa chữa.')),
      );
      if (repairId != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RepairOrderDetailScreen(orderId: repairId),
          ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket?.ticketCode ?? l10n.supportTicketsNav),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _ticket == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                        children: [
                          SectionCard(
                            title: _ticket!.subject,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(_ticket!.customerName)),
                                    StatusBadge(
                                      label: supportStatusLabel(_ticket!.status),
                                      tone: supportStatusTone(_ticket!.status),
                                    ),
                                  ],
                                ),
                                if (_ticket!.customerPhone != null)
                                  Text(_ticket!.customerPhone!),
                                const SizedBox(height: 8),
                                Text(_ticket!.description),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    StatusBadge(
                                      label: supportCategoryLabel(_ticket!.category),
                                      tone: StatusBadgeTone.neutral,
                                    ),
                                    StatusBadge(
                                      label: repairPriorityLabel(_ticket!.priority, l10n),
                                      tone: repairPriorityTone(_ticket!.priority),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: l10n.repairStatus,
                            child: TsStatusDropdownField(
                              caption: l10n.repairStatus,
                              value: _ticket!.status,
                              options: supportTicketStatuses,
                              labelFor: supportStatusLabel,
                              enabled: !_busy,
                              onChanged: (v) {
                                if (v != null && v != _ticket!.status) _changeStatus(v);
                              },
                            ),
                          ),
                          if (_staff.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SectionCard(
                              title: 'Phân công',
                              child: DropdownButtonFormField<String?>(
                                value: _ticket!.assignedUserId,
                                decoration: const InputDecoration(labelText: 'Nhân viên xử lý'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('— Chưa phân công —'),
                                  ),
                                  for (final s in _staff)
                                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                                ],
                                onChanged: _busy ? null : _assign,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _convertToRepair,
                            icon: const Icon(Icons.build_outlined),
                            label: Text(
                              _ticket!.repairOrderId != null
                                  ? l10n.supportViewRepairOrder
                                  : l10n.supportConvertToRepair,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: 'Hoạt động',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                activityTimeline(
                                  items: _ticket!.activityLog,
                                  contentOf: (a) => a.content,
                                  timeOf: (a) => formatActivityTime(a.createdAt),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _noteCtrl,
                                  decoration: const InputDecoration(hintText: 'Thêm ghi chú...'),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _addNote,
                                    child: const Text('Ghi chú'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
