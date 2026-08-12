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

import 'service_ui.dart';
import 'contact_fail_reasons.dart';
import 'widgets/edit_request_info_sheet.dart';
import 'widgets/evidence_section.dart';
import 'widgets/searchable_user_dropdown.dart';
import 'widgets/ticket_appointment_sla_header.dart';
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
  List<(String, String)> _users = [];
  final _guideCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _rescheduleSlotCtrl = TextEditingController(text: '09:00-11:00');
  final _rescheduleNoteCtrl = TextEditingController();
  DateTime _rescheduleDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _load();
    });
  }

  @override
  void dispose() {
    _guideCtrl.dispose();
    _noteCtrl.dispose();
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
    } catch (_) {
      // Keep empty; assignee still shown from ticket.staffName.
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
        if (t?.guideContent != null) _guideCtrl.text = t!.guideContent!;
        if (t?.note != null) _noteCtrl.text = t!.note!;
        final parsed = DateTime.tryParse(t?.appointmentDate ?? '');
        if (parsed != null) _rescheduleDate = parsed;
        final slot = (t?.appointmentSlot ?? '').trim();
        if (slot.isNotEmpty) _rescheduleSlotCtrl.text = slot;
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

  bool get _hasContactEvidence =>
      _ticket?.evidences.any((e) => e.stage == 'contact') ?? false;

  String? _completeBlockReason({required bool requireGuide}) {
    final staffId = (_ticket?.staffUserId ?? '').trim();
    if (staffId.isEmpty) {
      return 'Chọn nhân viên kỹ thuật phụ trách.';
    }
    if (!_hasContactEvidence) {
      return 'Cần thêm bằng chứng liên hệ (ảnh/video/ghi âm).';
    }
    if (requireGuide && _guideCtrl.text.trim().isEmpty) {
      return 'Nhập nội dung đã hướng dẫn.';
    }
    return null;
  }

  bool _canChangeAssignee(ServiceTicketPublic t) {
    final user = context.read<AuthProvider>().user;
    final role = user?.role;
    if (role == 'admin' || role == 'manager') return true;
    final uid = user?.id;
    if (uid == null || uid.isEmpty) return false;
    return t.staffUserId == uid;
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

  Future<void> _complete() async {
    final block = _completeBlockReason(requireGuide: true);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('complete-online', body: {
      'guideContent': _guideCtrl.text.trim(),
      if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
    });
  }

  Future<void> _fail() async {
    final block = _completeBlockReason(requireGuide: true);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('fail-online', body: {
      'guideContent': _guideCtrl.text.trim(),
      if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
    });
  }

  Future<void> _promptContactFailed() async {
    if (!_hasContactEvidence) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(
          content: Text(
            'Cần thêm bằng chứng liên hệ (ảnh nhật ký cuộc gọi / ghi âm) trước.',
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
              title: const Text('Không liên hệ được'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cần có bằng chứng liên hệ (ảnh nhật ký cuộc gọi hoặc ghi âm) ở khối Bằng chứng liên hệ.',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Thời điểm gọi'),
                    subtitle: Text(formatServiceTime(contactedAt.toIso8601String())),
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
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(contactedAt),
                      );
                      if (t == null) return;
                      setLocal(() {
                        contactedAt = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
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
                      'Chỉ quản lý quyết định đóng phiếu khi không liên hệ được khách.',
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
        if (selected == 'other') 'reasonDetail': detail,
      },
    );
  }

  String _staffLabel(ServiceTicketPublic t) {
    final id = t.staffUserId.trim();
    if (id.isEmpty) return '—';
    for (final u in _users) {
      if (u.$1 == id) return u.$2;
    }
    return t.staffName?.trim().isNotEmpty == true ? t.staffName! : id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    final open = t?.status == 'processing';
    final paused = t?.status == 'contact_failed';
    final completeBlock = open ? _completeBlockReason(requireGuide: true) : null;
    final canAssign = t != null && open && _canChangeAssignee(t) && !_busy;
    final canContactFailed =
        t != null && open && _canChangeAssignee(t) && !_busy;
    final canReschedule =
        t != null && paused && _canChangeAssignee(t) && !_busy;
    final isManager = () {
      final role = context.read<AuthProvider>().user?.role;
      return role == 'admin' || role == 'manager';
    }();
    final canFailFromPaused = t != null && paused && isManager && !_busy;
    final canEditAppt = t != null &&
        open &&
        !_busy &&
        canEditTicketRequestInfoFromContext(context, t);

    // Ensure current assignee appears in the list even if inactive / not returned.
    final usersForPicker = List<(String, String)>.from(_users);
    if (t != null && t.staffUserId.trim().isNotEmpty) {
      final id = t.staffUserId.trim();
      if (!usersForPicker.any((u) => u.$1 == id)) {
        usersForPicker.insert(0, (id, _staffLabel(t)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ?? l10n.serviceOnlineTicket),
        actions: [
          IconButton(
            onPressed: () => _load(showSpinner: true),
            icon: const Icon(Icons.refresh),
          ),
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
                if (t.contactFailedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Không liên hệ được: ${t.contactFailedCount} lần',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TicketAppointmentSlaHeader(
                  ticket: t,
                  canEdit: canEditAppt,
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
                  title: 'Nhân viên kỹ thuật phụ trách',
                  child: canAssign
                      ? SearchableUserDropdown(
                          labelText: 'KTV phụ trách *',
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
                ),
                const SizedBox(height: 12),
                EvidenceSection(
                  ticketId: t.id,
                  stage: 'contact',
                  evidences: t.evidences,
                  onChanged: _load,
                  readOnly: !open,
                  title: 'Bằng chứng liên hệ *',
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Hướng dẫn / xử lý',
                  child: Column(
                    children: [
                      TextField(
                        controller: _guideCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung hướng dẫn *',
                        ),
                        minLines: 3,
                        maxLines: 6,
                        enabled: open,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteCtrl,
                        decoration:
                            InputDecoration(labelText: l10n.repairNotes),
                        maxLines: 2,
                        enabled: open,
                      ),
                    ],
                  ),
                ),
                if (open) ...[
                  if (completeBlock != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      completeBlock,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || completeBlock != null ? null : _complete,
                    child: const Text('Xử lý xong'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || completeBlock != null ? null : _fail,
                    child: const Text('Thất bại'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: !canContactFailed ? null : _promptContactFailed,
                    child: const Text('Không liên hệ được'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final r = await promptReason(
                              context,
                              title: 'Lý do hủy phiếu',
                            );
                            if (r != null) {
                              await _action(
                                'cancel-online',
                                body: {'reason': r},
                              );
                            }
                          },
                    child: const Text('Hủy phiếu'),
                  ),
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
                  if (isManager) ...[
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
