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

import 'contact_fail_reasons.dart';
import 'service_ui.dart';
import 'widgets/edit_request_info_sheet.dart';
import 'widgets/evidence_section.dart';
import 'widgets/onsite_cost_section.dart';
import 'widgets/searchable_user_dropdown.dart';
import 'widgets/signature_pad.dart';
import 'widgets/signature_thumb.dart';
import 'widgets/ticket_appointment_sla_header.dart';
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
  final _handlingNoteCtrl = TextEditingController();
  final _rescheduleSlotCtrl = TextEditingController(text: '09:00-11:00');
  final _rescheduleNoteCtrl = TextEditingController();
  DateTime _rescheduleDate = DateTime.now().add(const Duration(days: 1));
  List<(String, String)> _users = [];
  bool _resignStaff = false;
  bool _resignCustomer = false;

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
    _handlingNoteCtrl.dispose();
    _rescheduleSlotCtrl.dispose();
    _rescheduleNoteCtrl.dispose();
    super.dispose();
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
          final name = (e['fullName'] as String?)?.trim() ?? '';
          final active = e['isActive'] as bool? ?? true;
          if (id != null && active) {
            list.add((id, name.isEmpty ? id : name));
          }
        }
      }
      if (mounted) setState(() => _users = list);
    } catch (_) {}
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
        _handlingNoteCtrl.text = t?.note ?? '';
        final parsed = DateTime.tryParse(t?.appointmentDate ?? '');
        if (parsed != null) _rescheduleDate = parsed;
        final slot = (t?.appointmentSlot ?? '').trim();
        if (slot.isNotEmpty) _rescheduleSlotCtrl.text = slot;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canChangeAssignee(ServiceTicketPublic t) {
    final user = context.read<AuthProvider>().user;
    final role = user?.role;
    if (role == 'admin' || role == 'manager') return true;
    final uid = user?.id;
    if (uid == null || uid.isEmpty) return false;
    return t.staffUserId == uid;
  }

  bool get _isManager {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin' || role == 'manager';
  }

  bool _hasContactEvidence(ServiceTicketPublic t) =>
      t.evidences.any((e) => e.stage == 'contact');

  String _staffLabel(ServiceTicketPublic t) {
    final name = (t.staffName ?? '').trim();
    if (name.isNotEmpty) return name;
    return t.staffUserId.trim().isEmpty ? '—' : t.staffUserId;
  }

  Future<void> _changeAssignee(String staffUserId) async {
    if (_busy) return;
    final t = _ticket;
    if (t == null) return;
    if (staffUserId == t.staffUserId) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchTicketAssignee(widget.ticketId, staffUserId);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _ticket = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã đổi người phụ trách.')),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveHandlingNote() async {
    if (_busy) return;
    final t = _ticket;
    if (t == null) return;
    final next = _handlingNoteCtrl.text.trim();
    final prev = (t.note ?? '').trim();
    if (next == prev) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchTicketHandlingNote(
            widget.ticketId,
            next.isEmpty ? null : next,
          );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _ticket = updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã lưu ghi chú.')),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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

  String? _conditionBlockError() {
    final t = _ticket;
    if (t == null) return null;
    final hasCondition = t.evidences.any((e) => e.stage == 'condition');
    if (!hasCondition) return 'Cần bằng chứng tình trạng sản phẩm.';
    if (_conditionCtrl.text.trim().isEmpty) {
      return 'Nhập tình trạng sản phẩm.';
    }
    return null;
  }

  String? _workBlockError() {
    final t = _ticket;
    if (t == null) return null;
    final hasWork = t.evidences.any((e) => e.stage == 'work');
    if (!hasWork) return 'Cần bằng chứng công việc đã làm.';
    if (_workCtrl.text.trim().isEmpty) return 'Nhập công việc đã làm.';
    return null;
  }

  String? _costBlockError() {
    final t = _ticket;
    if (t == null) return null;
    if (t.costMode != 'free' && t.costMode != 'paid') {
      return 'Chọn và lưu chi phí (Miễn phí / Có tính phí).';
    }
    if (t.costMode == 'free' && (t.freeReason ?? '').isEmpty) {
      return 'Chọn lý do miễn phí.';
    }
    if (t.costMode == 'paid' && t.feeAmount <= 0) {
      return 'Tổng chi phí phải lớn hơn 0.';
    }
    if (t.costMode == 'paid' && (t.paymentMethod ?? '').isEmpty) {
      return 'Chọn hình thức thanh toán.';
    }
    return null;
  }

  String? _signatureBlockError() {
    final t = _ticket;
    if (t == null) return null;
    final hasStaff = t.signatures.any(
      (s) => s.stage == 'onsite_result' && s.signer == 'staff',
    );
    final hasCustomer = t.signatures.any(
      (s) => s.stage == 'onsite_result' && s.signer == 'customer',
    );
    if (!hasStaff) return 'Cần chữ ký nhân viên hỗ trợ.';
    if (!hasCustomer) return 'Cần chữ ký khách hàng.';
    return null;
  }

  String? _closeBlockReason({required bool requireCost}) {
    final t = _ticket;
    if (t == null) return 'Đang tải phiếu…';
    return _conditionBlockError() ??
        _workBlockError() ??
        (requireCost ? _costBlockError() : null) ??
        _signatureBlockError();
  }

  Future<void> _completeOnsite() async {
    final block = _closeBlockReason(requireCost: true);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('complete-onsite', body: {
      'productCondition': _conditionCtrl.text.trim(),
      'workDone': _workCtrl.text.trim(),
    });
  }

  Future<void> _failOnsite() async {
    final block = _closeBlockReason(requireCost: false);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('fail-onsite', body: {
      'productCondition': _conditionCtrl.text.trim(),
      'workDone': _workCtrl.text.trim(),
    });
  }

  Future<void> _promptContactFailed() async {
    final t = _ticket;
    if (t == null) return;
    if (!_hasContactEvidence(t)) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Cần thêm bằng chứng (ảnh tại địa chỉ hoặc ảnh log cuộc gọi) trước.',
          ),
        ),
      );
      return;
    }
    var contactedAt = DateTime.now();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Không gặp được khách'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cần bằng chứng tại địa chỉ hoặc ảnh log cuộc gọi ở khối '
                    '«Bằng chứng không gặp được».',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Thời điểm'),
                    subtitle:
                        Text(formatServiceTime(contactedAt.toIso8601String())),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: contactedAt,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 7),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d == null || !ctx.mounted) return;
                      final tm = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(contactedAt),
                      );
                      if (tm == null) return;
                      setLocal(() {
                        contactedAt = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          tm.hour,
                          tm.minute,
                        );
                      });
                    },
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
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
    if (go != true || !mounted) return;
    await _action(
      'contact-failed',
      body: {'contactedAt': contactedAt.toUtc().toIso8601String()},
    );
  }

  Future<void> _reschedule() async {
    final slot = _rescheduleSlotCtrl.text.trim();
    final note = _rescheduleNoteCtrl.text.trim();
    if (slot.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập khung giờ hẹn.')),
      );
      return;
    }
    if (note.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập ghi chú khi đặt lịch lại.')),
      );
      return;
    }
    await _action(
      'reschedule-online',
      body: {
        'appointmentDate': yyyyMmDd(_rescheduleDate),
        'appointmentSlot': slot,
        'note': note,
      },
    );
    if (mounted) _rescheduleNoteCtrl.clear();
  }

  Future<void> _failFromContactFailed() async {
    String selected = contactFailReasonCodes.first;
    final detailCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Thất bại — đóng phiếu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Chỉ quản lý quyết định đóng phiếu khi không gặp được khách.',
                    ),
                    const SizedBox(height: 12),
                    for (final code in contactFailReasonCodes)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(contactFailReasonLabel(code)),
                        value: code,
                        groupValue: selected,
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => selected = v);
                        },
                      ),
                    if (selected == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Chi tiết lý do *',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Xác nhận thất bại'),
                ),
              ],
            );
          },
        );
      },
    );
    final detail = detailCtrl.text.trim();
    detailCtrl.dispose();
    if (go != true || !mounted) return;
    if (selected == 'other' && detail.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập chi tiết lý do khi chọn «Khác».')),
      );
      return;
    }
    await _action(
      'fail-from-contact-failed',
      body: {
        'reasonCode': selected,
        if (detail.isNotEmpty) 'reasonDetail': detail,
      },
    );
  }

  Widget _inlineError(BuildContext context, String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }

  List<Widget> _signatureBlock(ServiceTicketPublic t, {required bool open}) {
    final staffSigs = t.signatures
        .where((s) => s.stage == 'onsite_result' && s.signer == 'staff')
        .toList();
    final customerSigs = t.signatures
        .where((s) => s.stage == 'onsite_result' && s.signer == 'customer')
        .toList();
    final bothSigned = staffSigs.isNotEmpty && customerSigs.isNotEmpty;

    if (bothSigned) {
      return [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SignatureThumb(
                      label: 'Nhân viên hỗ trợ',
                      url: staffSigs.last.imageUrl,
                      subtitle: staffSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(staffSigs.last.signedAt),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SignatureThumb(
                      label: 'Khách hàng',
                      url: customerSigs.last.imageUrl,
                      subtitle: customerSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(customerSigs.last.signedAt),
                    ),
                  ),
                ],
              ),
              if (open)
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _resignStaff = true),
                      child: const Text('Ký lại NV'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _resignCustomer = true),
                      child: const Text('Ký lại khách'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (open && _resignStaff) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-onsite_result-staff-resign'),
            ticketId: t.id,
            stage: 'onsite_result',
            signer: 'staff',
            signatures: const [],
            onChanged: () {
              setState(() => _resignStaff = false);
              _load();
            },
            readOnly: false,
            title: 'Ký lại — nhân viên hỗ trợ',
          ),
        ],
        if (open && _resignCustomer) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-onsite_result-customer-resign'),
            ticketId: t.id,
            stage: 'onsite_result',
            signer: 'customer',
            signatures: const [],
            onChanged: () {
              setState(() => _resignCustomer = false);
              _load();
            },
            readOnly: false,
            title: 'Ký lại — khách hàng',
          ),
        ],
      ];
    }

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SignaturePadSection(
              key: ValueKey('sig-${t.id}-onsite_result-staff'),
              ticketId: t.id,
              stage: 'onsite_result',
              signer: 'staff',
              signatures: t.signatures,
              onChanged: _load,
              readOnly: !open,
              title: 'Nhân viên hỗ trợ *',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SignaturePadSection(
              key: ValueKey('sig-${t.id}-onsite_result-customer'),
              ticketId: t.id,
              stage: 'onsite_result',
              signer: 'customer',
              signatures: t.signatures,
              onChanged: _load,
              readOnly: !open,
              title: 'Khách hàng *',
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    final open = t?.status == 'processing';
    final paused = t?.status == 'contact_failed';
    final canAssign = t != null && open && _canChangeAssignee(t) && !_busy;
    final canEditNote = t != null && open && _canChangeAssignee(t) && !_busy;
    final canContactFailed =
        t != null && open && _canChangeAssignee(t) && !_busy;
    final canReschedule =
        t != null && paused && _canChangeAssignee(t) && !_busy;
    final canFailFromPaused = t != null && paused && _isManager && !_busy;
    final usersForPicker = List<(String, String)>.from(_users);
    if (t != null) {
      final id = t.staffUserId.trim();
      if (id.isNotEmpty && !usersForPicker.any((u) => u.$1 == id)) {
        usersForPicker.insert(0, (id, _staffLabel(t)));
      }
    }
    final conditionErr = open ? _conditionBlockError() : null;
    final workErr = open ? _workBlockError() : null;
    final costErr = open ? _costBlockError() : null;
    final sigErr = open ? _signatureBlockError() : null;
    final closeBlock = open ? _closeBlockReason(requireCost: true) : null;
    final failBlock = open ? _closeBlockReason(requireCost: false) : null;

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
                if (t.contactFailedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Không gặp được khách: ${t.contactFailedCount} lần',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TicketAppointmentSlaHeader(
                  ticket: t,
                  canEdit: open &&
                      !_busy &&
                      canEditTicketRequestInfoFromContext(context, t),
                  onUpdated: (updated) {
                    setState(() => _ticket = updated);
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                SharedRequestInfoSection(
                  ticket: t,
                  canEdit: open && !_busy,
                  onUpdated: (updated) {
                    setState(() => _ticket = updated);
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Nhân viên hỗ trợ',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      canAssign
                          ? SearchableUserDropdown(
                              labelText: 'NV hỗ trợ *',
                              value: t.staffUserId.trim().isEmpty
                                  ? null
                                  : t.staffUserId,
                              users: usersForPicker,
                              onChanged: _changeAssignee,
                            )
                          : Text(
                              _staffLabel(t),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _handlingNoteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú của NV hỗ trợ',
                        ),
                        enabled: canEditNote,
                        maxLines: 3,
                        onEditingComplete:
                            canEditNote ? _saveHandlingNote : null,
                      ),
                      if (canEditNote) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _saveHandlingNote,
                            child: const Text('Lưu ghi chú'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (open || paused) ...[
                  const SizedBox(height: 12),
                  EvidenceSection(
                    ticketId: t.id,
                    stage: 'contact',
                    evidences: t.evidences,
                    onChanged: _load,
                    readOnly: !open,
                    title: 'Bằng chứng không gặp được',
                  ),
                ],
                if (open) ...[
                  const SizedBox(height: 12),
                  EvidenceSection(
                    ticketId: t.id,
                    stage: 'condition',
                    evidences: t.evidences,
                    onChanged: _load,
                    readOnly: !open,
                    title: 'Bằng chứng tình trạng SP *',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _conditionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tình trạng sản phẩm *',
                    ),
                    enabled: open,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                  _inlineError(context, conditionErr),
                  const SizedBox(height: 12),
                  EvidenceSection(
                    ticketId: t.id,
                    stage: 'work',
                    evidences: t.evidences,
                    onChanged: _load,
                    readOnly: !open,
                    title: 'Bằng chứng công việc *',
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
                  _inlineError(context, workErr),
                  const SizedBox(height: 12),
                  OnsiteCostSection(
                    ticket: t,
                    readOnly: !open,
                    onUpdated: (updated) {
                      setState(() => _ticket = updated);
                      _load();
                    },
                  ),
                  _inlineError(context, costErr),
                  const SizedBox(height: 12),
                  ..._signatureBlock(t, open: open),
                  _inlineError(context, sigErr),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _busy || closeBlock != null ? null : _completeOnsite,
                    child: const Text('Hoàn thành tại nhà'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed:
                        _busy || failBlock != null ? null : _failOnsite,
                    child: const Text('Không xử lý được'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đã gặp khách, đã kiểm tra, nhưng không xử lý được tại chỗ. '
                    'Nếu cần mang máy về sửa: đóng phiếu này rồi tạo phiếu SC mới.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed:
                        !canContactFailed ? null : _promptContactFailed,
                    child: const Text('Không gặp được khách'),
                  ),
                ],
                if (!open && !paused) ...[
                  const SizedBox(height: 12),
                  OnsiteCostSection(
                    ticket: t,
                    readOnly: true,
                    onUpdated: (_) {},
                  ),
                  const SizedBox(height: 12),
                  ..._signatureBlock(t, open: false),
                ],
                if (paused) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Chọn lịch hẹn mới',
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ngày hẹn *'),
                          subtitle: Text(yyyyMmDd(_rescheduleDate)),
                          trailing: const Icon(Icons.calendar_today),
                          enabled: canReschedule,
                          onTap: !canReschedule
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _rescheduleDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() => _rescheduleDate = picked);
                                  }
                                },
                        ),
                        TextField(
                          controller: _rescheduleSlotCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Khung giờ hẹn *',
                          ),
                          enabled: canReschedule,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _rescheduleNoteCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú *',
                          ),
                          maxLines: 2,
                          enabled: canReschedule,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: canReschedule ? _reschedule : null,
                          child: const Text('Đặt lịch & tiếp tục xử lý'),
                        ),
                      ],
                    ),
                  ),
                  if (_isManager) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          canFailFromPaused ? _failFromContactFailed : null,
                      child: const Text('Thất bại'),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                TicketLogList(logs: t.logs),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
