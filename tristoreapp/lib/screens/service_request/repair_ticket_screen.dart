import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/integer_thousands_input_formatter.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'service_ui.dart';
import 'widgets/countdown_banner.dart';
import 'widgets/edit_request_info_sheet.dart';
import 'widgets/evidence_section.dart';
import 'widgets/locked_request_info_card.dart';
import 'widgets/repair/deadline_card.dart';
import 'widgets/repair/repair_terms_sheet.dart';
import 'widgets/repair/sub_status_badge.dart';
import 'widgets/repair_stepper.dart';
import 'widgets/signature_pad.dart';
import 'widgets/signature_thumb.dart';
import 'widgets/ticket_log_list.dart';

class RepairTicketScreen extends StatefulWidget {
  const RepairTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<RepairTicketScreen> createState() => _RepairTicketScreenState();
}

class _RepairTicketScreenState extends State<RepairTicketScreen> {
  static const _thousandsSep = ThousandsGroupSeparatorKey.dot;

  ServiceTicketPublic? _ticket;
  bool _loading = true;
  bool _busy = false;
  List<(String, String)> _users = [];

  /// Đang xem lại bước đã qua (không đổi status / không xóa data bước sau).
  int? _previewStepIndex;

  // Handoff / inspect
  static const _defaultTermsText =
      'Kỹ thuật hỗ trợ Phong — 034 621 2738 hoặc Tây — 090 577 8145. '
      'Trong vòng 3 ngày kỹ thuật báo tình trạng máy và thời gian dự kiến hoàn thành.';

  String? _technicianId;
  String? _vendorId;
  String? _repairType;
  String? _sendStaffUserId;
  String? _pickupStaffUserId;
  DateTime _sendMovedAt = DateTime.now();
  DateTime _pickupMovedAt = DateTime.now();
  final _sendNoteCtrl = TextEditingController();
  final _pickupNoteCtrl = TextEditingController();
  final _vendorDoneNoteCtrl = TextEditingController();
  bool _invalidatingRepairSave = false;
  List<RepairTechnicianPublic> _technicians = [];
  List<RepairVendorPublic> _vendors = [];
  String? _techUserId;
  String? _receiveStaffUserId;
  DateTime _contactDeadline = DateTime.now().add(const Duration(hours: 4));
  String? _repairMethod;
  bool _inspectFormDirty = false;
  bool _termsDirty = false;
  final _termsCtrl = TextEditingController();
  final _initialCtrl = TextEditingController();
  final _receiveNoteCtrl = TextEditingController();
  final _methodNoteCtrl = TextEditingController();

  // Contact / inspect leftovers used later
  final _contactNoteCtrl = TextEditingController();

  // Repairing
  bool _repairFormDirty = false;
  final _solutionCtrl = TextEditingController();
  final _partCostCtrl = TextEditingController(text: '0');
  final _laborCostCtrl = TextEditingController(text: '0');
  final _warrantyCtrl = TextEditingController(text: '0');
  final _repairContactNoteCtrl = TextEditingController();
  final _receiveBackNoteCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();

  // Delivery
  bool _deliveryFormDirty = false;
  String? _deliveryStaffUserId;
  String _deliveryMethod = 'store';
  DateTime? _deliveryEta;
  final _shippingPayerCtrl = TextEditingController();
  final _deliveryNoteCtrl = TextEditingController();
  bool _resignDeliveryStaff = false;
  bool _resignDeliveryCustomer = false;

  // Payment
  bool _payFormDirty = false;
  final _payAmountCtrl = TextEditingController(text: '0');
  final _payNoteCtrl = TextEditingController();
  String _payMethod = 'cash';
  DateTime? _payDue;
  final List<String> _payProofUrls = [];
  final List<PendingMediaUpload> _pendingPayProofs = [];

  // Request editing (Thông tin YC gốc)
  bool _editingRequest = false;
  bool _resignReceiveStaff = false;
  bool _resignReceiveCustomer = false;
  final _reqNameCtrl = TextEditingController();
  final _reqPhoneCtrl = TextEditingController();
  final _reqAddressCtrl = TextEditingController();
  final _reqCustomerNoteCtrl = TextEditingController();
  final _reqBuyerNameCtrl = TextEditingController();
  final _reqBuyerPhoneCtrl = TextEditingController();
  final _reqBuyerAddressCtrl = TextEditingController();
  final _reqProductNameCtrl = TextEditingController();
  final _reqProductSerialCtrl = TextEditingController();
  final _reqIssueCtrl = TextEditingController();
  final _reqSlotCtrl = TextEditingController();
  DateTime _reqAppointmentDate = DateTime.now().add(const Duration(days: 1));
  List<Map<String, String>> _reqAttachments = [];
  final List<PendingMediaUpload> _pendingReqAttachments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadUsers();
      _loadRepairConfig();
    });
  }

  Future<void> _loadRepairConfig() async {
    final prov = context.read<ServiceRequestsProvider>();
    final vendors = await prov.fetchRepairVendors();
    final techs = await prov.fetchRepairTechnicians();
    if (!mounted) return;
    setState(() {
      _vendors = vendors;
      _technicians = techs;
    });
  }

  @override
  void dispose() {
    _initialCtrl.dispose();
    _termsCtrl.dispose();
    _receiveNoteCtrl.dispose();
    _methodNoteCtrl.dispose();
    _reqNameCtrl.dispose();
    _reqPhoneCtrl.dispose();
    _reqAddressCtrl.dispose();
    _reqCustomerNoteCtrl.dispose();
    _reqBuyerNameCtrl.dispose();
    _reqBuyerPhoneCtrl.dispose();
    _reqBuyerAddressCtrl.dispose();
    _reqProductNameCtrl.dispose();
    _reqProductSerialCtrl.dispose();
    _reqIssueCtrl.dispose();
    _reqSlotCtrl.dispose();
    _contactNoteCtrl.dispose();
    _solutionCtrl.dispose();
    _partCostCtrl.dispose();
    _laborCostCtrl.dispose();
    _warrantyCtrl.dispose();
    _repairContactNoteCtrl.dispose();
    _receiveBackNoteCtrl.dispose();
    _resultCtrl.dispose();
    _shippingPayerCtrl.dispose();
    _deliveryNoteCtrl.dispose();
    _payAmountCtrl.dispose();
    _payNoteCtrl.dispose();
    _sendNoteCtrl.dispose();
    _pickupNoteCtrl.dispose();
    _vendorDoneNoteCtrl.dispose();
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
        final status = t?.status;
        final softInspect = status == 'received' ||
            status == 'inspecting' ||
            status == 'approving' ||
            status == 'notifying';
        final softRepair = status == 'repairing';
        final softDelivery = status == 'delivering';
        final softPay = status == 'paying';

        // Reset defaults for later steps; soft-preserve inspect/receive form.
        if (!softInspect || !_inspectFormDirty) {
          _contactDeadline = DateTime.now().add(const Duration(hours: 4));
        }

        if (req != null && !_editingRequest) {
          _resetRequestEditorFromRequest(req);
        }

        if (!softInspect || !_inspectFormDirty) {
          final staffId = (t?.staffUserId ?? '').trim();
          _techUserId = staffId.isEmpty ? null : staffId;
          final savedReceiveStaff = (detail?.receiveStaffUserId ?? '').trim();
          _receiveStaffUserId = savedReceiveStaff.isEmpty
              ? context.read<AuthProvider>().user?.id
              : savedReceiveStaff;
          _initialCtrl.text = detail?.initialAssessment ?? '';
          _methodNoteCtrl.text = detail?.extraNote ?? '';
          _repairMethod = detail?.repairMethod;
          _technicianId = detail?.technicianId;
          _vendorId = detail?.vendorId;
          _repairType = detail?.repairType ??
              (detail?.repairMethod == 'store'
                  ? 'in_store'
                  : detail?.repairMethod != null
                      ? 'external'
                      : null);
          if (detail?.contactDeadlineAt != null) {
            final parsed = DateTime.tryParse(detail!.contactDeadlineAt!);
            if (parsed != null) _contactDeadline = parsed;
          }
        }

        if (!_termsDirty) {
          final terms = detail?.termsText?.trim();
          _termsCtrl.text =
              (terms != null && terms.isNotEmpty) ? terms : _defaultTermsText;
        }

        // Chỉ seed khi form chưa dirty — tránh hồi sinh ghi chú sau khi user xóa
        // rồi upload bằng chứng (_load lại với ô trống).
        if (!_inspectFormDirty) {
          _receiveNoteCtrl.text = (t?.note ?? '').trim();
        }

        final contactNote = detail?.contactNote ?? '';
        if (!softInspect || !_inspectFormDirty) {
          _contactNoteCtrl.text = contactNote;
        }

        final preserveRepair = softRepair && _repairFormDirty;
        final preserveDelivery = softDelivery && _deliveryFormDirty;
        final preservePay = softPay && _payFormDirty;
        final preserveCosts = preserveRepair || preserveDelivery;

        if (!preserveRepair) {
          _solutionCtrl.text = detail?.solution ?? '';
          _repairContactNoteCtrl.text = detail?.repairContactNote ?? '';
          _receiveBackNoteCtrl.text = detail?.receiveBackNote ?? '';
          _resultCtrl.text = detail?.repairResult ?? '';
        }
        if (!preserveCosts) {
          _partCostCtrl.text = formatIntegerWithSeparator(
            detail?.partCost ?? 0,
            _thousandsSep,
          );
          _laborCostCtrl.text = formatIntegerWithSeparator(
            detail?.laborCost ?? 0,
            _thousandsSep,
          );
          _warrantyCtrl.text = '${detail?.warrantyMonths ?? 0}';
        }

        if (!preserveDelivery) {
          _deliveryMethod = detail?.deliveryMethod ?? 'store';
          _shippingPayerCtrl.text = detail?.shippingFeePayer ?? '';
          _deliveryEta = detail?.deliveryEta != null
              ? DateTime.tryParse(detail!.deliveryEta!)
              : null;
          final savedDelivery = (detail?.deliveryStaffUserId ?? '').trim();
          _deliveryStaffUserId = savedDelivery.isEmpty
              ? context.read<AuthProvider>().user?.id
              : savedDelivery;
        }

        if (!preservePay) {
          final aborted = detail?.abortedAt != null;
          final costTotal =
              (detail?.partCost ?? 0) + (detail?.laborCost ?? 0);
          _payMethod = detail?.paymentMethod ?? (aborted ? 'free' : 'cash');
          if (detail?.paymentAmount != null) {
            _payAmountCtrl.text = formatIntegerWithSeparator(
              detail!.paymentAmount!,
              _thousandsSep,
            );
          } else if (aborted || _payMethod == 'free') {
            _payAmountCtrl.text = '0';
          } else {
            _payAmountCtrl.text =
                formatIntegerWithSeparator(costTotal, _thousandsSep);
          }
          _payDue = detail?.paymentDueDate != null
              ? DateTime.tryParse(detail!.paymentDueDate!)
              : null;
          _payNoteCtrl.text = detail?.paymentNote ?? '';
          _payProofUrls
            ..clear()
            ..addAll(detail?.paymentProofUrls ?? const []);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _action(String action, {Map<String, dynamic>? body}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .ticketAction(widget.ticketId, action, body: body);
      if (updated != null && mounted) {
        setState(() {
          _ticket = updated;
          _repairFormDirty = false;
          _deliveryFormDirty = false;
          _payFormDirty = false;
          _previewStepIndex = null;
        });
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã cập nhật.')),
        );
        await _load();
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _handoffBlockReason(ServiceTicketPublic t) {
    final hasStaff = t.signatures.any(
      (s) => s.stage == 'receive' && s.signer == 'staff',
    );
    final hasCustomer = t.signatures.any(
      (s) => s.stage == 'receive' && s.signer == 'customer',
    );
    if (!hasStaff) return 'Cần chữ ký nhân viên.';
    if (!hasCustomer) return 'Cần chữ ký khách.';
    if (_receiveStaffUserId == null) return 'Chọn nhân viên tiếp nhận.';
    return null;
  }

  Future<void> _updateRepairTerms() async {
    final ok = await context.read<ServiceRequestsProvider>().patchTicket(
          widget.ticketId,
          'repair-terms',
          body: {'termsText': _termsCtrl.text.trim()},
        );
    if (ok != null && mounted) {
      setState(() {
        _termsDirty = false;
        _ticket = ok;
      });
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Đã lưu cam kết')),
      );
    }
  }

  Future<void> _openTermsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => RepairTermsSheet(
        initialText: _termsCtrl.text,
        defaultText: _defaultTermsText,
        onSave: (text) async {
          setState(() {
            _termsCtrl.text = text;
            _termsDirty = true;
          });
          await _updateRepairTerms();
        },
      ),
    );
  }

  Widget _termsCommitmentRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              _termsCtrl.text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          if (!_historyView)
            IconButton(
              tooltip: 'Sửa cam kết',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: _busy ? null : _openTermsSheet,
            ),
        ],
      ),
    );
  }

  bool _deadlineReadOnly(ServiceTicketPublic t, RepairDetailPublic? d) {
    final step = _historyView
        ? _previewStepIndex!
        : _currentStepIndex(t, d);
    return step >= 3;
  }

  TicketMovementPublic? _movement(RepairDetailPublic? d, String type) {
    final list = d?.movements ?? const [];
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i].type == type) return list[i];
    }
    return null;
  }

  String _userName(String? userId) {
    if (userId == null) return '—';
    for (final u in _users) {
      if (u.$1 == userId) return u.$2;
    }
    return userId;
  }

  void _onRepairFieldChanged() {
    final wasDirty = _repairFormDirty;
    setState(() => _repairFormDirty = true);
    if (!wasDirty && !_historyView && !_invalidatingRepairSave) {
      _invalidateRepairWorkSave();
    }
  }

  Future<void> _invalidateRepairWorkSave() async {
    if (_invalidatingRepairSave || _historyView) return;
    _invalidatingRepairSave = true;
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .ticketAction(widget.ticketId, 'invalidate-repair-work-save');
      if (updated != null && mounted) {
        setState(() => _ticket = updated);
      }
    } catch (_) {
      // Client vẫn khoá nút qua _repairFormDirty.
    } finally {
      _invalidatingRepairSave = false;
    }
  }

  Widget _movementDateTile({
    required String title,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(formatServiceTime(value.toIso8601String())),
      trailing: const Icon(Icons.schedule),
      onTap: _historyView
          ? null
          : () async {
              final d0 = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d0 == null || !mounted) return;
              final tm = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (tm == null) return;
              onChanged(
                DateTime(d0.year, d0.month, d0.day, tm.hour, tm.minute),
              );
            },
    );
  }

  Future<void> _handoff(ServiceTicketPublic t) async {
    final block = _handoffBlockReason(t);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('handoff-tech', body: {
      'receiveStaffUserId': _receiveStaffUserId,
      if (_receiveNoteCtrl.text.trim().isNotEmpty)
        'note': _receiveNoteCtrl.text.trim(),
    });
    if (mounted) setState(() => _inspectFormDirty = false);
  }

  String? _confirmInspectBlockReason(ServiceTicketPublic _) {
    if (_initialCtrl.text.trim().isEmpty) {
      return 'Nhập đánh giá ban đầu.';
    }
    if (_technicianId == null || _technicianId!.isEmpty) {
      return 'Chọn nhân viên kỹ thuật.';
    }
    if (_repairType == null) return 'Chọn hình thức sửa chữa.';
    if (_repairType == 'external' &&
        (_vendorId == null || _vendorId!.isEmpty)) {
      return 'Chọn đơn vị sửa ngoài.';
    }
    return null;
  }

  Future<void> _confirmInspect(ServiceTicketPublic t) async {
    final block = _confirmInspectBlockReason(t);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('confirm-inspect', body: {
      'initialAssessment': _initialCtrl.text.trim(),
      'technicianId': _technicianId,
      'repairType': _repairType,
      if (_repairType == 'external') 'vendorId': _vendorId,
      if (_methodNoteCtrl.text.trim().isNotEmpty)
        'extraNote': _methodNoteCtrl.text.trim(),
    });
    if (mounted) setState(() => _inspectFormDirty = false);
  }

  Future<void> _saveRepairWork() async {
    await _action('save-repair-work', body: {
      'solution': _solutionCtrl.text.trim(),
      'partCost': _parseCostField(_partCostCtrl),
      'laborCost': _parseCostField(_laborCostCtrl),
      'warrantyMonths': int.tryParse(_warrantyCtrl.text.trim()) ?? 0,
    });
    if (mounted) setState(() => _repairFormDirty = false);
  }

  Future<void> _openExtendDeadline(ServiceTicketPublic t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => RepairExtendDeadlineSheet(
        ticketId: t.id,
        evidences: t.evidences,
        onReload: _load,
        onSaved: (dt, note) async {
          await _action('extend-deadline', body: {
            'newDeadlineAt': dt.toUtc().toIso8601String(),
            if (note != null) 'contactNote': note,
          });
        },
      ),
    );
  }

  Future<void> _cancelRequest(ServiceTicketPublic t) async {
    final r = await promptReason(
      context,
      title: 'Hủy yêu cầu sửa chữa',
    );
    if (r == null || !mounted) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .ticketAction(widget.ticketId, 'cancel-repair', body: {'reason': r});
      if (!mounted) return;
      if (updated != null) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã hủy yêu cầu.')),
        );
        Navigator.pop(context, true);
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

  int _currentStepIndex(ServiceTicketPublic t, RepairDetailPublic? d) {
    return repairStepIndex(
      t.status,
      customerRejectPending: d?.customerRejectPending ?? false,
      subStatus: d?.subStatus,
    );
  }

  bool get _historyView {
    final t = _ticket;
    if (t == null || _previewStepIndex == null) return false;
    return _previewStepIndex! < _currentStepIndex(t, t.repairDetail);
  }

  String _statusForStepIndex(int i) => _targetStatusFromStepIndex(i);

  void _onStepperTap(int stepIndex, ServiceTicketPublic t, RepairDetailPublic? d) {
    final cur = _currentStepIndex(t, d);
    if (stepIndex > cur || stepIndex >= 5) return;
    setState(() {
      // Bấm bước hiện tại → thoát chế độ xem lại.
      if (stepIndex == cur) {
        _previewStepIndex = null;
      } else {
        _previewStepIndex = stepIndex;
      }
    });
  }

  String _targetStatusFromStepIndex(int i) {
    switch (i) {
      case 0:
        return 'received';
      case 1:
        return 'inspecting';
      case 2:
        return 'repairing';
      case 3:
        return 'delivering';
      case 4:
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
    final currentIdx = _currentStepIndex(t, d);
    if (stepIndex >= currentIdx) return;

    final targetStatus = _targetStatusFromStepIndex(stepIndex);
    final title = 'Làm lại từ: ${repairStepLabels[stepIndex]}';

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Phiếu sẽ lùi về bước này để chỉnh sửa. Bằng chứng và chữ ký của '
          'bước này cùng các bước sau sẽ hết hiệu lực — cần chụp và ký lại. '
          'Dữ liệu các bước sau sẽ bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Làm lại'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _previewStepIndex = null);
    await _action(
      'rewind-repair',
      body: {'targetStatus': targetStatus},
    );
  }

  bool _canEditRequest(ServiceTicketPublic t, RepairDetailPublic? d) {
    return canEditTicketRequestInfoFromContext(context, t);
  }

  Future<void> _copyText(String text, String snackMessage) async {
    final v = text.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    AppMessenger.showSnackBar(context, SnackBar(content: Text(snackMessage)));
  }

  void _resetRequestEditorFromRequest(
    ServiceRequestBrief req, {
    ServiceTicketPublic? ticket,
  }) {
    _reqAttachments = req.attachments
        .map(
          (a) => {'url': a.url, 'mediaType': (a.mediaType ?? 'image')},
        )
        .toList();
    _reqNameCtrl.text = req.customerName;
    _reqPhoneCtrl.text = req.customerPhone;
    _reqAddressCtrl.text = req.customerAddress ?? '';
    _reqCustomerNoteCtrl.text = req.customerNote ?? '';
    _reqBuyerNameCtrl.text = req.buyerName ?? '';
    _reqBuyerPhoneCtrl.text = req.buyerPhone ?? '';
    _reqBuyerAddressCtrl.text = req.buyerAddress ?? '';
    _reqProductNameCtrl.text = req.productName;
    _reqProductSerialCtrl.text = req.productSerial ?? '';
    _reqIssueCtrl.text = req.issueDescription;
    final t = ticket ?? _ticket;
    final parsed = DateTime.tryParse(t?.appointmentDate ?? '');
    _reqAppointmentDate =
        parsed ?? DateTime.now().add(const Duration(days: 1));
    final slot = normalizeAppointmentTimeLabel(t?.appointmentSlot);
    _reqSlotCtrl.text = slot.isEmpty
        ? formatAppointmentTimeOfDay(defaultAppointmentTime)
        : slot;
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
      var anyFail = false;
      for (final pick in picks) {
        final pending = enqueuePendingMedia(pick: pick, scopeKey: 'request');
        setState(() => _pendingReqAttachments.add(pending));
        try {
          final uploaded = await uploadPickedMedia(
            pick: pick,
            api: api,
            onProgress: (v) {
              if (!mounted) return;
              setState(() => pending.progress = v);
            },
          );
          if (uploaded == null) {
            anyFail = true;
            continue;
          }
          _reqAttachments.add({
            'url': uploaded.url,
            'mediaType': uploaded.mediaType,
          });
        } catch (_) {
          anyFail = true;
        } finally {
          if (mounted) {
            setState(
              () => _pendingReqAttachments.removeWhere((e) => e.id == pending.id),
            );
          }
        }
      }
      if (anyFail && mounted) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(
            content: Text('Một số ảnh/video không tải lên được. Thử video ngắn hơn.'),
          ),
        );
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

  void _removePendingReqAttachment(String id) {
    if (!mounted) return;
    setState(() => _pendingReqAttachments.removeWhere((e) => e.id == id));
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
      final infoBody = <String, dynamic>{
        'customerName': _reqNameCtrl.text.trim(),
        'customerPhone': _reqPhoneCtrl.text.trim(),
        'productName': _reqProductNameCtrl.text.trim(),
        'issueDescription': _reqIssueCtrl.text.trim(),
        'customerNote': _reqCustomerNoteCtrl.text.trim().isEmpty
            ? null
            : _reqCustomerNoteCtrl.text.trim(),
        'appointmentDate': yyyyMmDd(_reqAppointmentDate),
        'appointmentSlot': normalizeAppointmentTimeLabel(_reqSlotCtrl.text)
                .isEmpty
            ? formatAppointmentTimeOfDay(defaultAppointmentTime)
            : normalizeAppointmentTimeLabel(_reqSlotCtrl.text),
      };
      final ticketUpdated = await context
          .read<ServiceRequestsProvider>()
          .patchTicketRequestInfo(widget.ticketId, infoBody);
      if (!mounted) return;
      if (ticketUpdated == null) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không thể lưu thông tin yêu cầu.')),
        );
        return;
      }

      final extraBody = <String, dynamic>{
        'customerAddress':
            _reqAddressCtrl.text.trim().isEmpty ? null : _reqAddressCtrl.text.trim(),
        'buyerName': _reqBuyerNameCtrl.text.trim().isEmpty
            ? null
            : _reqBuyerNameCtrl.text.trim(),
        'buyerPhone': _reqBuyerPhoneCtrl.text.trim().isEmpty
            ? null
            : _reqBuyerPhoneCtrl.text.trim(),
        'buyerAddress': _reqBuyerAddressCtrl.text.trim().isEmpty
            ? null
            : _reqBuyerAddressCtrl.text.trim(),
        'productSerial':
            _reqProductSerialCtrl.text.trim().isEmpty ? null : _reqProductSerialCtrl.text.trim(),
        'attachments': _reqAttachments,
      };
      await context.read<ServiceRequestsProvider>().patchRequest(
            req.id,
            extraBody,
          );

      if (!mounted) return;

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
      return LockedRequestInfoCard(
        request: req,
        onEdit: !canEdit || _busy
            ? null
            : () {
                setState(() {
                  _editingRequest = true;
                  _resetRequestEditorFromRequest(req, ticket: t);
                });
              },
      );
    }

    return SectionCard(
      title: 'Thông tin yêu cầu gốc (${req.code ?? req.id.substring(0, 8)})',
      titleTrailing: IconButton(
        tooltip: 'Hủy chỉnh sửa',
        onPressed: _busy
            ? null
            : () => setState(() {
                  _editingRequest = false;
                  _resetRequestEditorFromRequest(req, ticket: t);
                }),
        icon: const Icon(Icons.close),
      ),
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
                onPressed: _busy
                    ? null
                    : () => _copyText(
                          _reqPhoneCtrl.text,
                          'Đã copy SĐT',
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
            controller: _reqCustomerNoteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqBuyerNameCtrl,
            decoration: const InputDecoration(labelText: 'Tên người mua'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqBuyerPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'SĐT người mua',
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _busy
                    ? null
                    : () => _copyText(
                          _reqBuyerPhoneCtrl.text,
                          'Đã copy SĐT người mua',
                        ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reqBuyerAddressCtrl,
            decoration: const InputDecoration(labelText: 'Địa chỉ người mua'),
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
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày hẹn'),
            subtitle: Text(yyyyMmDd(_reqAppointmentDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _reqAppointmentDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _reqAppointmentDate = picked);
                    }
                  },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giờ hẹn'),
            subtitle: Text(
              normalizeAppointmentTimeLabel(_reqSlotCtrl.text).isEmpty
                  ? formatAppointmentTimeOfDay(defaultAppointmentTime)
                  : normalizeAppointmentTimeLabel(_reqSlotCtrl.text),
            ),
            trailing: const Icon(Icons.access_time),
            enabled: !_busy,
            onTap: _busy
                ? null
                : () async {
                    final picked = await pickAppointmentTimeOfDay(
                      context,
                      initial: parseAppointmentTimeOfDay(_reqSlotCtrl.text),
                    );
                    if (picked != null) {
                      setState(() {
                        _reqSlotCtrl.text = formatAppointmentTimeOfDay(picked);
                      });
                    }
                  },
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._pendingReqAttachments.map(
                  (pending) => SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LocalMediaPreviewTile(
                          localPath: pending.localPath,
                          isVideo: pending.isVideo,
                          progress: pending.progress,
                          width: 64,
                          height: 64,
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.75),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _busy
                                  ? null
                                  : () => _removePendingReqAttachment(pending.id),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < _reqAttachments.length; i++)
                  Stack(
                    children: [
                      MediaTile(
                        url: _reqAttachments[i]['url'] ?? '',
                        mediaType: _reqAttachments[i]['mediaType'] ?? 'image',
                        width: 64,
                        height: 64,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MediaViewerPage(
                                items: [
                                  for (final a in _reqAttachments)
                                    MediaViewerItem(
                                      url: a['url'] ?? '',
                                      mediaType: a['mediaType'] ?? 'image',
                                    ),
                                ],
                                initialIndex: i,
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _busy ? null : () => _removeRequestAttachmentAt(i),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _saveRequestEdits(req),
            child: const Text('Lưu thông tin yêu cầu'),
          ),
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
                    const SizedBox(width: 8),
                    RepairSubStatusBadge(subStatus: d?.subStatus),
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
                  subStatus: d?.subStatus,
                  customerRejectPending: d?.customerRejectPending ?? false,
                  browsable: !t.isDeleted,
                  previewIndex: _previewStepIndex,
                  onStepTap: (i) => _onStepperTap(i, t, d),
                ),
                if (_historyView) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Đang xem lại: ${repairStepLabels[_previewStepIndex!]}. '
                            'Dữ liệu các bước sau vẫn được giữ — không chỉnh sửa tại đây.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () =>
                                    setState(() => _previewStepIndex = null),
                                child: Text(
                                  'Về ${repairStepLabels[_currentStepIndex(t, d)]}',
                                ),
                              ),
                              if (_canRewindRepair(t, d))
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _rewindToStep(
                                            _previewStepIndex!,
                                            t,
                                            d,
                                          ),
                                  child: const Text('Làm lại từ bước này…'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                CountdownBanner(
                  deadlineAt: t.deadlineAt,
                  isOverdue: t.isOverdue,
                ),
                const SizedBox(height: 12),
                _buildRequestInfoEditor(t, d),
                if (d != null) ...[
                  const SizedBox(height: 12),
                  RepairDeadlineCard(
                    ticketId: t.id,
                    deadlineAt: t.deadlineAt,
                    deadlineChanges: d.deadlineChanges,
                    evidences: t.evidences,
                    readOnly: _deadlineReadOnly(t, d),
                    onExtend: () => _openExtendDeadline(t),
                    onReload: _load,
                  ),
                ],
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
                    t.status != 'received' &&
                    t.status != 'inspecting' &&
                    t.status != 'approving' &&
                    t.status != 'notifying' &&
                    t.status != 'repairing' &&
                    t.status != 'delivering' &&
                    !(t.status == 'paying' && d?.abortedAt != null) &&
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
    final status = _historyView
        ? _statusForStepIndex(_previewStepIndex!)
        : t.status;
    switch (status) {
      case 'received':
        return _receivedStep(t, userIds, nameOf);
      case 'inspecting':
      case 'approving':
      case 'notifying':
        return _inspectingStep(t, d, userIds, nameOf);
      case 'repairing':
        return _repairingStep(t, d);
      case 'delivering':
        return _deliveringStep(t, d, userIds, nameOf);
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
    final staffSigs = t.signatures
        .where((s) => s.stage == 'receive' && s.signer == 'staff')
        .toList();
    final customerSigs = t.signatures
        .where((s) => s.stage == 'receive' && s.signer == 'customer')
        .toList();
    final bothSigned = staffSigs.isNotEmpty && customerSigs.isNotEmpty;

    final receiveStaffRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 120,
          child: Text(
            'Nhân viên tiếp nhận *',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: TsDropdownFieldNullable<String>(
            value: _receiveStaffUserId,
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
            onChanged: _historyView
                ? null
                : (v) => setState(() {
                      _receiveStaffUserId = v;
                      _inspectFormDirty = true;
                    }),
          ),
        ),
      ],
    );

    final evidence = EvidenceSection(
      ticketId: t.id,
      stage: 'receive',
      evidences: t.evidences,
      onChanged: _load,
      readOnly: _historyView,
      title: 'Bằng chứng tiếp nhận',
      noteField: TextField(
        controller: _receiveNoteCtrl,
        readOnly: _historyView,
        decoration: const InputDecoration(
          labelText: 'Ghi chú bằng chứng tiếp nhận',
        ),
        maxLines: 2,
        onChanged: (_) => _inspectFormDirty = true,
      ),
    );

    final ctas = _historyView
        ? const SizedBox.shrink()
        : Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          child: const Text('Chuyển sang Kiểm tra'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _cancelRequest(t),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Hủy yêu cầu'),
        ),
      ],
    );

    if (bothSigned) {
      return [
        evidence,
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              receiveStaffRow,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SignatureThumb(
                      label: 'NV tiếp nhận',
                      url: staffSigs.last.imageUrl,
                      subtitle: staffSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(staffSigs.last.signedAt),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SignatureThumb(
                      label: 'Khách',
                      url: customerSigs.last.imageUrl,
                      subtitle: customerSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(customerSigs.last.signedAt),
                    ),
                  ),
                ],
              ),
              _termsCommitmentRow(),
              Row(
                children: [
                  if (!_historyView) ...[
                    TextButton(
                      onPressed: () =>
                          setState(() => _resignReceiveStaff = true),
                      child: const Text('Ký lại NV'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _resignReceiveCustomer = true),
                      child: const Text('Ký lại khách'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!_historyView && _resignReceiveStaff) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-receive-staff-resign'),
            ticketId: t.id,
            stage: 'receive',
            signer: 'staff',
            signatures: const [],
            onChanged: () {
              setState(() => _resignReceiveStaff = false);
              _load();
            },
            readOnly: false,
            title: 'Ký lại — nhân viên',
          ),
        ],
        if (!_historyView && _resignReceiveCustomer) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-receive-customer-resign'),
            ticketId: t.id,
            stage: 'receive',
            signer: 'customer',
            signatures: const [],
            onChanged: () {
              setState(() => _resignReceiveCustomer = false);
              _load();
            },
            readOnly: false,
            title: 'Ký lại — khách',
          ),
        ],
        const SizedBox(height: 12),
        ctas,
      ];
    }

    return [
      evidence,
      const SizedBox(height: 12),
      SignaturePadSection(
        key: ValueKey('sig-${t.id}-receive-staff'),
        ticketId: t.id,
        stage: 'receive',
        signer: 'staff',
        signatures: t.signatures,
        onChanged: _load,
        readOnly: _historyView,
        title: 'Chữ ký nhân viên tiếp nhận *',
        header: receiveStaffRow,
      ),
      const SizedBox(height: 8),
      SignaturePadSection(
        key: ValueKey('sig-${t.id}-receive-customer'),
        ticketId: t.id,
        stage: 'receive',
        signer: 'customer',
        signatures: t.signatures,
        onChanged: _load,
        readOnly: _historyView,
        title: 'Chữ ký khách *',
      ),
      _termsCommitmentRow(),
      const SizedBox(height: 12),
      ctas,
    ];
  }

  List<Widget> _inspectingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
    List<String> userIds,
    Map<String, String> nameOf,
  ) {
    final sub = d?.subStatus ?? 'pending_check';
    final isPendingSend = sub == 'pending_send';
    _sendStaffUserId ??= context.read<AuthProvider>().user?.id;

    return [
      if (!isPendingSend) ...[
        SectionCard(
          title: 'Nhân viên kỹ thuật *',
          child: TsDropdownFieldNullable<String>(
            value: _technicianId,
            labelText: 'Kỹ thuật viên',
            items: _technicians.map((x) => x.id).toList(),
            itemLabel: (id) {
              if (id == null) return '—';
              for (final x in _technicians) {
                if (x.id == id) return x.name;
              }
              return id;
            },
            onChanged: _historyView
                ? null
                : (v) => setState(() {
                      _technicianId = v;
                      _inspectFormDirty = true;
                    }),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Đánh giá ban đầu *',
          child: TextField(
            controller: _initialCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(
              labelText: 'Nhận định / đánh giá ban đầu',
            ),
            maxLines: 3,
            onChanged: (_) => setState(() => _inspectFormDirty = true),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Hình thức sửa chữa *',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(repairTypeLabel('in_store')),
                    selected: _repairType == 'in_store',
                    onSelected: _historyView
                        ? null
                        : (_) => setState(() {
                              _repairType = 'in_store';
                              _inspectFormDirty = true;
                            }),
                  ),
                  ChoiceChip(
                    label: Text(repairTypeLabel('external')),
                    selected: _repairType == 'external',
                    onSelected: _historyView
                        ? null
                        : (_) => setState(() {
                              _repairType = 'external';
                              _inspectFormDirty = true;
                            }),
                  ),
                ],
              ),
              if (_repairType == 'external') ...[
                const SizedBox(height: 8),
                TsDropdownFieldNullable<String>(
                  value: _vendorId,
                  labelText: 'Đơn vị sửa ngoài *',
                  items: _vendors.map((v) => v.id).toList(),
                  itemLabel: (id) {
                    if (id == null) return '—';
                    for (final v in _vendors) {
                      if (v.id == id) return v.name;
                    }
                    return id;
                  },
                  onChanged: _historyView
                      ? null
                      : (v) => setState(() {
                            _vendorId = v;
                            _inspectFormDirty = true;
                          }),
                ),
              ],
              const SizedBox(height: 12),
              EvidenceSection(
                ticketId: t.id,
                stage: 'repair_method',
                evidences: t.evidences,
                onChanged: _load,
                readOnly: _historyView,
                title: 'Ảnh/video kiểm tra',
                noteField: TextField(
                  controller: _methodNoteCtrl,
                  readOnly: _historyView,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                  maxLines: 2,
                  onChanged: (_) => _inspectFormDirty = true,
                ),
              ),
            ],
          ),
        ),
        if (!_historyView) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _confirmInspectBlockReason(t) != null
                ? null
                : () => _confirmInspect(t),
            child: const Text('Xác nhận kiểm tra'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _declineRepair,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Khách không sửa'),
          ),
        ],
      ],
      if (isPendingSend) ...[
        const SizedBox(height: 12),
        SectionCard(
          title: 'Gửi đi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (d?.vendorName != null)
                Text(
                  'Đơn vị: ${d!.vendorName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              _movementDateTile(
                title: 'Ngày giờ gửi *',
                value: _sendMovedAt,
                onChanged: (v) => setState(() => _sendMovedAt = v),
              ),
              const SizedBox(height: 8),
              TsDropdownFieldNullable<String>(
                value: _sendStaffUserId,
                labelText: 'Nhân viên bàn giao *',
                items: userIds,
                itemLabel: (id) => id == null ? '—' : (nameOf[id] ?? id),
                onChanged: _historyView
                    ? null
                    : (v) => setState(() => _sendStaffUserId = v),
              ),
              const SizedBox(height: 8),
              EvidenceSection(
                ticketId: t.id,
                stage: 'send',
                evidences: t.evidences,
                onChanged: _load,
                readOnly: _historyView,
                title: 'Ảnh/video bàn giao',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sendNoteCtrl,
                readOnly: _historyView,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                maxLines: 2,
              ),
              if (!_historyView) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action('confirm-send', body: {
                            'staffUserId': _sendStaffUserId,
                            'movedAt': _sendMovedAt.toUtc().toIso8601String(),
                            if (_sendNoteCtrl.text.trim().isNotEmpty)
                              'note': _sendNoteCtrl.text.trim(),
                          }),
                  child: const Text('Xác nhận đã gửi'),
                ),
              ],
            ],
          ),
        ),
      ],
      if (!_historyView && !isPendingSend) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _cancelRequest(t),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Hủy yêu cầu'),
        ),
      ],
      if (!_historyView && isPendingSend) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _declineRepair,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Khách không sửa'),
        ),
      ],
    ];
  }

  int _parseCostField(TextEditingController c) =>
      parseIntegerLoose(c.text, _thousandsSep) ?? 0;

  String _money(int v) => formatIntegerWithSeparator(v, _thousandsSep);

  String? _advanceDeliveryBlockReason(
    ServiceTicketPublic _,
    RepairDetailPublic? d,
  ) {
    if (_solutionCtrl.text.trim().isEmpty) {
      return 'Nhập nội dung sửa chữa.';
    }
    if (!(d?.isRepairWorkSaved ?? false) || _repairFormDirty) {
      return 'Cần bấm Lưu nội dung & chi phí trước.';
    }
    if (_resultCtrl.text.trim().isEmpty) return 'Nhập kết quả sửa chữa.';
    if (int.tryParse(_warrantyCtrl.text.trim()) == null) {
      return 'Nhập bảo hành (tháng).';
    }
    return null;
  }

  Future<void> _completeRepair(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) async {
    final block = _advanceDeliveryBlockReason(t, d);
    if (block != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(block)));
      return;
    }
    await _action('complete-repair', body: {
      'repairResult': _resultCtrl.text.trim(),
    });
  }

  Future<void> _abortToPayment() async {
    final r = await promptReason(
      context,
      title: 'Hủy giữa chừng — lý do',
      hint: 'Lý do chuyển sang Thanh toán & Duyệt',
    );
    if (r != null) {
      await _action('abort-to-payment', body: {'reason': r});
    }
  }

  Future<void> _declineRepair() async {
    final r = await promptReason(
      context,
      title: 'Khách không sửa — lý do',
      hint: 'Lý do khách từ chối sửa chữa',
    );
    if (r != null) {
      await _action('decline-repair', body: {'reason': r});
    }
  }

  Future<void> _addPayProof() async {
    final picks = await showMediaPickerSheet(context, allowVideo: false);
    if (picks == null || picks.isEmpty || !mounted) return;
    final api = context.read<AuthProvider>().api;
    setState(() => _busy = true);
    try {
      var anyFail = false;
      for (final pick in picks) {
        final pending = enqueuePendingMedia(pick: pick, scopeKey: 'pay-proof');
        setState(() => _pendingPayProofs.add(pending));
        try {
          final uploaded = await uploadPickedMedia(
            pick: pick,
            api: api,
            onProgress: (v) {
              if (!mounted) return;
              setState(() => pending.progress = v);
            },
          );
          if (uploaded == null || uploaded.url.isEmpty) {
            anyFail = true;
            continue;
          }
          _payProofUrls.add(uploaded.url);
        } catch (_) {
          anyFail = true;
        } finally {
          if (mounted) {
            setState(
              () => _pendingPayProofs.removeWhere((e) => e.id == pending.id),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _payFormDirty = true;
          _busy = false;
        });
        if (anyFail) {
          AppMessenger.showSnackBar(
            context,
            const SnackBar(content: Text('Một số chứng từ tải lên thất bại.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('Không tải được chứng từ: $e')),
        );
      }
    }
  }

  void _removePendingPayProof(String id) {
    if (!mounted) return;
    setState(() => _pendingPayProofs.removeWhere((e) => e.id == id));
  }

  Widget _proofTiles({
    required bool canEdit,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._pendingPayProofs.map(
          (pending) => SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LocalMediaPreviewTile(
                  localPath: pending.localPath,
                  isVideo: pending.isVideo,
                  progress: pending.progress,
                  width: 64,
                  height: 64,
                ),
                if (canEdit)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.75),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _removePendingPayProof(pending.id),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < _payProofUrls.length; i++)
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MediaTile(
                  url: _payProofUrls[i],
                  mediaType: 'image',
                  width: 64,
                  height: 64,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MediaViewerPage(
                          items: _payProofUrls
                              .map(
                                (u) => MediaViewerItem(
                                  url: u,
                                  mediaType: 'image',
                                ),
                              )
                              .toList(),
                          initialIndex: i,
                        ),
                      ),
                    );
                  },
                ),
                if (canEdit)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.75),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => setState(() {
                          _payProofUrls.removeAt(i);
                          _payFormDirty = true;
                        }),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (canEdit)
          ActionChip(
            avatar: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Thêm'),
            onPressed: _busy ? null : _addPayProof,
          ),
      ],
    );
  }

  List<Widget> _repairingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final sub = d?.subStatus ?? 'in_repair';
    final repairType = d?.repairType ??
        (_repairType ??
            (d?.repairMethod == 'store' ? 'in_store' : 'external'));
    final elapsed = formatRepairElapsed(
      d?.repairStartedAt,
      fallbackIso: t.statusChangedAt,
    );
    final canComplete = sub == 'in_repair' || sub == 'back_in_store';
    final block = canComplete ? _advanceDeliveryBlockReason(t, d) : null;
    _pickupStaffUserId ??= context.read<AuthProvider>().user?.id;

    final workCard = SectionCard(
      title: 'Nội dung & chi phí',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _solutionCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(
              labelText: 'Nội dung sửa chữa *',
            ),
            maxLines: 3,
            onChanged: (_) => _onRepairFieldChanged(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _partCostCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(labelText: 'Tiền linh kiện'),
            keyboardType: integerThousandsKeyboardType(_thousandsSep),
            inputFormatters: [
              IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
            ],
            onChanged: (_) => _onRepairFieldChanged(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _laborCostCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(labelText: 'Tiền công'),
            keyboardType: integerThousandsKeyboardType(_thousandsSep),
            inputFormatters: [
              IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
            ],
            onChanged: (_) => _onRepairFieldChanged(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _warrantyCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(
              labelText: 'Bảo hành (tháng) *',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _onRepairFieldChanged(),
          ),
          if (!_historyView) ...[
            const SizedBox(height: 12),
            if (d?.isRepairWorkSaved == true && !_repairFormDirty)
              Text(
                'Đã lưu ${formatServiceTimeHm(d?.repairWorkSavedAt)} · '
                '${_userName(d?.repairWorkSavedBy)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            if (_repairFormDirty || !(d?.isRepairWorkSaved ?? false))
              Text(
                'Cần bấm Lưu trước khi hoàn tất sửa chữa.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : _saveRepairWork,
              child: const Text('Lưu nội dung & chi phí'),
            ),
          ],
        ],
      ),
    );

    return [
      SectionCard(
        title: 'Thông tin sửa chữa',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hình thức: ${repairTypeLabel(repairType)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (d?.technicianName != null)
              Text('KTV: ${d!.technicianName}'),
            if (d?.vendorName != null) Text('Đơn vị: ${d!.vendorName}'),
            if ((d?.extraNote ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Ghi chú: ${d!.extraNote}'),
            ],
            const SizedBox(height: 8),
            Text('Đã sửa: $elapsed'),
            Text(
              'Trạng thái: ${repairSubStatusLabel(sub)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (sub == 'at_vendor') ...[
        SectionCard(
          title: 'Đang sửa ngoài',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                d?.vendorName ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_movement(d, 'send') != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Đã gửi: ${formatServiceTime(_movement(d, 'send')!.movedAt)}',
                  style: const TextStyle(fontSize: 13),
                ),
                if ((_movement(d, 'send')!.staffName ?? '').isNotEmpty)
                  Text(
                    'NV gửi: ${_movement(d, 'send')!.staffName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if ((_movement(d, 'send')!.note ?? '').trim().isNotEmpty)
                  Text(
                    'Ghi chú gửi: ${_movement(d, 'send')!.note}',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Xác nhận khi đơn vị báo đã sửa xong để chuyển sang chờ lấy về.',
              ),
              if (!_historyView) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _vendorDoneNoteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action('vendor-done', body: {
                            if (_vendorDoneNoteCtrl.text.trim().isNotEmpty)
                              'note': _vendorDoneNoteCtrl.text.trim(),
                          }),
                  child: const Text('Đơn vị đã sửa xong'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _declineRepair,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Khách không sửa'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        workCard,
      ] else if (sub == 'pending_pickup') ...[
        SectionCard(
          title: 'Lấy về cửa hàng',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (d?.vendorName != null)
                Text(
                  'Từ: ${d!.vendorName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              _movementDateTile(
                title: 'Ngày giờ lấy về *',
                value: _pickupMovedAt,
                onChanged: (v) => setState(() => _pickupMovedAt = v),
              ),
              const SizedBox(height: 8),
              TsDropdownFieldNullable<String>(
                value: _pickupStaffUserId,
                labelText: 'Nhân viên lấy về *',
                items: [
                  for (final u in _users) u.$1,
                ],
                itemLabel: (id) {
                  if (id == null) return '—';
                  for (final u in _users) {
                    if (u.$1 == id) return u.$2;
                  }
                  return id;
                },
                onChanged: _historyView
                    ? null
                    : (v) => setState(() => _pickupStaffUserId = v),
              ),
              const SizedBox(height: 8),
              EvidenceSection(
                ticketId: t.id,
                stage: 'return',
                evidences: t.evidences,
                onChanged: _load,
                readOnly: _historyView,
                title: 'Ảnh/video nhận lại',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pickupNoteCtrl,
                readOnly: _historyView,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                maxLines: 2,
              ),
              if (!_historyView) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || _pickupStaffUserId == null
                      ? null
                      : () => _action('confirm-pickup', body: {
                            'staffUserId': _pickupStaffUserId,
                            'movedAt':
                                _pickupMovedAt.toUtc().toIso8601String(),
                            if (_pickupNoteCtrl.text.trim().isNotEmpty)
                              'note': _pickupNoteCtrl.text.trim(),
                          }),
                  child: const Text('Xác nhận đã lấy về'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _declineRepair,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Khách không sửa'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        workCard,
      ] else ...[
        workCard,
        const SizedBox(height: 12),
        EvidenceSection(
          ticketId: t.id,
          stage: 'repair_result',
          evidences: t.evidences,
          onChanged: _load,
          readOnly: _historyView,
          title: 'Bằng chứng kết quả sửa',
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Kết quả sửa chữa',
          child: TextField(
            controller: _resultCtrl,
            readOnly: _historyView,
            decoration: const InputDecoration(labelText: 'Kết quả *'),
            maxLines: 3,
            onChanged: (_) => setState(() => _repairFormDirty = true),
          ),
        ),
        if (!_historyView) ...[
          const SizedBox(height: 12),
          if (block != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          FilledButton(
            onPressed: _busy || block != null
                ? null
                : () => _completeRepair(t, d),
            child: const Text('Hoàn tất sửa — sang Trả khách'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _declineRepair,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Khách không sửa'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _abortToPayment,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hủy giữa chừng'),
          ),
        ],
      ],
    ];
  }

  String? _completeDeliveryBlockReason(ServiceTicketPublic t) {
    if (_deliveryStaffUserId == null || _deliveryStaffUserId!.trim().isEmpty) {
      return 'Chọn nhân viên bàn giao.';
    }
    final hasStaff = t.signatures.any(
      (s) => s.stage == 'delivery' && s.signer == 'staff',
    );
    final hasCustomer = t.signatures.any(
      (s) => s.stage == 'delivery' && s.signer == 'customer',
    );
    if (!hasStaff) return 'Cần chữ ký nhân viên.';
    if (!hasCustomer) return 'Cần chữ ký khách.';
    if (_deliveryMethod == 'home' && _deliveryEta == null) {
      return 'Chọn thời gian giao tại nhà.';
    }
    if (_deliveryMethod == 'shipping' &&
        _shippingPayerCtrl.text.trim().isEmpty) {
      return 'Nhập người trả phí ship.';
    }
    return null;
  }

  List<Widget> _deliveringStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
    List<String> userIds,
    Map<String, String> nameOf,
  ) {
    final part = _parseCostField(_partCostCtrl);
    final labor = _parseCostField(_laborCostCtrl);
    final total = part + labor;
    final block = _completeDeliveryBlockReason(t);
    final sub = d?.subStatus ?? 'pending_delivery';

    final staffSigs = t.signatures
        .where((s) => s.stage == 'delivery' && s.signer == 'staff')
        .toList();
    final customerSigs = t.signatures
        .where((s) => s.stage == 'delivery' && s.signer == 'customer')
        .toList();
    final bothSigned = staffSigs.isNotEmpty && customerSigs.isNotEmpty;

    final deliveryStaffRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            'NV bàn giao *',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: TsDropdownFieldNullable<String>(
            value: (_deliveryStaffUserId ?? '').trim().isEmpty
                ? null
                : _deliveryStaffUserId,
            items: [
              ...userIds,
              if ((_deliveryStaffUserId ?? '').trim().isNotEmpty &&
                  !userIds.contains(_deliveryStaffUserId))
                _deliveryStaffUserId!,
            ],
            itemLabel: (id) => id == null ? '— Chọn nhân viên —' : (nameOf[id] ?? id),
            onChanged: _historyView
                ? null
                : (v) => setState(() {
                      _deliveryStaffUserId = v;
                      _deliveryFormDirty = true;
                    }),
          ),
        ),
      ],
    );

    final evidence = EvidenceSection(
      ticketId: t.id,
      stage: 'delivery',
      evidences: t.evidences,
      onChanged: () => _load(),
      readOnly: _historyView,
      title: 'Bằng chứng bàn giao',
      noteField: TextField(
        controller: _deliveryNoteCtrl,
        readOnly: _historyView,
        decoration: const InputDecoration(
          labelText: 'Ghi chú bằng chứng bàn giao',
        ),
        maxLines: 2,
        onChanged: (_) => setState(() => _deliveryFormDirty = true),
      ),
    );

    final methodCard = SectionCard(
      title: 'Hình thức bàn giao',
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
            onChanged: _historyView
                ? null
                : (v) {
                    if (v != null) {
                      setState(() {
                        _deliveryMethod = v;
                        _deliveryFormDirty = true;
                      });
                    }
                  },
          ),
          if (_deliveryMethod == 'home')
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Thời gian giao'),
              subtitle: Text(
                _deliveryEta?.toLocal().toString() ?? 'Chọn thời gian',
              ),
              onTap: _historyView
                  ? null
                  : () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (day == null || !mounted) return;
                      final tm = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (tm == null) return;
                      setState(() {
                        _deliveryEta = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          tm.hour,
                          tm.minute,
                        );
                        _deliveryFormDirty = true;
                      });
                    },
            ),
          if (_deliveryMethod == 'shipping')
            TextField(
              controller: _shippingPayerCtrl,
              readOnly: _historyView,
              decoration: const InputDecoration(
                labelText: 'Người trả phí ship',
              ),
              onChanged: (_) => setState(() => _deliveryFormDirty = true),
            ),
        ],
      ),
    );

    final ctas = _historyView
        ? const SizedBox.shrink()
        : Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (block != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              block,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        FilledButton(
          onPressed: _busy || block != null
              ? null
              : () => _action('complete-delivery', body: {
                    'deliveryMethod': _deliveryMethod,
                    'deliveryStaffUserId': _deliveryStaffUserId,
                    if (_deliveryMethod == 'home' && _deliveryEta != null)
                      'deliveryEta':
                          _deliveryEta!.toUtc().toIso8601String(),
                    if (_shippingPayerCtrl.text.trim().isNotEmpty)
                      'shippingFeePayer': _shippingPayerCtrl.text.trim(),
                    if (_deliveryNoteCtrl.text.trim().isNotEmpty)
                      'note': _deliveryNoteCtrl.text.trim(),
                  }),
          child: const Text('Hoàn tất trả khách — sang Thanh toán'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _abortToPayment,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Hủy'),
        ),
      ],
    );

    final List<Widget> signatureBlock;
    if (bothSigned) {
      signatureBlock = [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deliveryStaffRow,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SignatureThumb(
                      label: 'NV bàn giao',
                      url: staffSigs.last.imageUrl,
                      subtitle: staffSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(staffSigs.last.signedAt),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SignatureThumb(
                      label: 'Khách',
                      url: customerSigs.last.imageUrl,
                      subtitle: customerSigs.last.signedAt == null
                          ? null
                          : formatServiceTime(customerSigs.last.signedAt),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (!_historyView) ...[
                    TextButton(
                      onPressed: () =>
                          setState(() => _resignDeliveryStaff = true),
                      child: const Text('Ký lại NV'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _resignDeliveryCustomer = true),
                      child: const Text('Ký lại khách'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!_historyView && _resignDeliveryStaff) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-delivery-staff-resign'),
            ticketId: t.id,
            stage: 'delivery',
            signer: 'staff',
            signatures: const [],
            onChanged: () {
              setState(() => _resignDeliveryStaff = false);
              _load();
            },
            title: 'Ký lại — NV bàn giao',
          ),
        ],
        if (!_historyView && _resignDeliveryCustomer) ...[
          const SizedBox(height: 8),
          SignaturePadSection(
            key: ValueKey('sig-${t.id}-delivery-customer-resign'),
            ticketId: t.id,
            stage: 'delivery',
            signer: 'customer',
            signatures: const [],
            onChanged: () {
              setState(() => _resignDeliveryCustomer = false);
              _load();
            },
            title: 'Ký lại — khách',
          ),
        ],
      ];
    } else {
      signatureBlock = [
        SectionCard(child: deliveryStaffRow),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SignaturePadSection(
                key: ValueKey('sig-${t.id}-delivery-staff'),
                ticketId: t.id,
                stage: 'delivery',
                signer: 'staff',
                signatures: t.signatures,
                onChanged: () => _load(),
                readOnly: _historyView,
                title: 'NV bàn giao *',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SignaturePadSection(
                key: ValueKey('sig-${t.id}-delivery-customer'),
                ticketId: t.id,
                stage: 'delivery',
                signer: 'customer',
                signatures: t.signatures,
                onChanged: () => _load(),
                readOnly: _historyView,
                title: 'Khách *',
              ),
            ),
          ],
        ),
      ];
    }

    return [
      if (sub == 'declined') ...[
        SectionCard(
          title: 'Khách không sửa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lý do: ${d?.abortReason ?? d?.repairResult ?? '—'}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chi phí = 0. Hoàn tất trả máy rồi sang thanh toán (miễn phí).',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      methodCard,
      const SizedBox(height: 12),
      SectionCard(
        title: 'Chi phí & bảo hành',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tiền linh kiện: ${_money(part)} đ'),
            Text('Tiền công: ${_money(labor)} đ'),
            const SizedBox(height: 4),
            Text(
              'Tổng chi phí: ${_money(total)} đ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Bảo hành: ${d?.warrantyMonths ?? 0} tháng'),
            if (!_historyView &&
                _canRewindRepair(t, d) &&
                sub != 'declined') ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _rewindToStep(2, t, d),
                child: const Text('Sửa chi phí'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      evidence,
      const SizedBox(height: 12),
      ...signatureBlock,
      const SizedBox(height: 12),
      ctas,
    ];
  }

  List<Widget> _payingStep(
    ServiceTicketPublic t,
    RepairDetailPublic? d,
  ) {
    final sub = d?.subStatus ?? 'pending_payment';
    final pendingPayment = sub == 'pending_payment' || d?.paymentSubmittedAt == null;
    final pendingApproval = sub == 'pending_approval';
    final terminal = sub == 'completed' || sub == 'debt_open';
    final aborted = d?.abortedAt != null;
    final declined = d?.subStatus == 'declined' ||
        (d?.repairResult ?? '').startsWith('Khách không sửa');
    final costTotal = (d?.partCost ?? 0) + (d?.laborCost ?? 0);
    final due = (aborted || declined)
        ? (d?.paymentAmount ?? 0)
        : (d?.paymentAmount ?? costTotal);
    final isFree = _payMethod == 'free';
    final displayDue = isFree ? 0 : due;
    final currentUserId = context.read<AuthProvider>().user?.id;
    final sameSubmitter =
        pendingApproval && d?.paymentSubmittedBy == currentUserId;

    if (terminal) {
      return [
        SectionCard(
          title: 'Thanh toán & Duyệt',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repairSubStatusLabel(sub),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Tổng chi phí sửa: ${_money(costTotal)} đ'),
              if (sub == 'debt_open') ...[
                Text('Công nợ: ${_money(d?.paymentAmount ?? 0)} đ'),
                if (d?.paymentDueDate != null)
                  Text('Hạn thu: ${d!.paymentDueDate}'),
              ] else
                Text(
                  d?.paymentMethod == 'free'
                      ? 'Miễn phí'
                      : 'Đã thu: ${_money(d?.paymentAmount ?? 0)} đ',
                ),
            ],
          ),
        ),
      ];
    }

    return [
      if (aborted)
        SectionCard(
          title: 'Hủy giữa chừng',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lý do: ${d?.abortReason ?? '—'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quản lý chọn miễn phí / số tiền rồi Duyệt để đóng phiếu.',
              ),
            ],
          ),
        ),
      if (aborted) const SizedBox(height: 12),
      if (declined && !aborted)
        SectionCard(
          title: 'Khách không sửa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lý do: ${d?.abortReason ?? '—'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Chi phí 0 — ghi nhận miễn phí rồi duyệt để đóng.'),
            ],
          ),
        ),
      if (declined && !aborted) const SizedBox(height: 12),
      SectionCard(
        title: 'Thanh toán & Duyệt',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tổng chi phí sửa: ${_money(costTotal)} đ'),
            Text('Còn lại / cần thu: ${_money(displayDue)} đ'),
            const SizedBox(height: 12),
            if (pendingPayment) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Miễn phí'),
                value: isFree,
                onChanged: (v) {
                  setState(() {
                    _payFormDirty = true;
                    if (v) {
                      _payMethod = 'free';
                      _payAmountCtrl.text = '0';
                    } else {
                      _payMethod = 'cash';
                      _payAmountCtrl.text = _money(due);
                    }
                  });
                },
              ),
              if (!isFree) ...[
                TextField(
                  controller: _payAmountCtrl,
                  decoration: const InputDecoration(labelText: 'Số tiền'),
                  keyboardType: integerThousandsKeyboardType(_thousandsSep),
                  inputFormatters: [
                    IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
                  ],
                  onChanged: (_) => setState(() => _payFormDirty = true),
                ),
                const SizedBox(height: 8),
                TsDropdownField<String>(
                  value: _payMethod == 'free' ? 'cash' : _payMethod,
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
                    if (v != null) {
                      setState(() {
                        _payMethod = v;
                        _payFormDirty = true;
                      });
                    }
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
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _payDue = picked;
                          _payFormDirty = true;
                        });
                      }
                    },
                  ),
                if (_payMethod == 'bank_transfer') ...[
                  const SizedBox(height: 8),
                  const Text('Chứng từ chuyển khoản *'),
                  const SizedBox(height: 4),
                  _proofTiles(canEdit: !_historyView),
                ] else if (_payMethod == 'cash') ...[
                  const SizedBox(height: 8),
                  const Text('Chứng từ (tuỳ chọn)'),
                  const SizedBox(height: 4),
                  _proofTiles(canEdit: !_historyView),
                ],
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _payNoteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
                maxLines: 2,
                onChanged: (_) => setState(() => _payFormDirty = true),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_payMethod == 'bank_transfer' &&
                            _payProofUrls.isEmpty) {
                          AppMessenger.showSnackBar(
                            context,
                            const SnackBar(
                              content: Text(
                                'Chuyển khoản cần đính kèm chứng từ.',
                              ),
                            ),
                          );
                          return;
                        }
                        _action('submit-payment', body: {
                          'paymentAmount': isFree
                              ? 0
                              : _parseCostField(_payAmountCtrl),
                          'paymentMethod': _payMethod,
                          if (_payNoteCtrl.text.trim().isNotEmpty)
                            'paymentNote': _payNoteCtrl.text.trim(),
                          if (_payMethod == 'pay_later' && _payDue != null)
                            'paymentDueDate': yyyyMmDd(_payDue!),
                          if (_payProofUrls.isNotEmpty)
                            'paymentProofUrls': List<String>.from(_payProofUrls),
                        });
                      },
                child: const Text('Ghi nhận thanh toán'),
              ),
              if (aborted && _isManager) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!isFree ||
                              _payNoteCtrl.text.trim().isNotEmpty ||
                              _payProofUrls.isNotEmpty) {
                            final ok = await _action('submit-payment', body: {
                              'paymentAmount': isFree
                                  ? 0
                                  : _parseCostField(_payAmountCtrl),
                              'paymentMethod': _payMethod,
                              if (_payNoteCtrl.text.trim().isNotEmpty)
                                'paymentNote': _payNoteCtrl.text.trim(),
                              if (_payProofUrls.isNotEmpty)
                                'paymentProofUrls':
                                    List<String>.from(_payProofUrls),
                            });
                            if (!ok) return;
                          }
                          await _action('confirm-payment');
                        },
                  child: const Text('Duyệt kết thúc'),
                ),
              ],
            ] else if (pendingApproval) ...[
              Text(
                isFree || (d?.paymentMethod == 'free')
                    ? 'Miễn phí'
                    : 'Đã ghi nhận: ${_money(d?.paymentAmount ?? 0)} đ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('PT: ${d?.paymentMethod ?? '—'}'),
              if (d?.paymentSubmittedAt != null)
                Text(
                  'Ghi bởi ${_userName(d?.paymentSubmittedBy)} · '
                  '${formatServiceTime(d?.paymentSubmittedAt)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              if ((d?.paymentNote ?? '').trim().isNotEmpty)
                Text('Ghi chú: ${d!.paymentNote}'),
              if ((d?.paymentProofUrls ?? const []).isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < d!.paymentProofUrls.length; i++)
                      ActionChip(
                        label: Text('Chứng từ ${i + 1}'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MediaViewerPage(
                                items: d.paymentProofUrls
                                    .map(
                                      (u) => MediaViewerItem(
                                        url: u,
                                        mediaType: 'image',
                                      ),
                                    )
                                    .toList(),
                                initialIndex: i,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (sameSubmitter)
                Text(
                  'Bạn đã ghi nhận — cần quản lý khác duyệt.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              if (_isManager) ...[
                FilledButton(
                  onPressed: _busy || sameSubmitter
                      ? null
                      : () => _action('confirm-payment'),
                  child: Text(aborted ? 'Duyệt kết thúc' : 'Duyệt thanh toán'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final r = await promptReason(
                            context,
                            title: 'Sửa lại thanh toán',
                            hint: 'Lý do trả về bước ghi nhận',
                          );
                          if (r != null) {
                            await _action('revise-payment', body: {
                              'reason': r,
                            });
                          }
                        },
                  child: const Text('Sửa lại ghi nhận'),
                ),
              ] else
                const Text('Chờ quản lý duyệt…'),
            ],
          ],
        ),
      ),
    ];
  }
}
