import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/providers/address_catalog_provider.dart';

import 'package:tstore/core/config/api_config.dart';
import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/constants/routes.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/app_date_time.dart';
import 'package:tstore/core/utils/dio_error_message.dart';
import 'package:tstore/core/utils/order_address_display.dart';
import 'package:tstore/core/theme/app_text_styles.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/delivery_provider.dart';
import 'package:tstore/providers/preparation_provider.dart';
import 'package:tstore/screens/delivery/create_delivery_sheet.dart';
import 'package:tstore/widgets/assign_target_dropdown.dart';
import 'package:tstore/screens/delivery/delivery_detail_screen.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/screens/orders/record_sale_order_payment_screen.dart';
import 'package:tstore/screens/products/product_media_widgets.dart';
import 'package:tstore/screens/orders/sale_order_flow_screen.dart';
import 'package:tstore/screens/preparation/preparation_detail_screen.dart';
import 'package:tstore/screens/preparation/preparation_ui.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/status_change_sheet.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

const _thousandsSep = ThousandsGroupSeparatorKey.dot;

List<(String, StatusBadgeTone)> _detailLineBadges(
  SaleOrderLinePublic l,
  AppLocalizations l10n,
) {
  return [
    if (l.fragile) (l10n.saleOrderFlagFragile, StatusBadgeTone.warning),
    if (l.bulky) (l10n.saleOrderFlagBulky, StatusBadgeTone.neutral),
    if (l.needsInstallation) (l10n.saleOrderFlagInstall, StatusBadgeTone.info),
    if (l.carefulPackaging) (l10n.saleOrderFlagPack, StatusBadgeTone.neutral),
    if (l.alreadyPaid) (l10n.saleOrderFlagPaid, StatusBadgeTone.info),
  ];
}

/// Dịch mã phương thức KiotViet (Cash/Card/Transfer/...) sang tiếng Việt.
/// Nếu chuỗi đã ở dạng đã localize (vd "Tiền mặt") thì trả nguyên.
bool _paymentCountsAsCollected(SaleOrderPaymentPublic p) =>
    p.recordStatus != 'pending' && !p.isScheduleReminder;

String _localizedPaymentMethod(String raw, AppLocalizations l10n) {
  final s = raw.trim();
  if (s.isEmpty) return '—';
  if (s == 'Hẹn thu') return l10n.saleOrderPaymentScheduleReminderLabel;
  switch (s) {
    case '1':
    case 'Cash':
      return 'Tiền mặt';
    case '2':
    case 'Card':
      return 'Thẻ (POS)';
    case '3':
    case 'Transfer':
    case 'BankTransfer':
      return 'Chuyển khoản';
    case '4':
    case 'Voucher':
      return 'Phiếu quà tặng';
    case '5':
    case 'Point':
      return 'Điểm thưởng';
    case 'Debit':
      return 'Ghi nợ';
    default:
      return s;
  }
}

String _orderStatusLabel(String s, AppLocalizations l10n) {
  switch (s) {
    case 'draft':
      return l10n.ordersStatusDraft;
    case 'confirmed':
      return l10n.ordersStatusConfirmed;
    case 'delivery':
      return l10n.ordersStatusDelivery;
    case 'completed':
      return l10n.ordersStatusCompleted;
    case 'cancelled':
      return l10n.ordersStatusCancelled;
    case 'refund':
      return l10n.ordersStatusRefund;
    default:
      return s;
  }
}

StatusBadgeTone _toneForOrderStatus(String s) {
  switch (s) {
    case 'completed':
      return StatusBadgeTone.success;
    case 'delivery':
      return StatusBadgeTone.warning;
    case 'confirmed':
      return StatusBadgeTone.info;
    case 'cancelled':
    case 'refund':
      return StatusBadgeTone.error;
    default:
      return StatusBadgeTone.neutral;
  }
}

String _deliveryStatusShort(String s, AppLocalizations l10n) {
  switch (s) {
    case 'pending':
    case 'awaiting_confirm':
    case 'preparing':
    case 'ready':
      return l10n.deliveryStatusPending;
    case 'delivering':
      return l10n.deliveryStatusDelivering;
    case 'completed':
      return l10n.deliveryStatusCompleted;
    case 'failed':
      return l10n.deliveryStatusFailed;
    case 'cancelled':
      return l10n.deliveryStatusCancelled;
    default:
      return s;
  }
}

StatusBadgeTone _toneForDeliveryStatus(String s) {
  switch (s) {
    case 'completed':
      return StatusBadgeTone.success;
    case 'failed':
    case 'cancelled':
      return StatusBadgeTone.error;
    case 'delivering':
      return StatusBadgeTone.warning;
    default:
      return StatusBadgeTone.neutral;
  }
}

String _assigneeDisplayName(String? name, AppLocalizations l10n) {
  final n = name?.trim();
  if (n != null && n.isNotEmpty) return n;
  return l10n.deliveryAssignUnassigned;
}

class SaleOrderDetailScreen extends StatefulWidget {
  const SaleOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<SaleOrderDetailScreen> createState() => _SaleOrderDetailScreenState();
}

class _SaleOrderDetailScreenState extends State<SaleOrderDetailScreen> {
  SaleOrderPublic? _order;
  DeliveryPublic? _linkedDelivery;
  PreparationOrderPublic? _linkedPreparation;
  String? _error;
  bool _loading = true;
  bool _actionBusy = false;
  /// Đơn đã thay đổi (thanh toán, trạng thái, …) — trả về danh sách khi pop.
  bool _listNeedsRefresh = false;
  final _notesCtrl = TextEditingController();
  Timer? _notesDebounce;
  bool _suppressNotesAutosave = false;
  bool _savingNotes = false;
  bool _notesDirty = false;
  String? _managedById;
  String? _saleChannel;
  List<(String id, String name)> _users = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl.addListener(_onNotesDirtyChanged);
    _fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AddressCatalogProvider>().ensureLoaded();
      if (_isElevatedRole(context.read<AuthProvider>().user?.role)) {
        _loadUsers();
      }
    });
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesCtrl.removeListener(_onNotesDirtyChanged);
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNotesDirtyChanged() {
    if (_suppressNotesAutosave) return;
    final current = (_order?.notes ?? '').trim();
    final next = _notesCtrl.text.trim();
    if (_notesDirty != (next != current)) {
      setState(() => _notesDirty = next != current);
    }
  }

  bool _canEdit(SaleOrderPublic o) => o.status == 'draft';

  bool _canEditKiotViet(SaleOrderPublic o) =>
      o.orderSource == 'kiotviet' &&
      o.status != 'cancelled' &&
      o.status != 'refund';

  bool _canEditOrderNotes(SaleOrderPublic o) =>
      o.status != 'cancelled' && o.status != 'refund';

  bool _canOpenEdit(SaleOrderPublic o) => _canEdit(o) || _canEditKiotViet(o);

  bool _canCancel(SaleOrderPublic o) =>
      o.status == 'draft' || o.status == 'confirmed';

  bool _canAssignOrderToMe(SaleOrderPublic o) =>
      o.isOnManagementBoard &&
      (o.status == 'confirmed' || o.status == 'delivery');

  bool _canShowFinishOrderButton(SaleOrderPublic o) =>
      o.status == 'confirmed' || o.status == 'delivery';

  String? _finishOrderBlockedMessage(SaleOrderPublic o, AppLocalizations l10n) {
    if (!_canShowFinishOrderButton(o)) return null;
    final deliveryStatus =
        _linkedDelivery?.status ?? o.linkedDeliveryStatus;
    if (!o.isPaymentCollectedForFinish) {
      return l10n.ordersFinishBlockedPayment;
    }
    if (!o.isPrepReadyForFinish(
      linkedPrepStatus: _linkedPreparation?.status,
      linkedDeliveryStatus: deliveryStatus,
    )) {
      return l10n.ordersFinishBlockedPrep;
    }
    if (!o.isDeliveryDoneForFinish(linkedDeliveryStatus: deliveryStatus)) {
      return l10n.ordersFinishBlockedDelivery;
    }
    return null;
  }

  void _onFinishOrderPressed(SaleOrderPublic o) {
    final l10n = AppLocalizations.of(context);
    final blocked = _finishOrderBlockedMessage(o, l10n);
    if (blocked != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(blocked)));
      return;
    }
    _finishOrder(o);
  }

  bool _canCreateDelivery(SaleOrderPublic o) =>
      o.status == 'confirmed' || o.status == 'delivery';

  String? _effectivePrepId(SaleOrderPublic o) =>
      _linkedPreparation?.id ?? o.linkedPreparationId;

  String? _effectivePrepStatus(SaleOrderPublic o) =>
      _linkedPreparation?.status ?? o.linkedPreparationStatus;

  String? _effectiveDeliveryId(SaleOrderPublic o) =>
      _linkedDelivery?.id ?? o.linkedDeliveryId;

  String? _effectiveDeliveryStatus(SaleOrderPublic o) =>
      _linkedDelivery?.status ?? o.linkedDeliveryStatus;

  String _effectivePrepAssigneeName(SaleOrderPublic o, AppLocalizations l10n) {
    final fromLinked = _linkedPreparation?.assignedUser?.name;
    if (fromLinked != null && fromLinked.trim().isNotEmpty) {
      return fromLinked.trim();
    }
    return _assigneeDisplayName(o.linkedPreparationAssignedName, l10n);
  }

  String _effectiveDeliveryAssigneeName(
    SaleOrderPublic o,
    AppLocalizations l10n,
  ) {
    final fromLinked = _linkedDelivery?.assignedUser?.name;
    if (fromLinked != null && fromLinked.trim().isNotEmpty) {
      return fromLinked.trim();
    }
    return _assigneeDisplayName(o.linkedDeliveryAssignedName, l10n);
  }

  bool _hasLinkedPreparation(SaleOrderPublic o) {
    final id = _effectivePrepId(o);
    final status = _effectivePrepStatus(o);
    return id != null && id.isNotEmpty && status != null && status.isNotEmpty;
  }

  bool _hasLinkedDelivery(SaleOrderPublic o) {
    final id = _effectiveDeliveryId(o);
    final status = _effectiveDeliveryStatus(o);
    return id != null && id.isNotEmpty && status != null && status.isNotEmpty;
  }

  bool _canCreatePreparation(SaleOrderPublic o) {
    if (o.status == 'cancelled' || o.status == 'refund') return false;
    if (_hasLinkedPreparation(o)) return false;
    return true;
  }

  bool _canOpenRecordPayment(SaleOrderPublic o) {
    if (o.status == 'draft' ||
        o.status == 'cancelled' ||
        o.status == 'refund') {
      return false;
    }
    if (o.hasPendingPaymentToConfirm) return true;
    return o.availableToRecordPayment > 0;
  }

  bool _canEditExpectedDelivery(SaleOrderPublic o) =>
      o.status != 'cancelled' && o.status != 'refund';

  void _markListNeedsRefresh() {
    _listNeedsRefresh = true;
  }

  SaleOrderPublic? _popResultForList() =>
      _listNeedsRefresh ? _order : null;

  void _popToCaller() {
    Navigator.of(context).pop(_popResultForList());
  }

  bool _isElevatedRole(String? role) =>
      role == 'admin' || role == 'manager';

  bool _isStaffRole(String? role) =>
      role == 'staff' || _isElevatedRole(role);

  /// Khớp [SaleOrderService.allowedTransition] trên backend (chọn tự do, không theo bước).
  /// Chỉ elevated (admin/manager) mới dùng sheet này; ẩn Đang giao & Hoàn tiền,
  /// thêm Phiếu Tạm để mở lại đơn nhỡ huỷ nhầm.
  List<String> _selectableOrderStatuses(SaleOrderPublic o, String? role) {
    if (o.status == 'draft') return [];
    if (!_isElevatedRole(role)) {
      // Nhân viên chỉ đổi bước tiếp theo, không dùng sheet nhảy cóc.
      return const [];
    }
    final options = <String>[
      'draft',
      'confirmed',
      'completed',
      'cancelled',
    ];
    return options.where((s) => s != o.status).toList();
  }

  bool _canChangeOrderStatus(SaleOrderPublic o, String? role) =>
      _selectableOrderStatuses(o, role).isNotEmpty;

  DateTime? _expectedDeliveryLocal(SaleOrderPublic o) {
    final raw = o.expectedDeliveryAt?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _pickExpectedDelivery(SaleOrderPublic o) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final existing = _expectedDeliveryLocal(o);
    final initial = existing ?? now.add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing ?? initial),
    );
    if (t == null || !mounted) return;
    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    await _saveExpectedDelivery(picked.toUtc().toIso8601String(), l10n);
  }

  Future<void> _clearExpectedDelivery(AppLocalizations l10n) async {
    await _saveExpectedDelivery(null, l10n);
  }

  Future<void> _saveExpectedDelivery(
    String? isoUtc,
    AppLocalizations l10n,
  ) async {
    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.patch<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/expected-delivery',
        data: {'expectedDeliveryAt': isoUtc},
      );
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _actionBusy = false;
        if (data != null) {
          _order = SaleOrderPublic.fromJson(data);
        }
      });
      if (data == null) await _fetch();
      if (!mounted) return;
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.saleOrderExpectedDeliveryUpdated)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _toggleCustomerVip(String customerId, bool newVip) async {
    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.api.patch<void>(
        '/admin/customers/$customerId',
        data: {'isVip': newVip},
      );
      if (mounted) {
        await _fetch();
        _markListNeedsRefresh();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? AppLocalizations.of(context).error);
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _confirmPaymentProposal(String proposalId) async {
    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/payment-proposals/$proposalId/confirm',
      );
      if (!mounted) return;
      if (res.data != null) {
        setState(() {
          _order = SaleOrderPublic.fromJson(res.data!);
          _notesDirty = false;
        });
        _markListNeedsRefresh();
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(AppLocalizations.of(context).success)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? AppLocalizations.of(context).error);
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  bool get _deliveryBlockedByCancelledPrep =>
      _linkedPreparation != null && _linkedPreparation!.status == 'cancelled';

  Future<void> _openCreateDelivery(SaleOrderPublic o) async {
    if (_deliveryBlockedByCancelledPrep) {
      final l10n = AppLocalizations.of(context);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.prepDeliveryBlocked)),
      );
      return;
    }
    final ok = await showCreateDeliverySheet(context, order: o);
    if (ok == true && mounted) {
      await _fetch();
      _markListNeedsRefresh();
    }
  }

  Future<void> _saveOrderNotes() async {
    final o = _order;
    if (o == null || !_canEditOrderNotes(o) || _savingNotes) return;
    final next = _notesCtrl.text.trim();
    final current = (o.notes ?? '').trim();
    if (next == current) return;

    setState(() => _savingNotes = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.patch<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/notes',
        data: {'notes': next.isEmpty ? null : next},
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        _suppressNotesAutosave = true;
        setState(() {
          _order = SaleOrderPublic.fromJson(data);
          _notesDirty = false;
        });
        _suppressNotesAutosave = false;
        if (mounted) {
          AppMessenger.showSnackBar(
            context,
            SnackBar(content: Text(AppLocalizations.of(context).success)),
          );
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final deliveryProv = context.read<DeliveryProvider>();
      final prepProv = context.read<PreparationProvider>();
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}',
      );
      if (!mounted) return;
      final data = res.data;
      if (data == null) {
        setState(() {
          _loading = false;
          _error = '—';
        });
        return;
      }
      final order = SaleOrderPublic.fromJson(data);
      DeliveryPublic? linked;
      // Luôn thử load đơn giao (bất kể trạng thái đơn hàng)
      final list = await deliveryProv.fetchForSaleOrder(order.id);
      if (list.isNotEmpty) linked = list.first;
      final prep = await prepProv.fetchForSaleOrder(order.id);
      if (!mounted) return;
      _notesDebounce?.cancel();
      final priorNotes = (_order?.notes ?? '').trim();
      final localNotes = _notesCtrl.text.trim();
      final notesDirty = localNotes != priorNotes;
      _suppressNotesAutosave = true;
      setState(() {
        _order = order;
        _linkedDelivery = linked;
        _linkedPreparation = prep;
        _managedById = order.managedByUserId;
        _saleChannel = order.saleChannel;
        _loading = false;
        if (!notesDirty) {
          _notesCtrl.text = order.notes ?? '';
          _notesDirty = false;
        }
      });
      _suppressNotesAutosave = false;
    } on DioException catch (e) {
      if (!mounted) return;
      if (isDioUnauthorized(e)) {
        await context.read<AuthProvider>().logout();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = dioErrorMessage(e);
      });
    } catch (e, st) {
      debugPrint('SaleOrderDetail _fetch: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _copyToClipboard(String text, String successMessage) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppMessenger.showSnackBar(context, 
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshFromSource() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saleOrderKiotSyncOverwriteTitle),
        content: Text(l10n.saleOrderKiotSyncOverwriteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      final l10n = AppLocalizations.of(context);
      await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/refresh',
      );
      if (!mounted) return;
      await _fetch();
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.saleOrderDetailRefreshDone)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      final l10n = AppLocalizations.of(context);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
    }
  }

  Future<void> _createPreparation(AppLocalizations l10n) async {
    final assign = await showAssignTargetPicker(
      context,
      showUnassigned: false,
      title: l10n.saleOrderCreatePreparation,
    );
    if (assign == null || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/preparation',
        data: {
          'isPublicBoard': assign.isPublicBoard,
          if (!assign.isPublicBoard && assign.assignedUserId != null)
            'assignedUserId': assign.assignedUserId,
        },
      );
      if (!mounted) return;
      await _fetch();
      if (!mounted) return;
      setState(() => _actionBusy = false);
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(l10n.saleOrderCreatePreparation)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
    }
  }

  Future<void> _openEdit(SaleOrderPublic o) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SaleOrderFlowScreen(initialOrderId: o.id),
      ),
    );
    if (ok == true && mounted) {
      await _fetch();
      _markListNeedsRefresh();
    }
  }

  Future<void> _patchOrderStatus(String next, AppLocalizations l10n) async {
    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.patch<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/status',
        data: {'status': next},
      );
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _actionBusy = false;
        if (data != null) {
          _order = SaleOrderPublic.fromJson(data);
        }
      });
      await _fetch();
      if (!mounted) return;
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderChangeStatusSuccess)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _showChangeStatusSheet(AppLocalizations l10n) async {
    final o = _order;
    if (o == null) return;
    final role = context.read<AuthProvider>().user?.role;
    if (!_isStaffRole(role)) return;
    final options = _selectableOrderStatuses(o, role);
    if (options.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderChangeStatusNoOptions)),
      );
      return;
    }

    final selectedStatus = await showStatusChangeSheet(
      context: context,
      title: l10n.saleOrderChangeStatusTitle,
      currentStatusLabel: _orderStatusLabel(o.status, l10n),
      currentStatusTone: _toneForOrderStatus(o.status),
      statusFieldLabel: l10n.ordersStatusLabel,
      options: options
          .map(
            (s) => StatusChangeOption(
              value: s,
              label: _orderStatusLabel(s, l10n),
              tone: _toneForOrderStatus(s),
            ),
          )
          .toList(),
      confirmLabel: l10n.saleOrderRecordPaymentConfirm,
      cancelLabel: l10n.cancel,
    );

    if (selectedStatus == null || !mounted || selectedStatus == o.status) {
      return;
    }
    await _patchOrderStatus(selectedStatus, l10n);
  }

  Future<void> _cancelOrder(AppLocalizations l10n) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l10n.saleOrderDetailCancelOrder),
          content: Text(l10n.saleOrderDetailCancelConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.saleOrderDetailCancelOrder),
            ),
          ],
        );
      },
    );
    if (go != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/cancel',
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        setState(() {
          _order = SaleOrderPublic.fromJson(data);
          _actionBusy = false;
        });
        _markListNeedsRefresh();
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.saleOrderDetailCancelled)),
        );
      } else {
        setState(() => _actionBusy = false);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      final msg = e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null
          ? (e.response!.data as Map)['message'].toString()
          : (e.message ?? l10n.error);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
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
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _assignOrderToMe(SaleOrderPublic o) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _actionBusy = true);
    try {
      final res = await context.read<AuthProvider>().api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${o.id}/assign',
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        setState(() {
          _order = SaleOrderPublic.fromJson(data);
          _managedById = _order?.managedByUserId;
        });
      } else {
        await _fetch();
      }
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.ordersAssignToMeSuccess)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  List<String?> _managedByDropdownItems() {
    final ids = _users.map((u) => u.$1).toList();
    final cur = _managedById;
    if (cur != null && cur.isNotEmpty && !ids.contains(cur)) {
      ids.insert(0, cur);
    }
    return [null, ...ids];
  }

  String _managedByLabel(String? id, AppLocalizations l10n) {
    if (id == null || id.isEmpty) return l10n.deliveryAssignUnassigned;
    for (final u in _users) {
      if (u.$1 == id) return u.$2;
    }
    final o = _order;
    if (o != null && o.managedByUserId == id) {
      final name = (o.managedBy?.name ?? '').trim();
      if (name.isNotEmpty) return name;
    }
    return id;
  }

  Future<void> _patchManagedBy(String? userId, {String? revertTo}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _actionBusy = true);
    try {
      final res = await context.read<AuthProvider>().api.patch<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/managed-by',
        data: {'managedByUserId': userId},
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        setState(() {
          _order = SaleOrderPublic.fromJson(data);
          _managedById = _order?.managedByUserId;
        });
      } else {
        await _fetch();
      }
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.success)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _managedById = revertTo);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  String _saleChannelShortLabel(String? channel, AppLocalizations l10n) {
    switch (channel) {
      case 'store':
        return l10n.ordersSaleChannelShortStore;
      case 'online':
        return l10n.ordersSaleChannelShortOnline;
      default:
        return '—';
    }
  }

  String _saleChannelMenuLabel(String? channel, AppLocalizations l10n) {
    switch (channel) {
      case 'store':
        return l10n.ordersSaleChannelStore;
      case 'online':
        return l10n.ordersSaleChannelOnline;
      default:
        return l10n.ordersSaleChannelUnset;
    }
  }

  Future<void> _patchSaleChannel(String? channel, {String? revertTo}) async {
    setState(() => _actionBusy = true);
    try {
      final res = await context.read<AuthProvider>().api.patch<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/sale-channel',
        data: {'saleChannel': channel},
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        setState(() {
          _order = SaleOrderPublic.fromJson(data);
          _saleChannel = _order?.saleChannel;
        });
      } else {
        await _fetch();
      }
      _markListNeedsRefresh();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saleChannel = revertTo);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Widget _buildSaleChannelControl(SaleOrderPublic o, AppLocalizations l10n) {
    if (!_canEditOrderNotes(o)) {
      final label = o.saleChannelShortLabel;
      if (label == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: StatusBadge(
          label: label,
          tone: StatusBadgeTone.neutral,
        ),
      );
    }

    const channels = <String?>[null, 'store', 'online'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: channels.contains(_saleChannel) ? _saleChannel : null,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          selectedItemBuilder: (context) => channels
              .map(
                (c) => Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _saleChannelShortLabel(c, l10n),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c == null
                              ? scheme.onSurfaceVariant
                              : AppColors.primary,
                        ),
                  ),
                ),
              )
              .toList(),
          items: channels
              .map(
                (c) => DropdownMenuItem<String?>(
                  value: c,
                  child: Text(_saleChannelMenuLabel(c, l10n)),
                ),
              )
              .toList(),
          onChanged: _actionBusy
              ? null
              : (v) {
                  if (v == _saleChannel) return;
                  final prev = _saleChannel;
                  setState(() => _saleChannel = v);
                  unawaited(_patchSaleChannel(v, revertTo: prev));
                },
        ),
      ),
    );
  }

  Future<void> _finishOrder(SaleOrderPublic o) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _actionBusy = true);
    try {
      final res = await context.read<AuthProvider>().api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${o.id}/finish',
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        setState(() => _order = SaleOrderPublic.fromJson(data));
      } else {
        await _fetch();
      }
      _markListNeedsRefresh();
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.ordersFinishSuccess)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  String _money(int v) => '${formatIntegerWithSeparator(v, _thousandsSep)} đ';

  void _openTransferProofViewer(AppLocalizations l10n, String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: [MediaViewerItem(url: url)],
          initialIndex: 0,
        ),
      ),
    );
  }

  String? _fmtIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final raw = DateTime.tryParse(iso);
    if (raw == null) return iso;
    final d = AppDateTime.toVn(raw);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtIsoDateTime(String iso) {
    final raw = DateTime.tryParse(iso);
    if (raw == null) return iso;
    final d = AppDateTime.toVn(raw);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnlyLabel(String iso) {
    final raw = DateTime.tryParse(iso);
    if (raw == null) return iso;
    final d = AppDateTime.toVn(raw);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _snap(SaleOrderPublic o, String key) {
    final v = o.deliveryAddressSnapshot[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popToCaller();
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.ordersDetailTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _popToCaller,
        ),
        actions: [
          if (!_loading && _order != null) ...[
            IconButton(
              tooltip: l10n.saleOrderDetailRefresh,
              onPressed: _actionBusy ? null : _refreshFromSource,
              icon: const Icon(Icons.refresh_outlined),
            ),
            if (_canOpenEdit(_order!))
              IconButton(
                tooltip: l10n.saleOrderDetailEditOrder,
                onPressed: _actionBusy ? null : () => _openEdit(_order!),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_isStaffRole(context.read<AuthProvider>().user?.role) &&
                _canChangeOrderStatus(
                  _order!,
                  context.read<AuthProvider>().user?.role,
                ))
              IconButton(
                tooltip: l10n.saleOrderChangeStatus,
                onPressed: _actionBusy
                    ? null
                    : () => _showChangeStatusSheet(l10n),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    ErrorBanner(
                      message: _error!,
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    FilledButton.icon(
                      onPressed: _actionBusy ? null : _fetch,
                      icon: const Icon(Icons.refresh_outlined),
                      label: Text(l10n.deliveryRetry),
                    ),
                  ],
                )
              : _order == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        _buildBody(context, l10n, scheme, _order!),
                        if (_actionBusy) ...[
                          const Positioned.fill(
                            child: ModalBarrier(
                              dismissible: false,
                              color: Color(0x33000000),
                            ),
                          ),
                          const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    SaleOrderPublic o,
  ) {
    final rawBase = o.subtotal - o.linesPrepaidTotal;
    final base = rawBase < 0 ? 0 : rawBase;
    final cust = o.customer;
    final phoneDisplay = cust?.phone?.trim();
    final addressCatalog = context.watch<AddressCatalogProvider>();
    final deliveryAddressLine = resolveOrderDeliveryAddress(o, addressCatalog);
    final remainder = _fmtIsoDate(o.scheduledPaymentDate);
    final productsTotal =
        o.lines.fold<int>(0, (sum, line) => sum + (line.quantity * line.unitPrice));

    Widget moneyLine(String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                _money(value),
                style: AppTextStyles.amount(context),
              ),
            ],
          ),
        );

    final lineWidgets = <Widget>[];
    for (var i = 0; i < o.lines.length; i++) {
      final l = o.lines[i];
      final badges = _detailLineBadges(l, l10n);
      final lineTotal = l.quantity * l.unitPrice;
      final code = (l.productCode ?? '').trim();
      final name = (l.productName ?? '').trim();

      if (i > 0) {
        lineWidgets.add(
          Divider(
            height: 20,
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        );
      }
      lineWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? '—' : name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    code.isEmpty ? '—' : code,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      l10n.saleOrderLineTotalLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _money(lineTotal),
                      style: AppTextStyles.amount(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.saleOrderQty} ×${l.quantity} · '
              '${l10n.saleOrderSellingPriceLabel} ${_money(l.unitPrice)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: badges
                    .map((b) => StatusBadge(label: b.$1, tone: b.$2))
                    .toList(),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space3,
        AppSpacing.screenHorizontal,
        AppSpacing.space6,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.copyText,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copyToClipboard(
                      o.displayCode,
                      l10n.ordersOrderIdCopied,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '#${o.displayCode}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSaleChannelControl(o, l10n),
            StatusBadge(
              label: _orderStatusLabel(o.status, l10n),
              tone: _toneForOrderStatus(o.status),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space4),
        SectionCard(
          title: l10n.saleOrderReviewSectionCustomer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final nameText =
                      (cust != null && cust.name.trim().isNotEmpty)
                          ? cust.name.trim()
                          : '—';
                  final isElevated = _isElevatedRole(
                    context.read<AuthProvider>().user?.role,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                nameText,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (cust != null && cust.isVip) ...[
                              const SizedBox(width: 6),
                              StatusBadge(
                                label: 'VIP',
                                tone: StatusBadgeTone.warning,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (cust != null && isElevated)
                        IconButton(
                          tooltip: cust.isVip
                              ? l10n.customerRemoveVip
                              : l10n.customerMarkVip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            cust.isVip
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 20,
                            color: cust.isVip
                                ? const Color(0xFFFFA000)
                                : scheme.onSurfaceVariant,
                          ),
                          onPressed: _actionBusy
                              ? null
                              : () => unawaited(
                                    _toggleCustomerVip(cust.id, !cust.isVip),
                                  ),
                        ),
                      if (nameText != '—')
                        IconButton(
                          tooltip: l10n.saleOrderCopyName,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () =>
                              _copyToClipboard(nameText, l10n.saleOrderCopiedName),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.saleOrderPhoneHint}: ${(phoneDisplay != null && phoneDisplay.isNotEmpty) ? phoneDisplay : '—'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (phoneDisplay != null && phoneDisplay.isNotEmpty)
                    IconButton(
                      tooltip: l10n.saleOrderCopyPhone,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () => _copyToClipboard(
                        phoneDisplay,
                        l10n.saleOrderCopiedPhone,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final addrPlain =
                      deliveryAddressLine == '—' ? '' : deliveryAddressLine;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.saleOrderHouseHint}: '
                          '${addrPlain.isNotEmpty ? addrPlain : '—'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      if (addrPlain.isNotEmpty)
                        IconButton(
                          tooltip: l10n.saleOrderCopyAddress,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () => _copyToClipboard(
                            addrPlain,
                            l10n.saleOrderCopiedAddress,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.saleOrderReviewSectionPayment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              moneyLine(l10n.ordersSubtotal, o.subtotal),
              if (o.linesPrepaidTotal > 0) ...[
                moneyLine(l10n.ordersLinesPrepaid, o.linesPrepaidTotal),
                moneyLine(l10n.saleOrderBaseOwed, base),
              ],
              const Divider(height: 22),
              if (o.paymentTerms == 'partial_prepayment' ||
                  o.paymentTerms == 'paid_in_full') ...[
                if (o.prepaidAmount > 0) ...[
                  const SizedBox(height: 6),
                  moneyLine(l10n.saleOrderPrepaidAmount, o.prepaidAmount),
                ],
                if (remainder != null &&
                    (o.paymentTerms == 'partial_prepayment' ||
                        o.paymentTerms == 'scheduled')) ...[
                  const SizedBox(height: 10),
                  Text(
                    o.paymentTerms == 'partial_prepayment'
                        ? l10n.saleOrderRemainderDueDate
                        : l10n.saleOrderScheduledDate,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              o.amountDue <= 0 ? TextDecoration.lineThrough : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    remainder,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              o.amountDue <= 0 ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Builder(
                  builder: (context) {
                    final paymentDone = o.isPaymentStepDone;
                    const strike = TextDecoration.lineThrough;
                    final labelStyle = Theme.of(context).textTheme.bodyMedium;
                    final labelColor = labelStyle?.color;
                    final amtStyle = AppTextStyles.amount(context);
                    final amtColor = amtStyle.color;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.ordersAmountDue,
                            style: labelStyle?.copyWith(
                              decoration:
                                  paymentDone ? strike : null,
                              decorationColor: labelColor,
                            ),
                          ),
                        ),
                        if (o.amountDue > 0)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE082),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                _money(o.amountDue),
                                style: amtStyle.copyWith(
                                  decoration:
                                      paymentDone ? strike : null,
                                  decorationColor: amtColor,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            _money(o.amountDue),
                            style: amtStyle.copyWith(
                              decoration: paymentDone ? strike : null,
                              decorationColor: amtColor,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (o.payments.isNotEmpty) ...[
                const Divider(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.saleOrderKiotPaymentsTitle,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                      ),
                    ),
                    Text(
                      _money(
                        o.payments
                            .where(_paymentCountsAsCollected)
                            .fold<int>(0, (s, e) => s + e.amount),
                      ),
                      style: AppTextStyles.amount(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(o.payments.length, (i) {
                  final p = o.payments[i];
                  final methodLabel = _localizedPaymentMethod(
                    (p.method ?? '').trim(),
                    l10n,
                  );
                  final dateLabel = p.transDate != null
                      ? _fmtIsoDateTime(p.transDate!)
                      : null;
                  final statusLabel = (p.statusLabel ?? '').trim();
                  final code = (p.code ?? '').trim();
                  final desc = (p.description ?? '').trim();
                  final proofUrl = (p.transferProofUrl ?? '').trim();
                  final schedRaw = (p.scheduledPaymentDate ?? '').trim();
                  final scheduleStrike =
                      p.isScheduleReminder && o.amountDue <= 0;
                  final scheduleDeco = scheduleStrike
                      ? TextDecoration.lineThrough
                      : null;
                  String paymentLineTitle;
                  if (p.isScheduleReminder) {
                    final schedLabel = schedRaw.isNotEmpty
                        ? _formatDateOnlyLabel(schedRaw)
                        : '';
                    paymentLineTitle = schedLabel.isNotEmpty
                        ? '${l10n.saleOrderPaymentScheduleReminderLabel} · $schedLabel'
                        : l10n.saleOrderPaymentScheduleReminderLabel;
                  } else if (p.recordStatus == 'pending') {
                    paymentLineTitle =
                        '$methodLabel · ${l10n.saleOrderRecordPaymentPendingShort}';
                  } else {
                    paymentLineTitle = methodLabel;
                  }
                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${i + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paymentLineTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: scheduleDeco,
                                    ),
                              ),
                            ),
                            Text(
                              _money(p.amount),
                              style: AppTextStyles.amount(context).copyWith(
                                decoration: scheduleDeco,
                              ),
                            ),
                          ],
                        ),
                        if (_isElevatedRole(
                              context.read<AuthProvider>().user?.role,
                            ) &&
                            !p.isScheduleReminder &&
                            p.recordStatus == 'pending') ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: _actionBusy
                                  ? null
                                  : () => unawaited(
                                        _confirmPaymentProposal(p.id),
                                      ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(88, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(l10n.saleOrderConfirmPaymentProposal),
                            ),
                          ),
                        ],
                        if (dateLabel != null ||
                            statusLabel.isNotEmpty ||
                            code.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (dateLabel != null) dateLabel,
                              if (code.isNotEmpty) code,
                              if (statusLabel.isNotEmpty) statusLabel,
                            ].join(' · '),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                        ],
                        if (proofUrl.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _openTransferProofViewer(l10n, proofUrl),
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(
                                l10n.saleOrderRecordPaymentTransferProofView,
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        if (_canOpenRecordPayment(o) &&
            _isStaffRole(context.read<AuthProvider>().user?.role)) ...[
          const SizedBox(height: AppSpacing.space2),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _actionBusy
                  ? null
                  : () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RecordSaleOrderPaymentScreen(
                            orderId: o.id,
                          ),
                        ),
                      );
                      if (changed == true && mounted) {
                        await _fetch();
                        _markListNeedsRefresh();
                      }
                    },
              child: Text(l10n.saleOrderRecordPaymentButton),
            ),
          ),
        ],
        if (_canEditExpectedDelivery(o)) ...[
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.saleOrderExpectedDeliveryTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _actionBusy ? null : () => _pickExpectedDelivery(o),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (o.expectedDeliveryAt ?? '').trim().isNotEmpty
                                ? deliveryScheduledFormatted(
                                      o.expectedDeliveryAt,
                                    ) ??
                                    '—'
                                : l10n.saleOrderExpectedDeliveryTapToSet,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                              color: (o.expectedDeliveryAt ?? '')
                                      .trim()
                                      .isNotEmpty
                                  ? null
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.event_outlined,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if ((o.expectedDeliveryAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _actionBusy
                          ? null
                          : () => _clearExpectedDelivery(l10n),
                      child: Text(l10n.saleOrderExpectedDeliveryClear),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if ((o.expectedDeliveryAt ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.saleOrderExpectedDeliveryTitle,
            child: Text(
              deliveryScheduledFormatted(o.expectedDeliveryAt) ?? '—',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
        if (_canEditOrderNotes(o) || (o.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.saleOrderNotesSectionTitle,
            child: _canEditOrderNotes(o)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _notesCtrl,
                        enabled: !_actionBusy && !_savingNotes,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: l10n.saleOrderNotesHint,
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: (_notesDirty && !_savingNotes && !_actionBusy)
                              ? () => unawaited(_saveOrderNotes())
                              : null,
                          child: _savingNotes
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                )
                              : Text(l10n.save),
                        ),
                      ),
                    ],
                  )
                : Text(
                    o.notes!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.saleOrderReviewSectionProducts,
          titleTrailing: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                _money(productsTotal),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
              ),
            ),
          ),
          child: lineWidgets.isEmpty
              ? Text(
                  l10n.ordersListEmpty,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: lineWidgets,
                ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.saleOrderDetailAuditTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saleOrderCreatedBy,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (o.createdBy?.name ?? '').trim().isNotEmpty
                              ? o.createdBy!.name.trim()
                              : '—',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saleOrderUpdatedBy,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          () {
                            final n = (o.updatedBy?.name ?? '').trim();
                            if (n.isNotEmpty) return n;
                            return '—';
                          }(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saleOrderCreatedAtLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtIsoDateTime(o.createdAt),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.saleOrderLastUpdatedLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtIsoDateTime(o.updatedAt),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              if (_isElevatedRole(context.read<AuthProvider>().user?.role) &&
                  !_loadingUsers)
                TsDropdownFieldNullable<String>(
                  value: _managedByDropdownItems().contains(_managedById)
                      ? _managedById
                      : null,
                  items: _managedByDropdownItems(),
                  itemLabel: (id) => _managedByLabel(id, l10n),
                  labelText: l10n.ordersManagedBy,
                  enabled: !_actionBusy,
                  onChanged: (v) {
                    if (v == _managedById) return;
                    final prev = _managedById;
                    setState(() => _managedById = v);
                    unawaited(_patchManagedBy(v, revertTo: prev));
                  },
                )
              else
                Text(
                  (o.managedBy?.name ?? '').trim().isNotEmpty
                      ? o.managedBy!.name.trim()
                      : l10n.deliveryAssignUnassigned,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (_canAssignOrderToMe(o)) ...[
                const SizedBox(height: AppSpacing.space2),
                FilledButton.icon(
                  onPressed: _actionBusy ? null : () => _assignOrderToMe(o),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l10n.ordersAssignToMe),
                ),
              ],
            ],
          ),
        ),
        if (_canCreatePreparation(o)) ...[
          const SizedBox(height: AppSpacing.space3),
          if (_hasLinkedDelivery(o)) ...[
            Text(
              l10n.saleOrderPrepDeliveryAlreadyExists,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: AppSpacing.space1),
          ],
          SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _actionBusy ? null : () => _createPreparation(l10n),
                icon: const Icon(Icons.checklist_outlined, size: 20),
                label: Text(l10n.saleOrderPrepButtonLabel),
              ),
            ),
          ),
        ],
        if (_hasLinkedPreparation(o)) ...[
          const SizedBox(height: AppSpacing.space4),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: StatusBadge(
                              label: preparationStatusLabel(
                                _effectivePrepStatus(o)!,
                                l10n,
                              ),
                              tone: preparationStatusTone(
                                _effectivePrepStatus(o)!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _actionBusy
                            ? null
                            : () {
                                Navigator.of(context)
                                    .push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PreparationDetailScreen(
                                      preparationId: _effectivePrepId(o)!,
                                    ),
                                  ),
                                )
                                    .then((_) {
                                  if (mounted) _fetch();
                                });
                              },
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        label: Text(
                          l10n.prepViewOrder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.saleOrderWorkerLabel}: '
                  '${_effectivePrepAssigneeName(o, l10n)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
        if (_canCreateDelivery(o) || _hasLinkedDelivery(o)) ...[
          const SizedBox(height: AppSpacing.space4),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: _hasLinkedDelivery(o)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                  child: StatusBadge(
                                    label: _deliveryStatusShort(
                                      _effectiveDeliveryStatus(o)!,
                                      l10n,
                                    ),
                                    tone: _toneForDeliveryStatus(
                                      _effectiveDeliveryStatus(o)!,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _actionBusy
                                  ? null
                                  : () {
                                      Navigator.of(context)
                                          .push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) => DeliveryDetailScreen(
                                            deliveryId: _effectiveDeliveryId(o)!,
                                          ),
                                        ),
                                      )
                                          .then((_) {
                                        if (mounted) _fetch();
                                      });
                                    },
                              icon: const Icon(Icons.visibility_outlined, size: 20),
                              label: Text(
                                l10n.deliveryViewOrder,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.saleOrderWorkerLabel}: '
                        '${_effectiveDeliveryAssigneeName(o, l10n)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: _actionBusy || _deliveryBlockedByCancelledPrep
                        ? null
                        : () => _openCreateDelivery(o),
                    icon: const Icon(Icons.local_shipping_outlined, size: 20),
                    label: Text(l10n.deliveryCreateFromOrder),
                  ),
          ),
        ],
        if (_canCancel(o) || _canShowFinishOrderButton(o)) ...[
          const SizedBox(height: AppSpacing.space4),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: Row(
              children: [
                if (_canCancel(o)) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _actionBusy ? null : () => _cancelOrder(l10n),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: Text(l10n.saleOrderDetailCancelOrder),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                    ),
                  ),
                ],
                if (_canShowFinishOrderButton(o)) ...[
                  if (_canCancel(o)) const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _actionBusy
                          ? null
                          : () => _onFinishOrderPressed(o),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(l10n.saleOrderDetailCompleteOrder),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
