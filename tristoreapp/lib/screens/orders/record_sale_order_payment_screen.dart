import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/config/api_config.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_text_styles.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/utils/product_image_compress.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/auth_user.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/products/product_media_widgets.dart';
import 'package:tstore/widgets/integer_thousands_input_formatter.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

const _thousandsSep = ThousandsGroupSeparatorKey.dot;

bool _countsAsCollected(SaleOrderPaymentPublic p) =>
    p.recordStatus != 'pending' && !p.isScheduleReminder;

int _collectedExcludingPending(SaleOrderPublic o) {
  return o.payments
      .where(_countsAsCollected)
      .fold<int>(0, (s, p) => s + p.amount);
}

List<SaleOrderPaymentPublic> _pendingPayments(SaleOrderPublic o) {
  return o.payments
      .where(
        (p) => p.recordStatus == 'pending' && !p.isScheduleReminder,
      )
      .toList();
}

SaleOrderPaymentPublic? _activeScheduleReminder(SaleOrderPublic o) {
  SaleOrderPaymentPublic? latest;
  for (final p in o.payments) {
    if (p.isScheduleReminder) latest = p;
  }
  return latest;
}

class RecordSaleOrderPaymentScreen extends StatefulWidget {
  const RecordSaleOrderPaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<RecordSaleOrderPaymentScreen> createState() =>
      _RecordSaleOrderPaymentScreenState();
}

class _RecordSaleOrderPaymentScreenState
    extends State<RecordSaleOrderPaymentScreen> {
  SaleOrderPublic? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = 'cash';
  bool _scheduleEnabled = false;
  DateTime? _scheduledDate;
  String? _transferProofUrl;
  String? _transferProofLocalPath;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _money(int v) =>
      '${formatIntegerWithSeparator(v, _thousandsSep)} đ';

  bool _canManage(AuthUser? u) =>
      u != null && (u.role == 'admin' || u.role == 'manager');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}',
      );
      final data = res.data;
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _loading = false;
          _error = '—';
        });
        return;
      }
      setState(() {
        _order = SaleOrderPublic.fromJson(data);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _dioMsg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? e.toString();
  }

  String _isoDate(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _tomorrowDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  Future<void> _pickScheduledDate({bool required = false}) async {
    final tomorrow = _tomorrowDate();
    final initial = _scheduledDate ?? tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(tomorrow) ? tomorrow : initial,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) {
      if (required && mounted) {
        setState(() {
          _scheduleEnabled = false;
          _scheduledDate = null;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _scheduleEnabled = true;
      _scheduledDate = DateTime(picked.year, picked.month, picked.day);
      _amountCtrl.clear();
      _method = 'cash';
      _clearTransferProof();
    });
  }

  Future<void> _onScheduleSwitchChanged(bool v) async {
    if (!v) {
      setState(() {
        _scheduleEnabled = false;
        _scheduledDate = null;
      });
      return;
    }
    await _pickScheduledDate(required: true);
  }

  Future<void> _submitProposal(AppLocalizations l10n) async {
    final o = _order;
    if (o == null) return;

    final Map<String, dynamic> data;
    if (_scheduleEnabled) {
      if (_scheduledDate == null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(l10n.saleOrderRecordPaymentScheduleRequired),
          ),
        );
        return;
      }
      data = {
        'amount': o.amountDue,
        'scheduleReminderOnly': true,
        'scheduledPaymentDate': _isoDate(_scheduledDate!),
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };
    } else {
      final amt = parseIntegerLoose(_amountCtrl.text, _thousandsSep);
      if (amt == null || amt < 1) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(l10n.saleOrderRecordPaymentInvalidAmount),
          ),
        );
        return;
      }
      if (amt > o.availableToRecordPayment) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(l10n.saleOrderRecordPaymentAmountTooHigh),
          ),
        );
        return;
      }
      data = {
        'amount': amt,
        'method': _method,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
        if (_method == 'bank_transfer' && _transferProofUrl != null)
          'transferProofUrl': _transferProofUrl,
      };
    }

    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${widget.orderId}/payment-proposals',
        data: data,
      );
      if (!mounted) return;
      final responseData = res.data;
      if (responseData != null) {
        final updated = SaleOrderPublic.fromJson(responseData);
        setState(() {
          _order = updated;
          _busy = false;
          _amountCtrl.clear();
          _noteCtrl.clear();
          _clearTransferProof();
          _method = 'cash';
          _scheduleEnabled = false;
          _scheduledDate = null;
        });
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.saleOrderRecordPaymentSuccess)),
        );
        if (updated.availableToRecordPayment <= 0) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _busy = false);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text(_dioMsg(e))),
      );
    }
  }

  void _clearTransferProof() {
    _transferProofUrl = null;
    _transferProofLocalPath = null;
  }

  Future<void> _pickTransferProof(
    ImageSource source,
    AppLocalizations l10n,
  ) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source);
    if (x == null || !mounted) return;
    setState(() {
      _busy = true;
      _transferProofLocalPath = x.path;
      _transferProofUrl = null;
    });
    final url = await uploadProductImageFromPath(
      x.path,
      context.read<AuthProvider>().api,
    );
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _busy = false;
        _clearTransferProof();
      });
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(l10n.saleOrderRecordPaymentTransferProofUploadFailed),
        ),
      );
      return;
    }
    setState(() {
      _busy = false;
      _transferProofUrl = url;
    });
  }

  void _openTransferProofViewer(String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: [MediaViewerItem(url: url)],
          initialIndex: 0,
        ),
      ),
    );
  }

  Future<void> _confirmProposal(
    AppLocalizations l10n,
    String proposalId,
  ) async {
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/payment-proposals/$proposalId/confirm',
      );
      if (!mounted) return;
      final data = res.data;
      if (data != null) {
        final updated = SaleOrderPublic.fromJson(data);
        setState(() {
          _order = updated;
          _busy = false;
        });
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.saleOrderRecordPaymentConfirmSuccess)),
        );
        if (_pendingPayments(updated).isEmpty) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _busy = false);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(_dioMsg(e))),
      );
    }
  }

  Widget _buildPendingPaymentCard(
    BuildContext context,
    AppLocalizations l10n,
    SaleOrderPaymentPublic pending, {
    required bool manage,
  }) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  pending.method ?? '—',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                _money(pending.amount),
                style: AppTextStyles.amount(context),
              ),
            ],
          ),
          if ((pending.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pending.description!.trim(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if ((pending.scheduledPaymentDate ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.saleOrderRecordPaymentSchedule}: '
              '${_formatScheduledLabel(pending.scheduledPaymentDate!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (pending.requestedBy != null) ...[
            const SizedBox(height: 6),
            Text(
              pending.requestedBy!.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if ((pending.transferProofUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTransferProofThumbnail(
              context,
              l10n,
              pending.transferProofUrl!.trim(),
            ),
          ],
          if (manage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _confirmProposal(l10n, pending.id),
                child: Text(l10n.saleOrderRecordPaymentConfirm),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.saleOrderRecordPaymentTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _order == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            16,
                            AppSpacing.screenHorizontal,
                            32,
                          ),
                          children: [
                            _buildSummary(context, l10n, _order!),
                            const SizedBox(height: AppSpacing.space3),
                            ..._buildPreviousScheduleSection(
                              context,
                              l10n,
                              _order!,
                            ),
                            ..._buildPendingSection(context, l10n, user, _order!),
                            ..._buildFormSection(context, l10n, _order!),
                          ],
                        ),
                        if (_busy)
                          const ModalBarrier(
                            dismissible: false,
                            color: Color(0x33000000),
                          ),
                        if (_busy)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    AppLocalizations l10n,
    SaleOrderPublic o,
  ) {
    final rawBase = o.subtotal - o.linesPrepaidTotal;
    final base = rawBase < 0 ? 0 : rawBase;
    final collected = _collectedExcludingPending(o);
    final pendingTotal = o.pendingPaymentsTotal;
    final available = o.availableToRecordPayment;
    final dueSettled = o.amountDue <= 0;
    Widget row(String label, String value, {bool strike = false}) {
      final deco = strike ? TextDecoration.lineThrough : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: deco,
                    ),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.amount(context).copyWith(
                decoration: deco,
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(l10n.saleOrderRecordPaymentTotalOrder, _money(base)),
          row(l10n.saleOrderRecordPaymentCollected, _money(collected)),
          if (pendingTotal > 0)
            row(l10n.saleOrderRecordPaymentPendingTotal, _money(pendingTotal)),
          row(
            l10n.saleOrderRecordPaymentRemaining,
            _money(o.amountDue),
            strike: dueSettled,
          ),
          if (pendingTotal > 0 && available > 0)
            row(
              l10n.saleOrderRecordPaymentAvailableToRecord,
              _money(available),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPreviousScheduleSection(
    BuildContext context,
    AppLocalizations l10n,
    SaleOrderPublic o,
  ) {
    final sched = _activeScheduleReminder(o);
    if (sched == null) return [];

    final strike = o.amountDue <= 0;
    final deco = strike ? TextDecoration.lineThrough : null;
    final schedRaw = (sched.scheduledPaymentDate ?? '').trim();
    final datePart = schedRaw.isNotEmpty
        ? _formatScheduledLabel(schedRaw)
        : '—';

    return [
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saleOrderRecordPaymentPreviousSchedule,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: deco,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.saleOrderRecordPaymentSchedule}: $datePart',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: deco,
                        ),
                  ),
                ),
                Text(
                  _money(sched.amount),
                  style: AppTextStyles.amount(context).copyWith(
                    decoration: deco,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.space3),
    ];
  }

  List<Widget> _buildPendingSection(
    BuildContext context,
    AppLocalizations l10n,
    AuthUser? user,
    SaleOrderPublic o,
  ) {
    final pendingList = _pendingPayments(o);
    if (pendingList.isEmpty) return [];
    final manage = _canManage(user);
    return [
      Text(
        l10n.saleOrderRecordPaymentPendingTitle,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < pendingList.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _buildPendingPaymentCard(
          context,
          l10n,
          pendingList[i],
          manage: manage,
        ),
      ],
      const SizedBox(height: AppSpacing.space3),
    ];
  }

  List<Widget> _buildFormSection(
    BuildContext context,
    AppLocalizations l10n,
    SaleOrderPublic o,
  ) {
    if (o.availableToRecordPayment <= 0) {
      return [];
    }
    final hasPending = _pendingPayments(o).isNotEmpty;
    return [
      if (hasPending) ...[
        Text(
          l10n.saleOrderRecordPaymentAddAnotherHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
      ],
      if (!hasPending) ...[
        _buildScheduleRow(context, l10n, o),
        const SizedBox(height: 16),
      ],
      if (!hasPending && _scheduleEnabled) ...[
        const SizedBox(height: 12),
        Text(
          l10n.saleOrderRecordPaymentScheduleModeHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.saleOrderRecordPaymentScheduleAmountLabel,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                _money(o.amountDue),
                style: AppTextStyles.amount(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.saleOrderRecordPaymentNote,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : () => _submitProposal(l10n),
            child: Text(l10n.saleOrderRecordPaymentScheduleSubmit),
          ),
        ),
      ] else ...[
      TextField(
        controller: _amountCtrl,
        keyboardType: integerThousandsKeyboardType(_thousandsSep),
        inputFormatters: [
          IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
        ],
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          labelText: l10n.saleOrderRecordPaymentThisTime,
          hintText: '0',
          suffixText: 'đ',
          helperText: hasPending
              ? '${l10n.saleOrderRecordPaymentAvailableToRecord}: '
                  '${_money(o.availableToRecordPayment)}'
              : l10n.saleOrderIntegerThousandsHint,
          helperMaxLines: 2,
        ),
      ),
      const SizedBox(height: 16),
      TsDropdownField<String>(
        value: _method,
        labelText: l10n.saleOrderRecordPaymentMethod,
        items: const ['cash', 'bank_transfer', 'card', 'other'],
        itemLabel: (v) {
          switch (v) {
            case 'bank_transfer':
              return l10n.saleOrderRecordPaymentMethodTransfer;
            case 'card':
              return l10n.saleOrderRecordPaymentMethodCard;
            case 'other':
              return l10n.saleOrderRecordPaymentMethodOther;
            default:
              return l10n.saleOrderRecordPaymentMethodCash;
          }
        },
        enabled: !_busy,
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _method = v;
            if (v != 'bank_transfer') _clearTransferProof();
          });
        },
      ),
      if (_method == 'bank_transfer') ...[
        const SizedBox(height: 16),
        _buildTransferProofSection(context, l10n),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _noteCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l10n.saleOrderRecordPaymentNote,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : () => _submitProposal(l10n),
          child: Text(l10n.saleOrderRecordPaymentSubmit),
        ),
      ),
      ],
    ];
  }

  String _formatScheduledLabel(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return _formatDate(parsed);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Widget _buildTransferProofThumbnail(
    BuildContext context,
    AppLocalizations l10n,
    String url,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.saleOrderRecordPaymentTransferProofTitle,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openTransferProofViewer(url),
              child: SizedBox(
                width: 120,
                height: 120,
                child: ProductImageUrl(
                  url: url,
                  baseUrl: ApiConfig.baseUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => _openTransferProofViewer(url),
            child: Text(l10n.saleOrderRecordPaymentTransferProofView),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferProofSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hasProof =
        (_transferProofUrl ?? '').isNotEmpty ||
        (_transferProofLocalPath ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.saleOrderRecordPaymentTransferProofTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.saleOrderRecordPaymentTransferProofHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _pickTransferProof(ImageSource.gallery, l10n),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: Text(
                  l10n.productsImageFromGallery,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _pickTransferProof(ImageSource.camera, l10n),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: Text(
                  l10n.productsImageFromCamera,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (hasProof) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _transferProofUrl != null
                      ? () => _openTransferProofViewer(_transferProofUrl!)
                      : null,
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: _transferProofUrl != null
                        ? ProductImageUrl(
                            url: _transferProofUrl!,
                            baseUrl: ApiConfig.baseUrl,
                            fit: BoxFit.cover,
                          )
                        : (_transferProofLocalPath != null &&
                                File(_transferProofLocalPath!).existsSync())
                            ? Image.file(
                                File(_transferProofLocalPath!),
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(_clearTransferProof),
                child: Text(l10n.saleOrderRecordPaymentTransferProofRemove),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleRow(
    BuildContext context,
    AppLocalizations l10n,
    SaleOrderPublic o,
  ) {
    final strike = o.amountDue <= 0;
    final deco = strike ? TextDecoration.lineThrough : null;
    final dateLabel = _scheduledDate != null
        ? _formatDate(_scheduledDate!)
        : l10n.saleOrderRecordPaymentSchedulePick;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _busy || !_scheduleEnabled
                    ? null
                    : () => _pickScheduledDate(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.saleOrderRecordPaymentSchedule,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              decoration: deco,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              decoration: deco,
                              color: _scheduleEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight: _scheduleEnabled
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Switch(
              value: _scheduleEnabled,
              onChanged: _busy ? null : _onScheduleSwitchChanged,
            ),
          ],
        ),
    );
  }
}
