import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/media_upload.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/preparation_provider.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/screens/preparation/preparation_ui.dart';
import 'package:tstore/widgets/sale_order_code_link_row.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/status_change_sheet.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

class PreparationDetailScreen extends StatefulWidget {
  const PreparationDetailScreen({super.key, required this.preparationId});

  final String preparationId;

  @override
  State<PreparationDetailScreen> createState() => _PreparationDetailScreenState();
}

class _PreparationDetailScreenState extends State<PreparationDetailScreen> {
  PreparationOrderPublic? _item;
  /// Đơn bán đầy đủ (đồng bộ mã KiotViet với màn chi tiết đơn).
  SaleOrderPublic? _linkedSaleOrder;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _loadingUsers = false;
  List<(String id, String name)> _users = [];
  final _noteCtrl = TextEditingController();
  String? _assigneeId;
  Timer? _notesDebounce;
  bool _suppressAutosave = false;
  bool _autosaving = false;
  bool _savingAssignee = false;
  UploadConfig? _uploadConfig;
  final List<PendingMediaUpload> _pendingMedia = [];

  @override
  void initState() {
    super.initState();
    _noteCtrl.addListener(_onNotesChanged);
    _load();
    _loadUploadConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUsers());
  }

  Future<void> _loadUploadConfig() async {
    final api = context.read<PreparationProvider>().api;
    final cfg = await fetchUploadConfig(api);
    if (mounted) setState(() => _uploadConfig = cfg);
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _noteCtrl.removeListener(_onNotesChanged);
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onNotesChanged() {
    if (_suppressAutosave) return;
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(_autosave());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final p = context.read<PreparationProvider>();
    final d = await p.fetchOne(widget.preparationId);
    if (!mounted) return;
    if (d != null) await _enrichLinkedSaleOrder(d);
    if (!mounted) return;
    _notesDebounce?.cancel();
    final priorNotes = (_item?.notes ?? '').trim();
    final localNotes = _noteCtrl.text.trim();
    final notesDirty = localNotes != priorNotes;
    _suppressAutosave = true;
    setState(() {
      _item = d;
      _error = d == null ? 'Không tải được phiếu chuẩn bị.' : null;
      _loading = false;
      if (!notesDirty) {
        _noteCtrl.text = d?.notes ?? '';
      }
      _assigneeId = d?.assignedUserId;
    });
    _suppressAutosave = false;
  }

  Future<void> _enrichLinkedSaleOrder(PreparationOrderPublic item) async {
    var linked = item.saleOrder;
    if (saleOrderDisplayNeedsEnrich(linked)) {
      final p = context.read<PreparationProvider>();
      linked = await p.fetchLinkedSaleOrder(item.saleOrderId) ?? linked;
    }
    if (mounted) setState(() => _linkedSaleOrder = linked);
  }

  SaleOrderPublic? _saleOrderForDisplay(PreparationOrderPublic item) =>
      _linkedSaleOrder ?? item.saleOrder;

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

  Future<void> _toggleLine(PreparationOrderLinePublic line, bool v) async {
    final item = _item;
    if (item == null || _busy) return;
    setState(() => _busy = true);
    final p = context.read<PreparationProvider>();
    try {
      final updated = await p.patchLine(item.id, line.id, isChecked: v);
      if (updated != null && mounted) setState(() => _item = updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _patchTo(String next, {String? successMessage}) async {
    final item = _item;
    if (item == null || _busy) return;
    setState(() => _busy = true);
    final p = context.read<PreparationProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patchStatus(item.id, next);
      if (updated != null && mounted) {
        setState(() => _item = updated);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(successMessage ?? l10n.success)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = e.message ?? 'Lỗi';
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (data != null) {
        msg = data.toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelPreparation() async {
    final item = _item;
    if (item == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.prepCancelReasonTitle),
        content: TextField(
          controller: reasonCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.prepCancelReasonHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(reasonCtrl.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null) return;
    setState(() => _busy = true);
    final p = context.read<PreparationProvider>();
    try {
      final cleaned = reason.trim();
      if (cleaned.isNotEmpty) {
        final existing = item.notes?.trim() ?? '';
        final merged = existing.isEmpty
            ? 'Lý do hủy: $cleaned'
            : '$existing\n\nLý do hủy: $cleaned';
        await p.patch(item.id, {'notes': merged});
      }
      final updated = await p.patchStatus(item.id, 'cancelled');
      if (updated != null && mounted) {
        setState(() => _item = updated);
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(AppLocalizations.of(context).success)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = e.message ?? 'Lỗi';
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      } else if (data != null) {
        msg = data.toString();
      }
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isElevatedRole(String? role) =>
      role == 'admin' || role == 'manager';

  Future<void> _showManagerStatusSheet(PreparationOrderPublic item) async {
    final l10n = AppLocalizations.of(context);
    final options = preparationManagerSelectableStatuses(item.status);
    if (options.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.prepChangeStatusNoOptions)),
      );
      return;
    }

    final picked = await showStatusChangeSheet(
      context: context,
      title: l10n.prepChangeStatusTitle,
      currentStatusLabel: preparationStatusLabel(item.status, l10n),
      currentStatusTone: preparationStatusTone(item.status),
      statusFieldLabel: l10n.deliveryStatus,
      options: options
          .map(
            (s) => StatusChangeOption(
              value: s,
              label: preparationStatusLabel(s, l10n),
              tone: preparationStatusTone(s),
            ),
          )
          .toList(),
      confirmLabel: l10n.saleOrderRecordPaymentConfirm,
      cancelLabel: l10n.cancel,
    );

    if (picked == null || !mounted) return;
    if (picked == 'cancelled') {
      await _cancelPreparation();
      return;
    }
    await _patchTo(picked, successMessage: l10n.prepChangeStatusSuccess);
  }

  String? _saleOrderCreatorId(PreparationOrderPublic item) =>
      _linkedSaleOrder?.createdByUserId ??
      item.saleOrder?.createdByUserId;

  bool _canEditAssignee(PreparationOrderPublic item) {
    if (_isLocked(item.status)) return false;
    final user = context.read<AuthProvider>().user;
    if (user == null) return false;
    if (_isElevatedRole(user.role)) return true;
    final creatorId = _saleOrderCreatorId(item);
    return creatorId != null && creatorId == user.id;
  }

  String _assigneeLabel(String? userId, AppLocalizations l10n) {
    if (userId == null) return l10n.deliveryAssignUnassigned;
    for (final u in _users) {
      if (u.$1 == userId) return u.$2;
    }
    final name = _item?.assignedUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return userId;
  }

  List<String?> _assigneeDropdownItems(PreparationOrderPublic item) {
    final ids = _users.map((u) => u.$1).toList();
    final cur = _assigneeId ?? item.assignedUserId;
    if (cur != null && cur.isNotEmpty && !ids.contains(cur)) {
      ids.insert(0, cur);
    }
    return [null, ...ids];
  }

  Future<void> _saveAssignee(String? userId) async {
    final item = _item;
    if (item == null || _savingAssignee) return;
    if (!_canEditAssignee(item)) return;
    if (userId == item.assignedUserId) return;

    final prev = _assigneeId;
    setState(() => _assigneeId = userId);
    _savingAssignee = true;
    final p = context.read<PreparationProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(item.id, {'assignedUserId': userId});
      if (!mounted) return;
      if (updated != null) {
        var next = updated;
        if (updated.assignedUserId != userId) {
          next = await p.fetchOne(widget.preparationId) ?? updated;
        }
        setState(() {
          _item = next;
          _assigneeId = next.assignedUserId;
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

  Future<void> _autosave() async {
    final item = _item;
    if (item == null || _suppressAutosave || _autosaving) return;

    final notes = _noteCtrl.text.trim();
    final notesChanged = notes != (item.notes?.trim() ?? '');
    if (!notesChanged) return;

    _autosaving = true;
    final p = context.read<PreparationProvider>();
    final l10n = AppLocalizations.of(context);
    try {
      final updated = await p.patch(item.id, {'notes': notes});
      if (updated != null && mounted) {
        setState(() => _item = updated);
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

  Future<void> _addMedia() async {
    final item = _item;
    if (item == null || _isLocked(item.status)) return;
    final l10n = AppLocalizations.of(context);
    final picks = await showMediaPickerSheet(context, config: _uploadConfig);
    if (picks == null || picks.isEmpty || !mounted) return;

    final p = context.read<PreparationProvider>();
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

      final pending = enqueuePendingMedia(pick: pick);
      setState(() => _pendingMedia.add(pending));

      try {
        final result = await uploadPickedMedia(
          pick: pick,
          api: p.api,
          onProgress: (v) {
            if (!mounted) return;
            setState(() => pending.progress = v);
          },
        );
        if (!mounted) return;
        if (result == null || result.url.trim().isEmpty) {
          anyFail = true;
          continue;
        }
        final updated = await p.addImage(
          item.id,
          url: result.url,
          mediaType: result.mediaType,
        );
        if (updated != null && mounted) setState(() => _item = updated);
      } catch (_) {
        anyFail = true;
      } finally {
        if (mounted) {
          setState(() => _pendingMedia.removeWhere((e) => e.id == pending.id));
        }
      }
    }

    if (anyFail && mounted) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaUploadFailed)),
      );
    }
  }

  Future<void> _copyText(String text, String snackMessage) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppMessenger.showSnackBar(context, SnackBar(content: Text(snackMessage)));
  }

  Future<void> _confirmRemovePrepImage(PreparationImage img) async {
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
    final item = _item;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      final p = context.read<PreparationProvider>();
      final updated = await p.removeImage(item.id, url: img.url);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _item = updated);
      } else {
        final full = await p.fetchOne(item.id);
        if (full != null && mounted) {
          setState(() => _item = full);
          await _enrichLinkedSaleOrder(full);
        }
      }
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

  Future<void> _openMediaViewer(List<PreparationImage> images, int index) async {
    if (images.isEmpty) return;
    final safeIndex = index.clamp(0, images.length - 1);
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

  String? _effectiveExpectedLabel(PreparationOrderPublic item) {
    final fromDel = item.linkedDeliveryScheduledAt?.trim();
    final fromOrder = item.saleOrder?.expectedDeliveryAt?.trim();
    final iso = (fromDel != null && fromDel.isNotEmpty) ? fromDel : fromOrder;
    return deliveryScheduledFormatted(iso);
  }

  bool _hasOrderDeliveryContext(PreparationOrderPublic item) {
    final hasIso = (item.linkedDeliveryScheduledAt?.trim().isNotEmpty ?? false) ||
        (item.saleOrder?.expectedDeliveryAt?.trim().isNotEmpty ?? false);
    final hasOrderNotes = (item.saleOrder?.notes ?? '').trim().isNotEmpty;
    return hasIso || hasOrderNotes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.prepTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.prepTitle)),
        body: Center(child: Text(_error ?? '—')),
      );
    }
    final item = _item!;
    final isElevated = _isElevatedRole(
      context.read<AuthProvider>().user?.role,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prepTitle),
        actions: [
          if (isElevated)
            IconButton(
              tooltip: l10n.prepChangeStatus,
              onPressed: _busy ||
                      !preparationManagerCanChangeStatus(item.status)
                  ? null
                  : () => _showManagerStatusSheet(item),
              icon: const Icon(Icons.swap_vert_rounded),
            ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Text(
            item.code,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.space2),
          SaleOrderCodeLinkRow(
            saleOrderId: item.saleOrderId,
            displayCode: resolveSaleOrderDisplayCode(
              saleOrderId: item.saleOrderId,
              saleOrder: _saleOrderForDisplay(item),
            ),
            onCopy: () {
              final orderCode = resolveSaleOrderDisplayCode(
                saleOrderId: item.saleOrderId,
                saleOrder: _saleOrderForDisplay(item),
              );
              _copyText(orderCode, l10n.ordersOrderIdCopied);
            },
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            children: [
              Text(
                l10n.deliveryStatus,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              StatusBadge(
                label: preparationStatusLabel(item.status, l10n),
                tone: preparationStatusTone(item.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          if (_hasOrderDeliveryContext(item)) ...[
            SectionCard(
              title: l10n.prepOrderExpectedFromSale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((item.linkedDeliveryScheduledAt?.trim().isNotEmpty ??
                          false) ||
                      (item.saleOrder?.expectedDeliveryAt?.trim().isNotEmpty ??
                          false)) ...[
                    Text(
                      l10n.saleOrderExpectedDeliveryTitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _effectiveExpectedLabel(item) ?? '—',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  if ((item.saleOrder?.notes ?? '').trim().isNotEmpty) ...[
                    if ((item.linkedDeliveryScheduledAt?.trim().isNotEmpty ??
                            false) ||
                        (item.saleOrder?.expectedDeliveryAt?.trim().isNotEmpty ??
                            false))
                      const SizedBox(height: AppSpacing.space2),
                    Text(
                      l10n.prepOrderNotesFromSale,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.saleOrder!.notes!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          SectionCard(
            title: l10n.prepAssignee,
            child: _buildAssigneeSection(item, l10n),
          ),
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.prepProducts,
            child: Column(
              children: item.lines
                  .map(
                    (line) => CheckboxListTile(
                      value: line.isChecked,
                      onChanged: _isLocked(item.status) || _busy
                          ? null
                          : (v) => _toggleLine(line, v ?? false),
                      title: Text(
                        line.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${l10n.saleOrderQty}: ${line.quantity}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.prepPhotos,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_uploadConfig != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.mediaLimitsHint(
                        _uploadConfig!.maxImageBytes,
                        _uploadConfig!.maxVideoBytes,
                        _uploadConfig!.maxVideoDurationSeconds,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._pendingMedia.map(
                      (pending) => SizedBox(
                        width: 72,
                        height: 72,
                        child: LocalMediaPreviewTile(
                          localPath: pending.localPath,
                          isVideo: pending.isVideo,
                          progress: pending.progress,
                          width: 72,
                          height: 72,
                        ),
                      ),
                    ),
                    ...item.images.asMap().entries.map(
                      (entry) => SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            MediaTile(
                              url: entry.value.url,
                              mediaType: entry.value.mediaType,
                              onTap: () =>
                                  _openMediaViewer(item.images, entry.key),
                            ),
                            if (!_isLocked(item.status) && !_busy)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () =>
                                        _confirmRemovePrepImage(entry.value),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLocked(item.status) ? null : _addMedia,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l10n.mediaAddMedia),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.prepNotes,
            child: TextField(
              controller: _noteCtrl,
              minLines: 2,
              maxLines: 4,
              enabled: !_busy && !_isLocked(item.status),
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          if (item.status == 'pending')
              FilledButton.icon(
                onPressed: _busy ? null : () => _patchTo('in_progress'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.prepStartPreparing),
              ),
            if (item.status == 'in_progress') ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : () => _patchTo('ready'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(l10n.prepMarkReady),
              ),
            ],
            if (item.status == 'pending' ||
                item.status == 'in_progress' ||
                item.status == 'ready' ||
                item.status == 'done') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _cancelPreparation,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(l10n.prepMarkCancelled),
              ),
            ],
        ],
      ),
    );
  }

  bool _isLocked(String status) =>
      status == 'ready' || status == 'done' || status == 'cancelled';

  Widget _buildAssigneeSection(
    PreparationOrderPublic item,
    AppLocalizations l10n,
  ) {
    final canEdit = _canEditAssignee(item);
    if (_loadingUsers && canEdit) {
      return const LinearProgressIndicator();
    }
    if (!canEdit) {
      return Text(
        _assigneeLabel(item.assignedUserId, l10n),
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    final items = _assigneeDropdownItems(item);
    return TsDropdownFieldNullable<String>(
      value: items.contains(_assigneeId) ? _assigneeId : null,
      items: items,
      itemLabel: (v) => _assigneeLabel(v, l10n),
      enabled: !_busy && !_savingAssignee,
      onChanged: (v) => unawaited(_saveAssignee(v)),
    );
  }
}
