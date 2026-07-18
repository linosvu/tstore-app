import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'service_ui.dart';
import 'widgets/countdown_banner.dart';
import 'widgets/evidence_section.dart';
import 'widgets/locked_request_info_card.dart';
import 'widgets/repair_stepper.dart';
import 'widgets/signature_pad.dart';
import 'widgets/ticket_log_list.dart';

class RepairTicketScreen extends StatefulWidget {
  const RepairTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<RepairTicketScreen> createState() => _RepairTicketScreenState();
}

class _RepairTicketScreenState extends State<RepairTicketScreen> {
  ServiceTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  List<(String, String)> _users = [];

  // Handoff
  String? _techUserId;
  DateTime _contactDeadline = DateTime.now().add(const Duration(hours: 4));
  String _receiveType = 'store';
  final _initialCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();

  // Contact / inspect
  final _contactNoteCtrl = TextEditingController();
  final _solutionCtrl = TextEditingController();
  final _partCostCtrl = TextEditingController(text: '0');
  final _laborCostCtrl = TextEditingController(text: '0');
  DateTime _etaDate = DateTime.now().add(const Duration(days: 3));

  // Result
  final _resultCtrl = TextEditingController();

  // Delivery
  String _deliveryMethod = 'store';
  DateTime? _deliveryEta;
  final _shippingPayerCtrl = TextEditingController();

  // Payment
  final _payAmountCtrl = TextEditingController(text: '0');
  String _payMethod = 'cash';
  DateTime? _payDue;

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
    _initialCtrl.dispose();
    _extraCtrl.dispose();
    _contactNoteCtrl.dispose();
    _solutionCtrl.dispose();
    _partCostCtrl.dispose();
    _laborCostCtrl.dispose();
    _resultCtrl.dispose();
    _shippingPayerCtrl.dispose();
    _payAmountCtrl.dispose();
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
        _techUserId ??= context.read<AuthProvider>().user?.id;
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .fetchTicket(widget.ticketId);
      if (!mounted) return;
      final d = t?.repairDetail;
      setState(() {
        _ticket = t;
        if (d?.solution != null) _solutionCtrl.text = d!.solution!;
        if (d?.partCost != null) _partCostCtrl.text = '${d!.partCost}';
        if (d?.laborCost != null) _laborCostCtrl.text = '${d!.laborCost}';
        if (d?.repairResult != null) _resultCtrl.text = d!.repairResult!;
        if (d?.etaDate != null) {
          final parsed = DateTime.tryParse(d!.etaDate!);
          if (parsed != null) _etaDate = parsed;
        }
        if (d?.paymentAmount != null) {
          _payAmountCtrl.text = '${d!.paymentAmount}';
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
        AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _isManager {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin' || role == 'manager';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    final d = t?.repairDetail;
    final userIds = _users.map((e) => e.$1).toList();
    final nameOf = {for (final u in _users) u.$1: u.$2};

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ?? l10n.serviceRepairTicket),
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
                    if (d?.customerRejectPending == true) ...[
                      const SizedBox(width: 8),
                      const StatusBadge(
                        label: 'Chờ QL xác nhận từ chối',
                        tone: StatusBadgeTone.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                RepairStepper(
                  status: t.status,
                  customerRejectPending: d?.customerRejectPending ?? false,
                ),
                const SizedBox(height: 10),
                CountdownBanner(
                  deadlineAt: t.deadlineAt,
                  isOverdue: t.isOverdue,
                ),
                const SizedBox(height: 12),
                if (t.request != null)
                  LockedRequestInfoCard(request: t.request!),
                const SizedBox(height: 12),
                ..._buildStepBody(t, d, userIds, nameOf, l10n),
                const SizedBox(height: 12),
                TicketLogList(logs: t.logs),
                if (![
                  'completed',
                  'customer_rejected',
                  'cancelled',
                ].contains(t.status)) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final r = await promptReason(
                              context,
                              title: 'Huỷ phiếu sửa chữa',
                            );
                            if (r != null) {
                              await _action(
                                'cancel-repair',
                                body: {'reason': r},
                              );
                            }
                          },
                    child: const Text('Huỷ phiếu SC'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  List<Widget> _buildStepBody(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
    List<String> userIds,
    Map<String, String> nameOf,
    AppLocalizations l10n,
  ) {
    switch (t.status) {
      case 'received':
        return _receivedStep(t, userIds, nameOf);
      case 'inspecting':
        return _inspectingStep(t, d);
      case 'approving':
        return _approvingStep(d);
      case 'notifying':
        return _notifyingStep(t, d);
      case 'repairing':
        return _repairingStep(t, d);
      case 'delivering':
        return _deliveringStep(t);
      case 'paying':
        return _payingStep(t, d);
      default:
        return [
          SectionCard(
            title: 'Kết thúc',
            child: Text(
              'Trạng thái: ${ticketStatusLabel(t.type, t.status)}',
            ),
          ),
        ];
    }
  }

  List<Widget> _receivedStep(
    ServiceTicketPublic t,
    List<String> userIds,
    Map<String, String> nameOf,
  ) {
    return [
      EvidenceSection(
        ticketId: t.id,
        stage: 'receive',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng tiếp nhận',
      ),
      const SizedBox(height: 12),
      SignaturePadSection(
        ticketId: t.id,
        stage: 'receive',
        signer: 'staff',
        signatures: t.signatures,
        onChanged: _load,
      ),
      const SizedBox(height: 8),
      SignaturePadSection(
        ticketId: t.id,
        stage: 'receive',
        signer: 'customer',
        signatures: t.signatures,
        onChanged: _load,
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Bàn giao kỹ thuật',
        child: Column(
          children: [
            TsDropdownFieldNullable<String>(
              value: _techUserId,
              items: userIds,
              itemLabel: (id) => id == null ? '—' : (nameOf[id] ?? id),
              onChanged: (v) => setState(() => _techUserId = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hẹn gọi khách trước'),
              subtitle: Text(_contactDeadline.toLocal().toString()),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _contactDeadline,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d == null || !mounted) return;
                final tm = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_contactDeadline),
                );
                if (tm == null) return;
                setState(() {
                  _contactDeadline = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    tm.hour,
                    tm.minute,
                  );
                });
              },
            ),
            TsDropdownField<String>(
              value: _receiveType,
              items: const ['store', 'home'],
              itemLabel: (v) => v == 'store' ? 'Tại cửa hàng' : 'Tại nhà',
              onChanged: (v) {
                if (v != null) setState(() => _receiveType = v);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _initialCtrl,
              decoration: const InputDecoration(
                labelText: 'Đánh giá ban đầu',
              ),
              maxLines: 2,
            ),
            TextField(
              controller: _extraCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú thêm'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _techUserId == null
                  ? null
                  : () => _action('handoff-tech', body: {
                        'techUserId': _techUserId,
                        'contactDeadlineAt':
                            _contactDeadline.toUtc().toIso8601String(),
                        'receiveType': _receiveType,
                        if (_initialCtrl.text.trim().isNotEmpty)
                          'initialAssessment': _initialCtrl.text.trim(),
                        if (_extraCtrl.text.trim().isNotEmpty)
                          'extraNote': _extraCtrl.text.trim(),
                      }),
              child: const Text('Bàn giao kỹ thuật'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _inspectingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final contacted = d?.contactConfirmedAt != null;
    return [
      EvidenceSection(
        ticketId: t.id,
        stage: 'contact',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng gọi khách',
      ),
      const SizedBox(height: 12),
      if (!contacted)
        SectionCard(
          title: 'Xác nhận đã liên hệ',
          child: Column(
            children: [
              TextField(
                controller: _contactNoteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú liên hệ'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _action('confirm-contacted', body: {
                          if (_contactNoteCtrl.text.trim().isNotEmpty)
                            'contactNote': _contactNoteCtrl.text.trim(),
                        }),
                child: const Text('Đã gọi khách'),
              ),
            ],
          ),
        )
      else ...[
        const Text(
          'Đã xác nhận liên hệ khách.',
          style: TextStyle(color: Colors.green),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Gửi duyệt kiểm tra lỗi',
          child: Column(
            children: [
              TextField(
                controller: _solutionCtrl,
                decoration: const InputDecoration(labelText: 'Phương án sửa'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _partCostCtrl,
                decoration: const InputDecoration(labelText: 'Tiền linh kiện'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: _laborCostCtrl,
                decoration: const InputDecoration(labelText: 'Tiền công'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ngày hẹn xong (ETA)'),
                subtitle: Text(yyyyMmDd(_etaDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _etaDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) setState(() => _etaDate = picked);
                },
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _action('submit-inspect', body: {
                          'solution': _solutionCtrl.text.trim(),
                          'partCost': int.tryParse(_partCostCtrl.text) ?? 0,
                          'laborCost': int.tryParse(_laborCostCtrl.text) ?? 0,
                          'etaDate': yyyyMmDd(_etaDate),
                        }),
                child: const Text('Gửi duyệt kiểm tra'),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _approvingStep(RepairDetailPublic? d) {
    return [
      SectionCard(
        title: 'Duyệt kiểm tra lỗi',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phương án: ${d?.solution ?? '—'}'),
            Text('Linh kiện: ${d?.partCost ?? 0} đ'),
            Text('Công: ${d?.laborCost ?? 0} đ'),
            Text('ETA: ${d?.etaDate ?? '—'}'),
            if (_isManager) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _action('approve-inspect'),
                child: const Text('Duyệt'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final r = await promptReason(context);
                        if (r != null) {
                          await _action('reject-inspect', body: {'reason': r});
                        }
                      },
                child: const Text('Từ chối'),
              ),
            ] else
              const Text('Đang chờ quản lý duyệt…'),
          ],
        ),
      ),
    ];
  }

  List<Widget> _notifyingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    if (d?.customerRejectPending == true) {
      return [
        SectionCard(
          title: 'Khách từ chối — chờ QLĐ xác nhận',
          child: _isManager
              ? FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action('confirm-customer-reject'),
                  child: const Text('Xác nhận khách từ chối'),
                )
              : const Text('Đang chờ quản lý xác nhận.'),
        ),
      ];
    }
    return [
      EvidenceSection(
        ticketId: t.id,
        stage: 'notify',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng thông báo khách',
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Khách xác nhận',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Phương án: ${d?.solution ?? '—'}'),
            Text(
              'Chi phí: ${(d?.partCost ?? 0) + (d?.laborCost ?? 0)} đ',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _action('customer-agree'),
              child: const Text('Khách đồng ý sửa'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final r = await promptReason(
                        context,
                        title: 'Lý do khách từ chối',
                      );
                      if (r != null) {
                        await _action(
                          'customer-reject',
                          body: {'reason': r},
                        );
                      }
                    },
              child: const Text('Khách từ chối'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _repairingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final hasResult = (d?.repairResult ?? '').trim().isNotEmpty;
    return [
      EvidenceSection(
        ticketId: t.id,
        stage: 'repair',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng sửa chữa',
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Kết quả sửa chữa',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d?.rejectCountResult != null && d!.rejectCountResult > 0)
              Text(
                'Đã trả về ${d.rejectCountResult} lần',
                style: const TextStyle(color: Colors.orange),
              ),
            if (hasResult) ...[
              Text('Đã gửi: ${d!.repairResult}'),
              const SizedBox(height: 8),
              if (_isManager) ...[
                FilledButton(
                  onPressed: _busy ? null : () => _action('approve-result'),
                  child: const Text('QL duyệt kết quả → bàn giao'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final r = await promptReason(
                            context,
                            title: 'Lý do trả về',
                          );
                          if (r != null) {
                            await _action(
                              'reject-result',
                              body: {'reason': r},
                            );
                          }
                        },
                  child: const Text('Trả về sửa lại'),
                ),
              ] else
                const Text('Đang chờ quản lý duyệt kết quả…'),
              const Divider(),
              const Text('Gửi lại kết quả (nếu bị trả về):'),
            ],
            TextField(
              controller: _resultCtrl,
              decoration: const InputDecoration(labelText: 'Kết quả sửa'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _action('submit-repair-result', body: {
                        'repairResult': _resultCtrl.text.trim(),
                      }),
              child: Text(hasResult ? 'Gửi lại kết quả' : 'Gửi duyệt kết quả'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _deliveringStep(ServiceTicketPublic t) {
    return [
      EvidenceSection(
        ticketId: t.id,
        stage: 'delivery',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng bàn giao',
      ),
      const SizedBox(height: 8),
      SignaturePadSection(
        ticketId: t.id,
        stage: 'delivery',
        signer: 'customer',
        signatures: t.signatures,
        onChanged: _load,
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Hoàn tất bàn giao',
        child: Column(
          children: [
            TsDropdownField<String>(
              value: _deliveryMethod,
              items: const ['store', 'home', 'shipping'],
              itemLabel: (v) {
                switch (v) {
                  case 'home':
                    return 'Giao tại nhà';
                  case 'shipping':
                    return 'Gửi ship';
                  default:
                    return 'Nhận tại cửa hàng';
                }
              },
              onChanged: (v) {
                if (v != null) setState(() => _deliveryMethod = v);
              },
            ),
            if (_deliveryMethod == 'home')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Thời gian giao'),
                subtitle: Text(
                  _deliveryEta?.toLocal().toString() ?? 'Chọn thời gian',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (d == null || !mounted) return;
                  final tm = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (tm == null) return;
                  setState(() {
                    _deliveryEta = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      tm.hour,
                      tm.minute,
                    );
                  });
                },
              ),
            if (_deliveryMethod == 'shipping')
              TextField(
                controller: _shippingPayerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Người trả phí ship',
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _action('complete-delivery', body: {
                        'deliveryMethod': _deliveryMethod,
                        if (_deliveryMethod == 'home' && _deliveryEta != null)
                          'deliveryEta':
                              _deliveryEta!.toUtc().toIso8601String(),
                        if (_shippingPayerCtrl.text.trim().isNotEmpty)
                          'shippingFeePayer': _shippingPayerCtrl.text.trim(),
                      }),
              child: const Text('Hoàn tất bàn giao'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _payingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final submitted = d?.paymentSubmittedAt != null;
    return [
      SectionCard(
        title: 'Thanh toán',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!submitted) ...[
              TextField(
                controller: _payAmountCtrl,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              TsDropdownField<String>(
                value: _payMethod,
                items: const [
                  'cash',
                  'bank_transfer',
                  'card',
                  'pay_later',
                ],
                itemLabel: (v) {
                  switch (v) {
                    case 'bank_transfer':
                      return 'Chuyển khoản';
                    case 'card':
                      return 'Thẻ';
                    case 'pay_later':
                      return 'Ghi nợ';
                    default:
                      return 'Tiền mặt';
                  }
                },
                onChanged: (v) {
                  if (v != null) setState(() => _payMethod = v);
                },
              ),
              if (_payMethod == 'pay_later')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hạn thanh toán'),
                  subtitle: Text(
                    _payDue != null ? yyyyMmDd(_payDue!) : 'Chọn ngày',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _payDue = picked);
                  },
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _action('submit-payment', body: {
                          'paymentAmount':
                              int.tryParse(_payAmountCtrl.text) ?? 0,
                          'paymentMethod': _payMethod,
                          if (_payMethod == 'pay_later' && _payDue != null)
                            'paymentDueDate': yyyyMmDd(_payDue!),
                        }),
                child: const Text('Ghi nhận thanh toán'),
              ),
            ] else ...[
              Text('Đã ghi nhận: ${d?.paymentAmount ?? 0} đ'),
              Text('PT: ${d?.paymentMethod ?? '—'}'),
              if (_isManager)
                FilledButton(
                  onPressed: _busy ? null : () => _action('confirm-payment'),
                  child: const Text('QL xác nhận đã thu tiền'),
                )
              else
                const Text('Chờ quản lý xác nhận thanh toán…'),
            ],
          ],
        ),
      ),
    ];
  }
}
