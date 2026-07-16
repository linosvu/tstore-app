import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/delivery_provider.dart';
import 'package:tstore/providers/preparation_provider.dart';
import 'package:tstore/widgets/assign_target_dropdown.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

/// Badge tùy chọn dòng đơn (giống chi tiết đơn bán).
List<(String, StatusBadgeTone)> _sheetLineBadges(
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

/// Bottom sheet tạo đơn giao từ [SaleOrderPublic].
class CreateDeliverySheet extends StatefulWidget {
  const CreateDeliverySheet({super.key, required this.order});

  final SaleOrderPublic order;

  @override
  State<CreateDeliverySheet> createState() => _CreateDeliverySheetState();
}

class _CreateDeliverySheetState extends State<CreateDeliverySheet> {
  final _noteCtrl = TextEditingController();
  late final Map<String, bool> _selected;
  late final Map<String, int> _qty;
  String _assignTarget = kAssignTargetBoard;
  DateTime? _scheduled;
  String _priority = 'normal';
  bool _loadingUsers = false;
  bool _submitting = false;
  List<(String id, String name)> _users = [];
  List<String> _carriers = [];
  String? _shippingCarrier;

  SaleOrderPublic get o => widget.order;

  /// Thời gian dự kiến giao hàng trên đơn bán (local).
  DateTime? _expectedDeliveryFromOrder(SaleOrderPublic order) {
    final raw = order.expectedDeliveryAt?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  void initState() {
    super.initState();
    _selected = {for (final l in o.lines) l.id: true};
    _qty = {for (final l in o.lines) l.id: l.quantity};
    _scheduled =
        _expectedDeliveryFromOrder(o) ?? DateTime.now().add(const Duration(days: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadCarriers();
    });
  }

  Future<void> _loadCarriers() async {
    final p = context.read<DeliveryProvider>();
    final list = await p.fetchShippingCarriers();
    if (!mounted) return;
    setState(() => _carriers = list);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
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
    } catch (_) {
      /* ignore */
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  List<Widget> _lineBadgeSection(SaleOrderLinePublic l) {
    final l10n = AppLocalizations.of(context);
    final badges = _sheetLineBadges(l, l10n);
    if (badges.isEmpty) return <Widget>[];
    return [
      Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.space2,
          right: AppSpacing.space2,
          bottom: AppSpacing.space2,
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: badges
              .map((b) => StatusBadge(label: b.$1, tone: b.$2))
              .toList(),
        ),
      ),
    ];
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final first = now.subtract(const Duration(days: 1));
    final raw = _scheduled ?? now;
    final initial = raw.isBefore(first) ? first : raw;
    final d = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: DateTime(initial.year, initial.month, initial.day),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled ?? now),
    );
    if (t == null || !mounted) return;
    setState(() {
      _scheduled = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final selections = <Map<String, dynamic>>[];
    for (final l in o.lines) {
      if (_selected[l.id] == true) {
        final q = _qty[l.id] ?? 0;
        if (q < 1 || q > l.quantity) {
          AppMessenger.showSnackBar(
            context,
            const SnackBar(content: Text('Số lượng giao không hợp lệ.')),
          );
          return;
        }
        selections.add({'saleOrderLineId': l.id, 'quantityToDeliver': q});
      }
    }
    if (selections.isEmpty) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.deliverySelectLines)));
      return;
    }

    final assign = AssignTargetApiPayload.fromTargetValue(_assignTarget);
    final body = <String, dynamic>{
      'saleOrderId': o.id,
      'lineSelections': selections,
      'isPublicBoard': assign.isPublicBoard,
      'priority': _priority,
      if (_noteCtrl.text.trim().isNotEmpty) 'deliveryNote': _noteCtrl.text.trim(),
      if (_scheduled != null) 'scheduledAt': _scheduled!.toUtc().toIso8601String(),
      if (!assign.isPublicBoard && assign.assignedUserId != null)
        'assignedUserId': assign.assignedUserId,
      if (_shippingCarrier != null && _shippingCarrier!.trim().isNotEmpty)
        'shippingCarrier': _shippingCarrier!.trim(),
    };

    setState(() => _submitting = true);
    try {
      final p = context.read<DeliveryProvider>();
      await p.create(body);
      if (!mounted) return;
      await context.read<PreparationProvider>().refresh();
      AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.deliveryCreateSuccess)));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(
            e.response?.data?.toString() ?? e.message ?? l10n.deliveryCreateFailed,
          ),
        ),
      );
    } catch (e) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space3,
          AppSpacing.screenHorizontal,
          AppSpacing.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.saleOrderBack,
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    l10n.deliveryCreateTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            AssignTargetDropdown(
              value: _assignTarget,
              users: _users,
              loading: _loadingUsers,
              enabled: !_submitting,
              onChanged: (v) => setState(() => _assignTarget = v),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(l10n.deliverySelectLines, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final l in o.lines)
              AppSurfaceCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.space2),
                  padding: const EdgeInsets.all(AppSpacing.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected[l.id] ?? false,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _selected[l.id] = v ?? false),
                        title: Text(l.productName ?? l.productId),
                        subtitle: Text('Tối đa: ${l.quantity}'),
                      ),
                      ..._lineBadgeSection(l),
                      if (_selected[l.id] == true)
                        Row(
                          children: [
                            const Text('Số lượng giao:'),
                            IconButton(
                              onPressed: _submitting || (_qty[l.id] ?? 1) <= 1
                                  ? null
                                  : () => setState(() {
                                        _qty[l.id] = (_qty[l.id] ?? 1) - 1;
                                      }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${_qty[l.id] ?? l.quantity}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed: _submitting ||
                                      (_qty[l.id] ?? l.quantity) >= l.quantity
                                  ? null
                                  : () => setState(() {
                                        final cur = _qty[l.id] ?? l.quantity;
                                        _qty[l.id] = cur + 1;
                                      }),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                    ],
                  ),
              ),
            const SizedBox(height: AppSpacing.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: _submitting ? null : _pickSchedule,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.deliveryScheduled,
                        border: const OutlineInputBorder(),
                      ),
                      child: Text(
                        _scheduled == null
                            ? '—'
                            : DateFormat('dd/MM/yyyy HH:mm').format(_scheduled!),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TsDropdownField<String>(
                    value: _priority,
                    labelText: l10n.deliveryPriority,
                    items: const ['low', 'normal', 'high', 'urgent'],
                    itemLabel: (v) => deliveryPriorityLabel(v, l10n),
                    enabled: !_submitting,
                    onChanged: (v) =>
                        setState(() => _priority = v ?? 'normal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            TsDropdownFieldNullable<String>(
              value: _shippingCarrier,
              labelText: l10n.deliveryShippingCarrier,
              items: [null, ..._carriers],
              itemLabel: (v) =>
                  v == null ? l10n.deliveryCarrierNotChosen : v,
              enabled: !_submitting,
              onChanged: (v) => setState(() => _shippingCarrier = v),
            ),
            const SizedBox(height: AppSpacing.space2),
            TextField(
              controller: _noteCtrl,
              enabled: !_submitting,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.deliveryNote,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(l10n.saleOrderBack),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.deliverySubmit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiển thị bottom sheet tạo đơn giao.
Future<bool?> showCreateDeliverySheet(
  BuildContext context, {
  required SaleOrderPublic order,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => CreateDeliverySheet(order: order),
  );
}
