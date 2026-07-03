import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/repair_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/providers/repair_orders_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_status_dropdown_field.dart';

import 'repair_ui.dart';

class RepairOrderDetailScreen extends StatefulWidget {
  const RepairOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<RepairOrderDetailScreen> createState() => _RepairOrderDetailScreenState();
}

class _RepairOrderDetailScreenState extends State<RepairOrderDetailScreen> {
  RepairOrderPublic? _order;
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
        _staff = [
          for (final u in list) (id: u.id, name: u.name),
        ];
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await context.read<RepairOrdersProvider>().fetchOne(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = o;
        _loading = false;
        if (o == null) _error = 'Không tìm thấy đơn sửa chữa.';
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
    if (_order == null || _busy) return;
    if (status == 'cancelled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hủy đơn sửa chữa?'),
          content: const Text('Xác nhận chuyển trạng thái sang Đã hủy.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hủy đơn')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final updated = await context.read<RepairOrdersProvider>().patchStatus(
            widget.orderId,
            status,
          );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _order = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã cập nhật trạng thái.')),
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

  Future<void> _assign(String? userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<RepairOrdersProvider>().assign(
            widget.orderId,
            userId,
          );
      if (!mounted) return;
      if (updated != null) setState(() => _order = updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<RepairOrdersProvider>().addNote(
            widget.orderId,
            text,
          );
      if (!mounted) return;
      if (updated != null) {
        _noteCtrl.clear();
        setState(() => _order = updated);
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
        title: Text(_order?.displayCode != null ? '#${_order!.displayCode}' : l10n.ordersSubTabRepair),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _order == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                        children: [
                          SectionCard(
                            title: l10n.repairCustomerName,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (_order!.customer?.isVip == true) ...[
                                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFA000)),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _order!.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    StatusBadge(
                                      label: repairStatusLabel(_order!.status, l10n),
                                      tone: repairStatusTone(_order!.status),
                                    ),
                                  ],
                                ),
                                if (_order!.customerPhone != null)
                                  Row(
                                    children: [
                                      Expanded(child: Text(_order!.customerPhone!)),
                                      IconButton(
                                        icon: const Icon(Icons.copy_outlined),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: _order!.customerPhone!),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: l10n.repairItemDescription,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_order!.itemDescription),
                                const SizedBox(height: 8),
                                Text(
                                  _order!.issueDescription,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('${l10n.repairNotes}: ${_order!.notes}'),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '${l10n.repairReceivedDate}: ${_order!.receivedDate ?? '—'} · '
                                  '${l10n.repairPromisedDate}: ${_order!.promisedDate ?? '—'}',
                                ),
                                if (_order!.isOverdue)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: StatusBadge(
                                      label: 'Quá hạn trả',
                                      tone: StatusBadgeTone.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SectionCard(
                            title: l10n.repairStatus,
                            child: TsStatusDropdownField(
                              caption: l10n.repairStatus,
                              value: _order!.status,
                              options: repairStatuses,
                              labelFor: (s) => repairStatusLabel(s, l10n),
                              onChanged: _busy
                                  ? null
                                  : (v) {
                                      if (v != null && v != _order!.status) {
                                        _changeStatus(v);
                                      }
                                    },
                            ),
                          ),
                          if (_staff.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SectionCard(
                              title: 'Phân công',
                              child: DropdownButtonFormField<String?>(
                                value: _order!.assignedUserId,
                                decoration: const InputDecoration(labelText: 'Kỹ thuật viên'),
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
                          SectionCard(
                            title: 'Hoạt động',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                activityTimeline(
                                  items: _order!.activityLog,
                                  contentOf: (a) => a.content,
                                  timeOf: (a) => formatActivityTime(a.createdAt),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _noteCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Thêm ghi chú...',
                                  ),
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
