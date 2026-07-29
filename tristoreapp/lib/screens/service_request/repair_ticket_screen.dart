import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
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
  String? _receiveStaffUserId;
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

  // Request editing (Thông tin YC gốc)
  bool _editingRequest = false;
  final _reqNameCtrl = TextEditingController();
  final _reqPhoneCtrl = TextEditingController();
  final _reqPhone2Ctrl = TextEditingController();
  final _reqAddressCtrl = TextEditingController();
  final _reqProductNameCtrl = TextEditingController();
  final _reqProductSerialCtrl = TextEditingController();
  final _reqIssueCtrl = TextEditingController();
  List<Map<String, String>> _reqAttachments = [];

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
    _reqNameCtrl.dispose();
    _reqPhoneCtrl.dispose();
    _reqPhone2Ctrl.dispose();
    _reqAddressCtrl.dispose();
    _reqProductNameCtrl.dispose();
    _reqProductSerialCtrl.dispose();
    _reqIssueCtrl.dispose();
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

  Future<void> _load({bool showSpinner = false}) async {
    if (showSpinner || _ticket == null) {
      setState(() => _loading = true);
    }
    try {
      final role = context.read<AuthProvider>().user?.role;
      final includeDeleted = role == 'admin' || role == 'manager';
      final t = await context.read<ServiceRequestsProvider>().fetchTicket(
            widget.ticketId,
            includeDeleted: includeDeleted,
          );
      if (!mounted) return;
      final d = t?.repairDetail;
      setState(() {
        _ticket = t;
        final detail = d;
        final req = t?.request;

        // Reset stateful defaults so rewinding doesn't leave stale values.
        _receiveType = 'store';
        _contactDeadline = DateTime.now().add(const Duration(hours: 4));
        _etaDate = DateTime.now().add(const Duration(days: 3));
        _deliveryMethod = 'store';
        _deliveryEta = null;
        _payMethod = 'cash';
        _payDue = null;

        // Không ghi đè khi user đang sửa dở thông tin YC gốc.
        if (req != null && !_editingRequest) {
          _resetRequestEditorFromRequest(req);
        }

        // Received / handoff.
        _techUserId =
            (t?.staffUserId ?? '').trim().isEmpty ? null : t!.staffUserId;
        final savedReceiveStaff = (detail?.receiveStaffUserId ?? '').trim();
        _receiveStaffUserId = savedReceiveStaff.isEmpty
            ? context.read<AuthProvider>().user?.id
            : savedReceiveStaff;
        _receiveType = detail?.receiveType ?? 'store';
        _initialCtrl.text = detail?.initialAssessment ?? '';
        _extraCtrl.text = detail?.extraNote ?? '';
        _solutionCtrl.text = detail?.solution ?? '';
        _partCostCtrl.text = detail?.partCost != null ? '${detail!.partCost}' : '0';
        _laborCostCtrl.text = detail?.laborCost != null ? '${detail!.laborCost}' : '0';
        _resultCtrl.text = detail?.repairResult ?? '';

        if (detail?.etaDate != null) {
          final parsed = DateTime.tryParse(detail!.etaDate!);
          if (parsed != null) _etaDate = parsed;
        }

        // Hạn gọi khách được nhúng trong contactNote dạng "Hẹn gọi trước: <iso>".
        // Tách ra để ô ghi chú không hiển thị chuỗi máy.
        final contactNote = detail?.contactNote ?? '';
        final m = RegExp(r'Hẹn gọi trước:\s*(\S+)').firstMatch(contactNote);
        if (m != null) {
          final parsed = DateTime.tryParse(m.group(1)!);
          if (parsed != null) _contactDeadline = parsed;
          _contactNoteCtrl.text =
              contactNote.replaceFirst(m.group(0)!, '').trim();
        } else {
          _contactNoteCtrl.text = contactNote;
        }

        // Delivery.
        _deliveryMethod = detail?.deliveryMethod ?? 'store';
        _shippingPayerCtrl.text = detail?.shippingFeePayer ?? '';
        _deliveryEta = detail?.deliveryEta != null
            ? DateTime.tryParse(detail!.deliveryEta!)
            : null;

        // Payment.
        _payMethod = detail?.paymentMethod ?? 'cash';
        _payAmountCtrl.text =
            detail?.paymentAmount != null ? '${detail!.paymentAmount}' : '0';
        _payDue = detail?.paymentDueDate != null
            ? DateTime.tryParse(detail!.paymentDueDate!)
            : null;
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

  String? _handoffBlockReason(ServiceTicketPublic t) {
    final hasEvidence = t.evidences.any((e) => e.stage == 'receive');
    final hasStaff = t.signatures.any(
      (s) => s.stage == 'receive' && s.signer == 'staff',
    );
    final hasCustomer = t.signatures.any(
      (s) => s.stage == 'receive' && s.signer == 'customer',
    );
    if (!hasEvidence) return 'Cần thêm bằng chứng tiếp nhận (ảnh/video).';
    if (!hasStaff) return 'Cần chữ ký nhân viên.';
    if (!hasCustomer) return 'Cần chữ ký khách.';
    if (_receiveStaffUserId == null) return 'Chọn nhân viên tiếp nhận.';
    if (_techUserId == null) return 'Chọn nhân viên kỹ thuật.';
    if (_initialCtrl.text.trim().isEmpty) {
      return 'Nhập nhận định ban đầu.';
    }
    return null;
  }

  Future<void> _handoff(ServiceTicketPublic t) async {
    final block = _handoffBlockReason(t);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('handoff-tech', body: {
      'techUserId': _techUserId,
      'receiveStaffUserId': _receiveStaffUserId,
      'contactDeadlineAt': _contactDeadline.toUtc().toIso8601String(),
      'receiveType': _receiveType,
      'initialAssessment': _initialCtrl.text.trim(),
      if (_extraCtrl.text.trim().isNotEmpty)
        'extraNote': _extraCtrl.text.trim(),
    });
  }

  bool get _isManager {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin' || role == 'manager';
  }

  bool _canRewindRepair(ServiceTicketPublic t, RepairDetailPublic? d) {
    if (t.isDeleted) return false;
    final user = context.read<AuthProvider>().user;
    final role = user?.role;
    if (role == 'admin' || role == 'manager') return true;
    if (role != 'staff') return false;

    final uid = user?.id;
    if (uid == null || uid.trim().isEmpty) return false;
    // Staff chỉ được rewind phiếu do mình tạo hoặc mình đang được gán.
    return t.createdByUserId == uid || t.staffUserId == uid;
  }

  String _targetStatusFromStepIndex(int i) {
    switch (i) {
      case 0:
        return 'received';
      case 1:
        return 'inspecting';
      case 2:
        return 'approving';
      case 3:
        return 'notifying';
      case 4:
        return 'repairing';
      case 5:
        return 'delivering';
      case 6:
        return 'paying';
      default:
        return 'received';
    }
  }

  Future<void> _rewindToStep(
    int stepIndex,
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) async {
    if (_busy) return;
    final currentIdx = repairStepIndex(
      t.status,
      customerRejectPending: d?.customerRejectPending ?? false,
    );
    if (stepIndex >= currentIdx) return;

    final targetStatus = _targetStatusFromStepIndex(stepIndex);
    final title = 'Quay lại: ${repairStepLabels[stepIndex]}';

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Phiếu sẽ lùi về bước này để chỉnh sửa. Bằng chứng và chữ ký của '
          'bước này cùng các bước sau sẽ hết hiệu lực — cần chụp và ký lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _action(
      'rewind-repair',
      body: {'targetStatus': targetStatus},
    );
  }

  bool _canEditRequest(ServiceTicketPublic t, RepairDetailPublic? d) {
    final req = t.request;
    if (req == null) return false;
    if (!_canRewindRepair(t, d)) return false;
    // patchRequest chặn nếu request đã closed.
    return req.status != 'completed' && req.status != 'cancelled';
  }

  Future<void> _copyText(String text, String snackMessage) async {
    final v = text.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    AppMessenger.showSnackBar(context, SnackBar(content: Text(snackMessage)));
  }

  void _resetRequestEditorFromRequest(ServiceRequestBrief req) {
    _reqAttachments = req.attachments
        .map(
          (a) => {'url': a.url, 'mediaType': (a.mediaType ?? 'image')},
        )
        .toList();
    _reqNameCtrl.text = req.customerName;
    _reqPhoneCtrl.text = req.customerPhone;
    _reqPhone2Ctrl.text = req.customerPhone2 ?? '';
    _reqAddressCtrl.text = req.customerAddress ?? '';
    _reqProductNameCtrl.text = req.productName;
    _reqProductSerialCtrl.text = req.productSerial ?? '';
    _reqIssueCtrl.text = req.issueDescription;
  }

  Future<void> _pickRequestAttachments() async {
    final picks = await showMediaPickerSheet(
      context,
      allowVideo: true,
    );
    if (picks == null || picks.isEmpty) return;
    final api = context.read<AuthProvider>().api;

    setState(() => _busy = true);
    try {
      for (final pick in picks) {
        final uploaded = await uploadPickedMedia(pick: pick, api: api);
        if (uploaded == null) continue;
        _reqAttachments.add({
          'url': uploaded.url,
          'mediaType': pick.isVideo ? 'video' : 'image',
        });
      }
      if (mounted) setState(() {});
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

  void _removeRequestAttachmentAt(int index) {
    if (index < 0 || index >= _reqAttachments.length) return;
    setState(() => _reqAttachments.removeAt(index));
  }

  Future<void> _saveRequestEdits(ServiceRequestBrief req) async {
    if (_busy) return;
    if (_reqNameCtrl.text.trim().isEmpty ||
        _reqPhoneCtrl.text.trim().isEmpty ||
        _reqProductNameCtrl.text.trim().isEmpty ||
        _reqIssueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập đủ tên khách, SĐT, sản phẩm và lỗi.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'customerName': _reqNameCtrl.text.trim(),
        'customerPhone': _reqPhoneCtrl.text.trim(),
        'customerPhone2':
            _reqPhone2Ctrl.text.trim().isEmpty ? null : _reqPhone2Ctrl.text.trim(),
        'customerAddress':
            _reqAddressCtrl.text.trim().isEmpty ? null : _reqAddressCtrl.text.trim(),
        'productName': _reqProductNameCtrl.text.trim(),
        'productSerial':
            _reqProductSerialCtrl.text.trim().isEmpty ? null : _reqProductSerialCtrl.text.trim(),
        'issueDescription': _reqIssueCtrl.text.trim(),
        'attachments': _reqAttachments,
      };

      final updated =
          await context.read<ServiceRequestsProvider>().patchRequest(
                req.id,
                body,
              );

      if (!mounted) return;
      if (updated == null) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không thể lưu thông tin yêu cầu.')),
        );
        return;
      }

      setState(() => _editingRequest = false);
      await _load();
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Đã lưu thông tin yêu cầu.')),
      );
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

  Widget _buildRequestInfoEditor(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final req = t.request;
    if (req == null) return const SizedBox.shrink();

    final canEdit = _canEditRequest(t, d);
    if (!_editingRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LockedRequestInfoCard(request: req),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () {
                    setState(() {
                      _editingRequest = true;
                      _resetRequestEditorFromRequest(req);
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa'),
                ),
              ),
            ),
        ],
      );
    }

    return SectionCard(
      title: 'Thông tin yêu cầu gốc (${req.code ?? req.id.substring(0, 8)})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reqNameCtrl,
            decoration: const InputDecoration(labelText: 'Tên khách'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'SĐT',
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _busy ? null : () => _copyText(
                      _reqPhoneCtrl.text,
                      'Đã copy SĐT',
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqPhone2Ctrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'SĐT 2',
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _busy ? null : () => _copyText(
                      _reqPhone2Ctrl.text,
                      'Đã copy SĐT 2',
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqAddressCtrl,
            decoration: const InputDecoration(labelText: 'Địa chỉ'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqProductNameCtrl,
            decoration: const InputDecoration(labelText: 'Sản phẩm'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqProductSerialCtrl,
            decoration: const InputDecoration(labelText: 'Serial'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqIssueCtrl,
            decoration: const InputDecoration(labelText: 'Lỗi'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          Text(
            'Đính kèm (${_reqAttachments.length})',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickRequestAttachments,
            icon: const Icon(Icons.attach_file),
            label: const Text('Thêm đính kèm'),
          ),
          const SizedBox(height: 8),
          if (_reqAttachments.isNotEmpty)
            Column(
              children: [
                for (var i = 0; i < _reqAttachments.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      (_reqAttachments[i]['mediaType'] == 'video')
                          ? Icons.videocam_outlined
                          : Icons.photo_outlined,
                    ),
                    title: Text(
                      (_reqAttachments[i]['mediaType'] == 'video')
                          ? 'Video'
                          : 'Ảnh',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _removeRequestAttachmentAt(i),
                    ),
                    onTap: () {
                      final url = _reqAttachments[i]['url'];
                      final mediaType = _reqAttachments[i]['mediaType'] ?? 'image';
                      if (url == null || url.isEmpty) return;
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerPage(
                            items: [
                              MediaViewerItem(url: url, mediaType: mediaType),
                            ],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _saveRequestEdits(req),
                  child: const Text('Lưu'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _editingRequest = false;
                          _resetRequestEditorFromRequest(req);
                        });
                      },
                child: const Text('Hủy'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _softDeleteTicket() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Xóa phiếu SC'),
          content: const Text(
            'Phiếu sẽ bị ẩn khỏi danh sách (có thể khôi phục). Tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .softDeleteTicket(widget.ticketId);
      if (!mounted) return;
      if (t != null) {
        setState(() {
          _ticket = t;
          _busy = false;
        });
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã xóa phiếu SC.')),
        );
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    }
  }

  Future<void> _restoreTicket() async {
    setState(() => _busy = true);
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .restoreTicket(widget.ticketId);
      if (!mounted) return;
      if (t != null) {
        setState(() {
          _ticket = t;
          _busy = false;
        });
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã khôi phục phiếu SC.')),
        );
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    }
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
                  editable: _canRewindRepair(t, d),
                  onStepTap: (i) => _rewindToStep(i, t, d),
                ),
                const SizedBox(height: 10),
                CountdownBanner(
                  deadlineAt: t.deadlineAt,
                  isOverdue: t.isOverdue,
                ),
                const SizedBox(height: 12),
                _buildRequestInfoEditor(t, d),
                const SizedBox(height: 12),
                ..._buildStepBody(t, d, userIds, nameOf, l10n),
                const SizedBox(height: 12),
                TicketLogList(logs: t.logs),
                if (_isManager) ...[
                  const SizedBox(height: 12),
                  if (t.isDeleted)
                    FilledButton.icon(
                      onPressed: _busy ? null : _restoreTicket,
                      icon: const Icon(Icons.restore),
                      label: const Text('Khôi phục phiếu SC'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _softDeleteTicket,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa phiếu SC'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                if (!t.isDeleted &&
                    ![
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
        title: 'Bằng chứng tiếp nhận *',
      ),
      const SizedBox(height: 12),
      SignaturePadSection(
        key: ValueKey('sig-${t.id}-receive-staff'),
        ticketId: t.id,
        stage: 'receive',
        signer: 'staff',
        signatures: t.signatures,
        onChanged: _load,
        title: 'Chữ ký nhân viên *',
      ),
      const SizedBox(height: 8),
      SignaturePadSection(
        key: ValueKey('sig-${t.id}-receive-customer'),
        ticketId: t.id,
        stage: 'receive',
        signer: 'customer',
        signatures: t.signatures,
        onChanged: _load,
        title: 'Chữ ký khách *',
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Nhân viên tiếp nhận *',
        child: TsDropdownFieldNullable<String>(
          value: _receiveStaffUserId,
          labelText: 'Nhân viên đã ký / tiếp nhận',
          items: [
            ...userIds,
            if (_receiveStaffUserId != null &&
                !userIds.contains(_receiveStaffUserId))
              _receiveStaffUserId!,
          ],
          itemLabel: (id) {
            if (id == null) return '— Chọn nhân viên —';
            return nameOf[id] ?? id;
          },
          onChanged: (v) => setState(() => _receiveStaffUserId = v),
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Bàn giao kỹ thuật',
        child: Column(
          children: [
            TsDropdownFieldNullable<String>(
              value: _techUserId,
              labelText: 'Nhân viên kỹ thuật',
              // NV đang được gán có thể đã bị vô hiệu hoá / ngoài trang đầu
              // danh sách; thiếu item khớp value sẽ làm dropdown assert.
              items: [
                ...userIds,
                if (_techUserId != null && !userIds.contains(_techUserId))
                  _techUserId!,
              ],
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
                labelText: 'Đánh giá ban đầu *',
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _extraCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú thêm'),
            ),
            const SizedBox(height: 12),
            if (_handoffBlockReason(t) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _handoffBlockReason(t)!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _busy || _handoffBlockReason(t) != null
                  ? null
                  : () => _handoff(t),
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
                decoration: const InputDecoration(labelText: 'Phương án sửa *'),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
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
                onPressed: _busy || _solutionCtrl.text.trim().isEmpty
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
        stage: 'repair_result',
        evidences: t.evidences,
        onChanged: _load,
        title: 'Bằng chứng kết quả sửa *',
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
              decoration: const InputDecoration(labelText: 'Kết quả sửa *'),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy || _resultCtrl.text.trim().isEmpty
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
        key: ValueKey('sig-${t.id}-delivery-staff'),
        ticketId: t.id,
        stage: 'delivery',
        signer: 'staff',
        signatures: t.signatures,
        onChanged: _load,
        title: 'Chữ ký nhân viên *',
      ),
      const SizedBox(height: 8),
      SignaturePadSection(
        key: ValueKey('sig-${t.id}-delivery-customer'),
        ticketId: t.id,
        stage: 'delivery',
        signer: 'customer',
        signatures: t.signatures,
        onChanged: _load,
        title: 'Chữ ký khách *',
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
