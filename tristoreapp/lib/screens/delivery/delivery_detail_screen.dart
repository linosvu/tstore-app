import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/providers/address_catalog_provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/media_upload.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/delivery_provider.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/widgets/sale_order_code_link_row.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/status_change_sheet.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

List<(String, StatusBadgeTone)> _deliveryLineOptionBadges(
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

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen>
    with SingleTickerProviderStateMixin {
  DeliveryPublic? _d;
  SaleOrderPublic? _linkedSaleOrder;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _autosaving = false;
  bool _savingAssignee = false;
  bool _savingMeta = false;
  late final TabController _checkinTabController;
  bool _loadingUsers = false;
  List<(String id, String name)> _users = [];
  List<String> _carrierOptions = [];
  UploadConfig? _uploadConfig;
  final List<PendingMediaUpload> _pendingCheckin = [];
  final _noteCtrl = TextEditingController();
  Timer? _notesDebounce;
  bool _suppressAutosave = false;
  String? _assigneeId;
  String _priority = 'normal';
  String? _shippingCarrier;
  DateTime? _scheduledAt;

  static const List<String> _checkinTypes = [
    'received',
    'installation',
  ];

  @override
  void initState() {
    super.initState();
    _checkinTabController = TabController(length: _checkinTypes.length, vsync: this);
    _noteCtrl.addListener(_onNotesChanged);
    _load();
    _loadUploadConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadCarrierOptions();
    });
  }

  Future<void> _loadUploadConfig() async {
    final api = context.read<AuthProvider>().api;
    final cfg = await fetchUploadConfig(api);
    if (mounted) setState(() => _uploadConfig = cfg);
  }

  Future<void> _loadCarrierOptions() async {
    final list = await context.read<DeliveryProvider>().fetchShippingCarriers();
    if (!mounted) return;
    setState(() => _carrierOptions = list);
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _noteCtrl.removeListener(_onNotesChanged);
    _noteCtrl.dispose();
    _checkinTabController.dispose();
    super.dispose();
  }

  void _onNotesChanged() {
    if (_suppressAutosave) return;
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(_autosaveNotes());
    });
  }

  DateTime? _parseScheduledAt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  void _syncLocalFieldsFromDelivery(DeliveryPublic d) {
    _assigneeId = d.assignedUserId;
    _priority = d.priority;
    _shippingCarrier = d.shippingCarrier;
    _scheduledAt = _parseScheduledAt(d.scheduledAt);
  }

  bool _canEditDelivery(DeliveryPublic d) => !_terminal(d.status);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final p = context.read<DeliveryProvider>();
    final d = await p.fetchOne(widget.deliveryId);
    if (!mounted) return;
    if (d != null) await _enrichLinkedSaleOrder(d);
    if (!mounted) return;
    _notesDebounce?.cancel();
    final priorNotes = (_d?.deliveryNote ?? '').trim();
    final localNotes = _noteCtrl.text.trim();
    final notesDirty = localNotes != priorNotes;
    _suppressAutosave = true;
    setState(() {
      _d = d;
      _error = d == null ? 'Không tải được đơn.' : null;
      _loading = false;
      if (d != null) {
        _syncLocalFieldsFromDelivery(d);
        if (!notesDirty) {
          _noteCtrl.text = d.deliveryNote ?? '';
        }
      }
    });
    _suppressAutosave = false;
  }

  Future<void> _enrichLinkedSaleOrder(DeliveryPublic d) async {
    var linked = d.saleOrder;
    if (saleOrderDisplayNeedsEnrich(linked)) {
      final p = context.read<DeliveryProvider>();
      linked = await p.fetchLinkedSaleOrder(d.saleOrderId) ?? linked;
    }
    if (mounted) setState(() => _linkedSaleOrder = linked);
  }

  SaleOrderPublic? _saleOrderForDisplay(DeliveryPublic d) =>
      _linkedSaleOrder ?? d.saleOrder;

  String _priorityLabel(String p, AppLocalizations l10n) {
    switch (p) {
      case 'low':
        return l10n.deliveryPriorityLow;
      case 'high':
        return l10n.deliveryPriorityHigh;
      case 'urgent':
        return l10n.deliveryPriorityUrgent;
      default:
        return l10n.deliveryPriorityNormal;
    }
  }

  String? _nextStatus(String current) {
    switch (current) {
      case 'pending':
      case 'awaiting_confirm':
      case 'preparing':
      case 'ready':
        return 'delivering';
      case 'delivering':
        return 'completed';
      default:
        return null;
    }
  }

  bool _terminal(String s) =>
      s == 'completed' || s == 'failed' || s == 'cancelled';

  bool _isElevatedRole(String? role) =>
      role == 'admin' || role == 'manager';

  Future<void> _showManagerStatusSheet(DeliveryPublic d) async {
    final l10n = AppLocalizations.of(context);
    final options = deliveryManagerSelectableStatuses(d.status);
    if (options.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.deliveryChangeStatusNoOptions)),
      );
      return;
    }

    final picked = await showStatusChangeSheet(
      context: context,
      title: l10n.deliveryChangeStatusTitle,
      currentStatusLabel: deliveryStatusLabel(d.status, l10n),
      currentStatusTone: deliveryStatusTone(d.status),
      statusFieldLabel: l10n.deliveryStatus,
      options: options
          .map(
            (s) => StatusChangeOption(
              value: s,
              label: deliveryStatusLabel(s, l10n),
              tone: deliveryStatusTone(s),
            ),
          )
          .toList(),
      confirmLabel: l10n.saleOrderRecordPaymentConfirm,
      cancelLabel: l10n.cancel,
    );

    if (picked == null || !mounted) return;
    if (deliveryStatusChangeNeedsReason(picked)) {
      await _promptReasonThenStatus(picked);
      return;
    }
    await _patchStatus(picked, successMessage: l10n.deliveryChangeStatusSuccess);
  }

  Widget _buildPinnedStatusActions(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    DeliveryPublic d,
  ) {
    final next = _nextStatus(d.status);
    if (next == null && d.status != 'delivering') {
      return const SizedBox.shrink();
    }

    final prepStatus = d.linkedPreparationStatus;
    final blockedByPrep = next == 'delivering' &&
        prepStatus != null &&
        prepStatus.isNotEmpty &&
        prepStatus != 'ready' &&
        prepStatus != 'done';

    final saleOrder = _saleOrderForDisplay(d);
    final blockedByPrepForComplete = next == 'completed' &&
        saleOrder != null &&
        !saleOrder.isPrepReadyForFinish(linkedPrepStatus: prepStatus);
    final blocked = blockedByPrep || blockedByPrepForComplete;

    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (next != null) ...[
              FilledButton(
                onPressed: (_busy || blocked)
                    ? null
                    : () {
                        if (next == 'completed') {
                          _patchStatus('completed');
                        } else {
                          _patchStatus(next);
                        }
                      },
                child: Text(
                  '${l10n.deliveryNextStatus}: ${deliveryStatusLabel(next, l10n)}',
                ),
              ),
              if (blockedByPrep) ...[
                const SizedBox(height: 6),
                Text(
                  'Phiếu chuẩn bị phải ở trạng thái "Chuẩn bị xong" trước khi chuyển sang "Đang giao".',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ],
              if (blockedByPrepForComplete) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.ordersFinishBlockedPrep,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ],
            ],
            if (d.status == 'delivering') ...[
              if (next != null) const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _promptReasonThenStatus('failed'),
                child: Text(l10n.deliveryStatusFailed),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _patchStatus(
    String next, {
    String? reason,
    String? successMessage,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final p = context.read<DeliveryProvider>();
      final d = await p.patchStatus(widget.deliveryId, status: next, reason: reason);
      if (!mounted) return;
      if (d != null) {
        setState(() => _d = d);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(successMessage ?? l10n.success)),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (data != null) {
        msg = data.toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } catch (e) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptReasonThenStatus(String status) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deliveryReason),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.deliveryReason),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.ok)),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _patchStatus(status, reason: ctrl.text.trim());
    }
    ctrl.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get<Map<String, dynamic>>(
        '/admin/users',
        queryParameters: {'page': 1, 'limit': 100},
      );
      final data = res.data;
      final items = data?['items'];
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
      if (mounted) setState(() => _users = list);
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  String _assigneeLabel(String? userId, AppLocalizations l10n) {
    if (userId == null || userId.isEmpty) {
      return l10n.deliveryAssignUnassigned;
    }
    for (final u in _users) {
      if (u.$1 == userId) return u.$2;
    }
    return _d?.assignedUser?.name ?? userId;
  }

  List<String?> _assigneeDropdownItems(DeliveryPublic d) {
    final ids = _users.map((u) => u.$1).toList();
    final cur = _assigneeId ?? d.assignedUserId;
    if (cur != null && cur.isNotEmpty && !ids.contains(cur)) {
      ids.insert(0, cur);
    }
    return [null, ...ids];
  }

  Future<void> _saveAssignee(String? userId) async {
    final d = _d;
    if (d == null || _savingAssignee || !_canEditDelivery(d)) return;
    if (userId == d.assignedUserId) return;

    final prev = _assigneeId;
    setState(() => _assigneeId = userId);
    _savingAssignee = true;
    final p = context.read<DeliveryProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(widget.deliveryId, {'assignedUserId': userId});
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _d = updated;
          _assigneeId = updated.assignedUserId;
        });
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.success)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _assigneeId = prev);
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _savingAssignee = false);
    }
  }

  Future<void> _autosaveNotes() async {
    final d = _d;
    if (d == null || _suppressAutosave || _autosaving || !_canEditDelivery(d)) {
      return;
    }

    final notes = _noteCtrl.text.trim();
    final notesChanged = notes != (d.deliveryNote?.trim() ?? '');
    if (!notesChanged) return;

    _autosaving = true;
    final p = context.read<DeliveryProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(widget.deliveryId, {'deliveryNote': notes});
      if (updated != null && mounted) {
        setState(() => _d = updated);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _autosaving = false);
    }
  }

  Future<void> _savePriority(String priority) async {
    final d = _d;
    if (d == null || _savingMeta || !_canEditDelivery(d)) return;
    if (priority == d.priority) return;

    final prev = _priority;
    setState(() => _priority = priority);
    _savingMeta = true;
    final p = context.read<DeliveryProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(widget.deliveryId, {'priority': priority});
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _d = updated;
          _priority = updated.priority;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _priority = prev);
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _savingMeta = false);
    }
  }

  Future<void> _saveScheduledAt(DateTime? scheduled) async {
    final d = _d;
    if (d == null || _savingMeta || !_canEditDelivery(d)) return;

    final iso = scheduled?.toIso8601String();
    final currentIso = d.scheduledAt;
    if (iso == currentIso || (iso == null && (currentIso == null || currentIso.isEmpty))) {
      return;
    }

    final prev = _scheduledAt;
    setState(() => _scheduledAt = scheduled);
    _savingMeta = true;
    final p = context.read<DeliveryProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(widget.deliveryId, {'scheduledAt': iso});
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _d = updated;
          _scheduledAt = _parseScheduledAt(updated.scheduledAt);
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _scheduledAt = prev);
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _savingMeta = false);
    }
  }

  Future<void> _pickScheduledAt() async {
    final d = _d;
    if (d == null || !_canEditDelivery(d) || _savingMeta) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    final next = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _saveScheduledAt(next);
  }

  Future<void> _saveShippingCarrier(String? carrier) async {
    final d = _d;
    if (d == null || _savingMeta || !_canEditDelivery(d)) return;
    if (carrier == d.shippingCarrier) return;

    final prev = _shippingCarrier;
    setState(() => _shippingCarrier = carrier);
    _savingMeta = true;
    final p = context.read<DeliveryProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated =
          await p.patch(widget.deliveryId, {'shippingCarrier': carrier});
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _d = updated;
          _shippingCarrier = updated.shippingCarrier;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _shippingCarrier = prev);
      final data = e.response?.data;
      String msg = e.message ?? l10n.error;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _savingMeta = false);
    }
  }

  Widget _buildAssigneeSection(DeliveryPublic d, AppLocalizations l10n) {
    final canEdit = _canEditDelivery(d);
    if (_loadingUsers && canEdit) {
      return const LinearProgressIndicator();
    }
    if (!canEdit) {
      return Text(
        d.assignedUser?.name ??
            (d.isPublicBoard ? l10n.deliveryAssignUnassigned : '—'),
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    final items = _assigneeDropdownItems(d);
    return TsDropdownFieldNullable<String>(
      value: items.contains(_assigneeId) ? _assigneeId : null,
      items: items,
      itemLabel: (v) => _assigneeLabel(v, l10n),
      enabled: !_busy && !_savingAssignee,
      onChanged: (v) => unawaited(_saveAssignee(v)),
    );
  }

  Widget _buildSchedulePrioritySection(
    DeliveryPublic d,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final canEdit = _canEditDelivery(d);
    final scheduledIso = _scheduledAt?.toIso8601String();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.deliveryScheduled,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deliveryScheduledFormatted(scheduledIso) ?? '—',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (scheduledIso != null) ...[
                    const SizedBox(height: 6),
                    DeliveryCountdownTicker(
                      scheduledAtIso: scheduledIso,
                      l10n: l10n,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (canEdit) ...[
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: _busy || _savingMeta ? null : _pickScheduledAt,
                          child: Text(l10n.edit),
                        ),
                        TextButton(
                          onPressed: _busy || _savingMeta || _scheduledAt == null
                              ? null
                              : () => unawaited(_saveScheduledAt(null)),
                          child: Text(l10n.deliveryClearSchedule),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: canEdit
                  ? TsDropdownField<String>(
                      value: _priority,
                      labelText: l10n.deliveryPriority,
                      items: const ['low', 'normal', 'high', 'urgent'],
                      itemLabel: (v) => deliveryPriorityLabel(v, l10n),
                      enabled: !_busy && !_savingMeta,
                      onChanged: (v) {
                        if (v != null) unawaited(_savePriority(v));
                      },
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deliveryPriority,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _priorityLabel(d.priority, l10n),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (canEdit)
          TsDropdownFieldNullable<String>(
            value: _shippingCarrier,
            labelText: l10n.deliveryShippingCarrier,
            items: [null, ..._carrierOptions],
            itemLabel: (v) =>
                v == null ? l10n.deliveryCarrierNotChosen : v,
            enabled: !_busy && !_savingMeta,
            onChanged: (v) => unawaited(_saveShippingCarrier(v)),
          )
        else ...[
          Text(
            l10n.deliveryShippingCarrier,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            (d.shippingCarrier != null && d.shippingCarrier!.trim().isNotEmpty)
                ? d.shippingCarrier!.trim()
                : '—',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }

  List<PendingMediaUpload> _pendingForType(String type) =>
      _pendingCheckin.where((p) => p.scopeKey == type).toList();

  Future<void> _pickAndUploadMedia(String type) async {
    final l10n = AppLocalizations.of(context);
    final picks = await showMediaPickerSheet(context, config: _uploadConfig);
    if (picks == null || picks.isEmpty || !mounted) return;

    final api = context.read<AuthProvider>().api;
    final p = context.read<DeliveryProvider>();
    var anyFail = false;

    for (final pick in picks) {
      if (!mounted) return;
      final ok = await validateMediaPick(
        context: context,
        pick: pick,
        config: _uploadConfig,
        tooLargeMessage: pick.isVideo
            ? l10n.mediaVideoTooLarge
            : l10n.mediaUploadFailed,
        tooLongMessage: l10n.mediaVideoTooLong,
      );
      if (!ok || !mounted) {
        anyFail = true;
        continue;
      }

      final pending = enqueuePendingMedia(pick: pick, scopeKey: type);
      setState(() => _pendingCheckin.add(pending));

      try {
        final result = await uploadPickedMedia(
          pick: pick,
          api: api,
          onProgress: (v) {
            if (!mounted) return;
            setState(() => pending.progress = v);
          },
        );
        if (!mounted) return;
        if (result == null) {
          anyFail = true;
          continue;
        }
        await p.addCheckinImage(
          widget.deliveryId,
          url: result.url,
          type: type,
          mediaType: result.mediaType,
        );
        if (!mounted) return;
        final full = await p.fetchOne(widget.deliveryId);
        if (!mounted) return;
        if (full != null) setState(() => _d = full);
      } on DioException catch (e) {
        anyFail = true;
        if (!mounted) return;
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(
              e.response?.data?.toString() ?? e.message ?? l10n.error,
            ),
          ),
        );
      } catch (_) {
        anyFail = true;
      } finally {
        if (mounted) {
          setState(
            () => _pendingCheckin.removeWhere((e) => e.id == pending.id),
          );
        }
      }
    }

    if (!mounted) return;
    if (anyFail) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaUploadFailed)),
      );
    } else {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.success)));
    }
  }

  List<DeliveryCheckinImage> _imagesOfType(DeliveryPublic d, String type) {
    return d.checkinImages.where((e) => e.type == type).toList();
  }

  Future<void> _confirmRemoveCheckinImage(
    DeliveryCheckinImage img,
    String type,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deliveryRemoveImage),
        content: Text(l10n.productsRemoveImageTooltip),
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
    setState(() => _busy = true);
    try {
      final p = context.read<DeliveryProvider>();
      await p.removeCheckinImage(
        widget.deliveryId,
        url: img.url,
        type: type,
      );
      if (!mounted) return;
      final full = await p.fetchOne(widget.deliveryId);
      if (!mounted) return;
      if (full != null) setState(() => _d = full);
    } on DioException catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(
            e.response?.data?.toString() ?? e.message ?? l10n.error,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPrepImageViewer(List<LinkedPreparationImage> images, int i) {
    if (images.isEmpty) return Future.value();
    final safeIndex = i.clamp(0, images.length - 1);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: images
              .map(
                (e) => MediaViewerItem(url: e.url, mediaType: e.mediaType),
              )
              .toList(),
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  Widget _prepPhotosStrip(
    BuildContext context,
    AppLocalizations l10n,
    LinkedPreparationBrief prep,
  ) {
    final images = prep.images;
    if (images.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    const thumbGap = 8.0;
    const borderRadius = 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.space2),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: AppSpacing.space3),
        Text(
          l10n.deliveryPrepPhotos,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: AppSpacing.space2),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxSlots = constraints.maxWidth < 300 ? 3 : 4;
            final hasOverflow = images.length > maxSlots;
            final slotCount = hasOverflow ? maxSlots : images.length;
            final thumbSize =
                (constraints.maxWidth - thumbGap * (slotCount - 1)) / slotCount;

            Widget thumbAt(int index, {VoidCallback? onTap}) {
              return SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(borderRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap ?? () => _openPrepImageViewer(images, index),
                    child: MediaTile(
                      url: images[index].url,
                      mediaType: images[index].mediaType,
                      width: thumbSize,
                      height: thumbSize,
                    ),
                  ),
                ),
              );
            }

            Widget overflowThumb(int hiddenCount, int openIndex) {
              return SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(borderRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openPrepImageViewer(images, openIndex),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaTile(
                          url: images[openIndex].url,
                          mediaType: images[openIndex].mediaType,
                          width: thumbSize,
                          height: thumbSize,
                        ),
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          child: Text(
                            '+$hiddenCount',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final children = <Widget>[];
            final visibleThumbs =
                hasOverflow ? maxSlots - 1 : images.length;
            for (var i = 0; i < visibleThumbs; i++) {
              if (i > 0) children.add(const SizedBox(width: thumbGap));
              children.add(thumbAt(i));
            }
            if (hasOverflow) {
              children.add(const SizedBox(width: thumbGap));
              children.add(
                overflowThumb(
                  images.length - visibleThumbs,
                  visibleThumbs,
                ),
              );
            }

            return SizedBox(
              height: thumbSize,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openCheckinImageViewer(
    List<DeliveryCheckinImage> images,
    int initialIndex,
  ) async {
    if (images.isEmpty) return;
    final safeIndex = initialIndex.clamp(0, images.length - 1);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: images
              .map(
                (e) => MediaViewerItem(url: e.url, mediaType: e.mediaType),
              )
              .toList(),
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  String _customerNameDotPhone(SaleOrderCustomerBrief? cust) {
    final name = cust?.name ?? '—';
    final raw = cust?.phone?.trim();
    final phone = (raw != null && raw.isNotEmpty) ? raw : '—';
    return '$name · $phone';
  }

  Future<void> _copyText(String text, String snackMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppMessenger.showSnackBar(context, 
      SnackBar(content: Text(snackMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isElevated = _isElevatedRole(
      context.read<AuthProvider>().user?.role,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deliveryTitle),
        actions: [
          if (_d != null &&
              isElevated &&
              deliveryManagerCanChangeStatus(_d!.status))
            IconButton(
              tooltip: l10n.deliveryChangeStatus,
              onPressed: _loading || _busy
                  ? null
                  : () => _showManagerStatusSheet(_d!),
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading || _busy ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _d == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_terminal(_d!.status))
                              _buildPinnedStatusActions(
                                context,
                                l10n,
                                scheme,
                                _d!,
                              ),
                            Expanded(
                              child: _body(context, l10n, scheme, _d!),
                            ),
                          ],
                        ),
                        if (_busy)
                          const Positioned.fill(
                            child: ModalBarrier(dismissible: false, color: Color(0x33000000)),
                          ),
                        if (_busy)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    DeliveryPublic d,
  ) {
    final cust = d.saleOrder?.customer;
    final addrLine =
        deliveryAddressLine(d, context.watch<AddressCatalogProvider>());
    final terminal = _terminal(d.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space3,
        AppSpacing.screenHorizontal,
        AppSpacing.space6,
      ),
      children: [
        SectionCard(
          title: l10n.deliveryStatus,
          titleTrailing: StatusBadge(
            label: deliveryStatusLabel(d.status, l10n),
            tone: deliveryStatusTone(d.status),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (d.deliveryCode != null && d.deliveryCode!.trim().isNotEmpty)
                    Expanded(
                      child: Text(
                        '${l10n.deliveryDeliveryCode}: ${d.deliveryCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (d.deliveryCode != null && d.deliveryCode!.trim().isNotEmpty)
                    const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${l10n.deliveryAmountDueLabel}: ${deliveryFormatMoney(d.saleOrder?.amountDue ?? 0)}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SaleOrderCodeLinkRow(
                saleOrderId: d.saleOrderId,
                displayCode: resolveSaleOrderDisplayCode(
                  saleOrderId: d.saleOrderId,
                  saleOrder: _saleOrderForDisplay(d),
                ),
                onCopy: () {
                  final orderCode = resolveSaleOrderDisplayCode(
                    saleOrderId: d.saleOrderId,
                    saleOrder: _saleOrderForDisplay(d),
                  );
                  _copyText(orderCode, l10n.ordersOrderIdCopied);
                },
              ),
              if (d.cancelReason != null && d.cancelReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${l10n.deliveryReason}: ${d.cancelReason}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryCustomer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _customerNameDotPhone(cust),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (cust?.phone != null && cust!.phone!.trim().isNotEmpty)
                    IconButton(
                      tooltip: l10n.deliveryCopyPhoneTooltip,
                      onPressed: () => _copyText(
                        cust.phone!.trim(),
                        l10n.deliveryPhoneCopied,
                      ),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 22,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.deliveryAddress,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      addrLine.isEmpty ? '—' : addrLine,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (addrLine.trim().isNotEmpty)
                    IconButton(
                      tooltip: l10n.deliveryCopyAddressTooltip,
                      onPressed: () => _copyText(
                        addrLine.trim(),
                        l10n.deliveryAddressCopied,
                      ),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 22,
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryAssignee,
          child: _buildAssigneeSection(d, l10n),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryScheduleAndPrioritySection,
          child: _buildSchedulePrioritySection(d, l10n, scheme),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryNote,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                enabled: !_busy && _canEditDelivery(d),
              ),
              if (_autosaving)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryProducts,
          child: Column(
            children: [
              for (final line in d.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                  child: Material(
                    color: line.isPrepared
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: line.isPrepared
                            ? const Color(0xFF43A047)
                            : const Color(0xFFFFB74D),
                        width: 1.2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.saleOrderLine?.productName ??
                                      line.saleOrderLineId.substring(0, 8),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'SL giao: ${line.quantityToDeliver}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (line.saleOrderLine != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _deliveryLineOptionBadges(
                                line.saleOrderLine!,
                                l10n,
                              )
                                  .map(
                                    (b) => StatusBadge(label: b.$1, tone: b.$2),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              if (d.linkedPreparation != null)
                _prepPhotosStrip(context, l10n, d.linkedPreparation!),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        SectionCard(
          title: l10n.deliveryImages,
          child: _checkinImagesTabs(context, l10n, scheme, d, terminal),
        ),
        if (!terminal) ...[
          const SizedBox(height: AppSpacing.space4),
          OutlinedButton(
            onPressed: _busy ? null : () => _promptReasonThenStatus('cancelled'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.65)),
            ),
            child: Text(l10n.deliveryCancelShipment),
          ),
        ],
      ],
    );
  }

  Widget _checkinImagesTabs(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    DeliveryPublic d,
    bool terminal,
  ) {
    final tabH = min(420.0, MediaQuery.sizeOf(context).height * 0.46);
    return SizedBox(
      height: tabH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _checkinTabController,
            isScrollable: true,
            tabs: [
              Tab(text: l10n.deliveryTypeReceived),
              Tab(text: l10n.deliveryTypeInstall),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _checkinTabController,
              children: [
                for (final type in _checkinTypes)
                  _checkinTypeTabContent(
                    context,
                    l10n,
                    scheme,
                    d,
                    type,
                    terminal,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkinTypeTabContent(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    DeliveryPublic d,
    String type,
    bool terminal,
  ) {
    final imgs = _imagesOfType(d, type);
    final pending = _pendingForType(type);
    final totalCount = pending.length + imgs.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uploadConfig != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: Text(
                l10n.mediaLimitsHint(
                  _uploadConfig!.maxImageBytes,
                  _uploadConfig!.maxVideoBytes,
                  _uploadConfig!.maxVideoDurationSeconds,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: terminal ? null : () => _pickAndUploadMedia(type),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(
                l10n.mediaAddMedia,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Expanded(
            child: totalCount == 0
                ? Center(
                    child: Text(
                      l10n.deliveryCheckinTabEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: totalCount,
                    itemBuilder: (ctx, i) {
                      if (i < pending.length) {
                        final p = pending[i];
                        return LocalMediaPreviewTile(
                          localPath: p.localPath,
                          isVideo: p.isVideo,
                          progress: p.progress,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      }
                      final img = imgs[i - pending.length];
                      return Material(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InkWell(
                              onTap: () =>
                                  _openCheckinImageViewer(imgs, i - pending.length),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MediaTile(
                                    url: img.url,
                                    mediaType: img.mediaType,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                  if (img.note != null &&
                                      img.note!.trim().isNotEmpty)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        color: Colors.black45,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          img.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!terminal && !_busy)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _confirmRemoveCheckinImage(
                                      img,
                                      type,
                                    ),
                                    customBorder: const CircleBorder(),
                                    child: Tooltip(
                                      message: l10n.deliveryRemoveImage,
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
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
