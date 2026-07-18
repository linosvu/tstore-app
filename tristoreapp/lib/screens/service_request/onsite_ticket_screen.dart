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

import 'repair_ticket_screen.dart';
import 'service_ui.dart';
import 'widgets/countdown_banner.dart';
import 'widgets/evidence_section.dart';
import 'widgets/locked_request_info_card.dart';
import 'widgets/signature_pad.dart';
import 'widgets/ticket_log_list.dart';

class OnsiteTicketScreen extends StatefulWidget {
  const OnsiteTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<OnsiteTicketScreen> createState() => _OnsiteTicketScreenState();
}

class _OnsiteTicketScreenState extends State<OnsiteTicketScreen> {
  ServiceTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  final _conditionCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();
  final _accessoriesCtrl = TextEditingController();
  String? _repairStaffId;
  List<(String, String)> _users = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _conditionCtrl.dispose();
    _workCtrl.dispose();
    _resultCtrl.dispose();
    _accessoriesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
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
        if (id != null && active) list.add((id, name.isEmpty ? id : name));
      }
    }
    if (mounted) {
      setState(() {
        _users = list;
        _repairStaffId ??= context.read<AuthProvider>().user?.id;
      });
    }
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
        if (t?.productCondition != null) {
          _conditionCtrl.text = t!.productCondition!;
        }
        if (t?.workDone != null) _workCtrl.text = t!.workDone!;
        if (t?.resultNote != null) _resultCtrl.text = t!.resultNote!;
        if (t?.accessoriesNote != null) {
          _accessoriesCtrl.text = t!.accessoriesNote!;
        }
        _loading = false;
      });
    } catch (_) {
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

  String? _closeBlockReason({required bool needWorkEvidence}) {
    final t = _ticket;
    if (t == null) return 'Đang tải phiếu…';
    final hasCondition = t.evidences.any((e) => e.stage == 'condition');
    final hasWork = t.evidences.any((e) => e.stage == 'work');
    final hasStaff = t.signatures.any(
      (s) => s.stage == 'onsite_result' && s.signer == 'staff',
    );
    final hasCustomer = t.signatures.any(
      (s) => s.stage == 'onsite_result' && s.signer == 'customer',
    );
    if (!hasCondition) return 'Cần bằng chứng tình trạng sản phẩm.';
    if (needWorkEvidence && !hasWork) {
      return 'Cần bằng chứng công việc đã làm.';
    }
    if (!hasStaff) return 'Cần chữ ký nhân viên.';
    if (!hasCustomer) return 'Cần chữ ký khách.';
    if (_conditionCtrl.text.trim().isEmpty) {
      return 'Nhập tình trạng sản phẩm.';
    }
    if (needWorkEvidence && _workCtrl.text.trim().isEmpty) {
      return 'Nhập công việc đã làm.';
    }
    return null;
  }

  Future<void> _completeOnsite() async {
    final block = _closeBlockReason(needWorkEvidence: true);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('complete-onsite', body: {
      'productCondition': _conditionCtrl.text.trim(),
      'workDone': _workCtrl.text.trim(),
      if (_resultCtrl.text.trim().isNotEmpty)
        'resultNote': _resultCtrl.text.trim(),
    });
  }

  Future<void> _failOnsite() async {
    final block = _closeBlockReason(needWorkEvidence: true);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('fail-onsite', body: {
      'productCondition': _conditionCtrl.text.trim(),
      'workDone': _workCtrl.text.trim(),
      if (_resultCtrl.text.trim().isNotEmpty)
        'resultNote': _resultCtrl.text.trim(),
    });
  }

  Future<void> _takeDevice() async {
    final block = _closeBlockReason(needWorkEvidence: false);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<ServiceRequestsProvider>().takeDevice(
        widget.ticketId,
        {
          'productCondition': _conditionCtrl.text.trim(),
          if (_accessoriesCtrl.text.trim().isNotEmpty)
            'accessoriesNote': _accessoriesCtrl.text.trim(),
          if (_workCtrl.text.trim().isNotEmpty)
            'workDone': _workCtrl.text.trim(),
          if (_repairStaffId != null) 'repairStaffUserId': _repairStaffId,
        },
      );
      if (!mounted) return;
      if (result != null) {
        setState(() => _ticket = result.onsite);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã nhận máy — mở phiếu sửa chữa.')),
        );
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => RepairTicketScreen(ticketId: result.repair.id),
          ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    final open = t?.status == 'processing';
    final userIds = _users.map((e) => e.$1).toList();
    final nameOf = {for (final u in _users) u.$1: u.$2};

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ?? l10n.serviceOnsiteTicket),
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
                const SizedBox(height: 8),
                CountdownBanner(
                  deadlineAt: t.deadlineAt,
                  isOverdue: t.isOverdue,
                ),
                const SizedBox(height: 12),
                if (t.request != null)
                  LockedRequestInfoCard(request: t.request!),
                const SizedBox(height: 12),
                EvidenceSection(
                  ticketId: t.id,
                  stage: 'condition',
                  evidences: t.evidences,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Bằng chứng tình trạng SP *',
                ),
                const SizedBox(height: 12),
                EvidenceSection(
                  ticketId: t.id,
                  stage: 'work',
                  evidences: t.evidences,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Bằng chứng công việc *',
                ),
                const SizedBox(height: 12),
                SignaturePadSection(
                  key: ValueKey('sig-${t.id}-onsite_result-staff'),
                  ticketId: t.id,
                  stage: 'onsite_result',
                  signer: 'staff',
                  signatures: t.signatures,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Chữ ký nhân viên *',
                ),
                const SizedBox(height: 8),
                SignaturePadSection(
                  key: ValueKey('sig-${t.id}-onsite_result-customer'),
                  ticketId: t.id,
                  stage: 'onsite_result',
                  signer: 'customer',
                  signatures: t.signatures,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Chữ ký khách *',
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Kết quả hỗ trợ tại nhà',
                  child: Column(
                    children: [
                      TextField(
                        controller: _conditionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tình trạng sản phẩm *',
                        ),
                        enabled: open,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _workCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Công việc đã làm *',
                        ),
                        enabled: open,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _resultCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.repairNotes,
                        ),
                        enabled: open,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _accessoriesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phụ kiện (khi nhận máy)',
                        ),
                        enabled: open,
                      ),
                    ],
                  ),
                ),
                if (open) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'NV sửa chữa (khi nhận máy)',
                    child: TsDropdownFieldNullable<String>(
                      value: _repairStaffId,
                      items: userIds,
                      itemLabel: (id) =>
                          id == null ? '—' : (nameOf[id] ?? id),
                      onChanged: (v) => setState(() => _repairStaffId = v),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final closeBlock =
                          _closeBlockReason(needWorkEvidence: true);
                      final takeBlock =
                          _closeBlockReason(needWorkEvidence: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (closeBlock != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              closeBlock,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy || closeBlock != null
                                ? null
                                : _completeOnsite,
                            child: const Text('Hoàn thành tại nhà'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _busy || closeBlock != null
                                ? null
                                : _failOnsite,
                            child: const Text('Không xử lý được'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _busy || takeBlock != null
                                ? null
                                : _takeDevice,
                            child: const Text('Nhận máy mang về (tạo SC)'),
                          ),
                        ],
                      );
                    },
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
