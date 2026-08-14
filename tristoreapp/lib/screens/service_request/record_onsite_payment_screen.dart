import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/config/api_config.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_text_styles.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/utils/product_image_compress.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/models/auth_user.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/screens/products/product_media_widgets.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

const _thousandsSep = ThousandsGroupSeparatorKey.dot;

class RecordOnsitePaymentScreen extends StatefulWidget {
  const RecordOnsitePaymentScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<RecordOnsitePaymentScreen> createState() =>
      _RecordOnsitePaymentScreenState();
}

class _RecordOnsitePaymentScreenState extends State<RecordOnsitePaymentScreen> {
  ServiceTicketPublic? _ticket;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  final _noteCtrl = TextEditingController();
  String _method = 'cash';
  DateTime? _scheduledDate;
  final List<_ProofItem> _proofs = [];
  bool _uploadingProof = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _canManage(AuthUser? u) =>
      u != null && (u.role == 'admin' || u.role == 'manager');

  String _money(int v) =>
      '${formatIntegerWithSeparator(v, _thousandsSep)} đ';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  DateTime _tomorrowDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  String _dioMsg(Object e) {
    if (e is DioException) {
      return ServiceRequestsProvider.dioMessage(e);
    }
    return e.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await context
          .read<ServiceRequestsProvider>()
          .fetchTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _loading = false;
        if (t == null) _error = '—';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _dioMsg(e);
      });
    }
  }

  List<ServiceTicketPaymentPublic> _pendingOf(ServiceTicketPublic t) =>
      t.payments.where((p) => p.isPending).toList();

  bool _canPropose(ServiceTicketPublic t) =>
      t.canRecordOnsitePayment && !t.hasPendingPayment && !t.isPaidCollecting;

  Future<void> _pickScheduledDate() async {
    final tomorrow = _tomorrowDate();
    final initial = _scheduledDate ?? tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(tomorrow) ? tomorrow : initial,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  String? get _encodedProof {
    final urls = [
      for (final p in _proofs)
        if ((p.url ?? '').trim().isNotEmpty) p.url!.trim(),
    ];
    if (urls.isEmpty) return null;
    if (urls.length == 1) return urls.first;
    return jsonEncode(urls);
  }

  Future<void> _pickProof(ImageSource source, AppLocalizations l10n) async {
    final picker = ImagePicker();
    final List<XFile> files;
    if (source == ImageSource.gallery) {
      files = await picker.pickMultiImage(imageQuality: 92);
    } else {
      final x = await picker.pickImage(source: source, imageQuality: 92);
      files = x == null ? const [] : [x];
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _uploadingProof = true);
    final api = context.read<AuthProvider>().api;
    var anyFail = false;
    for (final x in files) {
      if (!mounted) return;
      final item = _ProofItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${x.path.hashCode}',
        localPath: x.path,
      );
      setState(() => _proofs.add(item));
      final url = await uploadProductImageFromPath(
        x.path,
        api,
        onProgress: (v) {
          if (!mounted) return;
          setState(() => item.progress = v);
        },
      );
      if (!mounted) return;
      if (url == null || url.trim().isEmpty) {
        anyFail = true;
        setState(() {
          item.failed = true;
          _proofs.removeWhere((e) => e.id == item.id);
        });
        continue;
      }
      setState(() {
        item.url = url;
        item.progress = 1;
      });
    }
    if (!mounted) return;
    setState(() => _uploadingProof = false);
    if (anyFail) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(l10n.saleOrderRecordPaymentTransferProofUploadFailed),
        ),
      );
    }
  }

  void _openProofs(List<String> urls, {int initialIndex = 0}) {
    if (urls.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: [for (final u in urls) MediaViewerItem(url: u)],
          initialIndex: initialIndex.clamp(0, urls.length - 1),
        ),
      ),
    );
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final t = _ticket;
    if (t == null || _busy) return;
    if (_method == 'unpaid' && _scheduledDate == null) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderRecordPaymentScheduleRequired)),
      );
      return;
    }
    if (_method == 'bank_transfer' && _encodedProof == null) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderRecordPaymentTransferProofHint)),
      );
      return;
    }

    final body = <String, dynamic>{
      'method': _method,
      if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      if (_method == 'unpaid')
        'scheduledPaymentDate': _isoDate(_scheduledDate!),
      if (_method == 'bank_transfer') 'transferProofUrl': _encodedProof,
    };

    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .createOnsitePaymentProposal(widget.ticketId, body);
      if (!mounted) return;
      if (updated == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _ticket = updated;
        _busy = false;
        _noteCtrl.clear();
        _proofs.clear();
        _method = 'cash';
        _scheduledDate = null;
      });
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderRecordPaymentSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(context, SnackBar(content: Text(_dioMsg(e))));
    }
  }

  Future<void> _confirm(AppLocalizations l10n, String id) async {
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ServiceRequestsProvider>()
          .confirmOnsitePaymentProposal(id);
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _ticket = updated;
          _busy = false;
        });
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.saleOrderRecordPaymentConfirmSuccess)),
        );
        if (_pendingOf(updated).isEmpty) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppMessenger.showSnackBar(context, SnackBar(content: Text(_dioMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _ticket;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.saleOrderRecordPaymentTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || t == null
              ? Center(child: Text(_error ?? '—'))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    _summary(context, l10n, t),
                    const SizedBox(height: 12),
                    for (final p in _pendingOf(t)) ...[
                      _pendingCard(context, l10n, p),
                      const SizedBox(height: 12),
                    ],
                    if (_canPropose(t)) _form(context, l10n, t),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _summary(
    BuildContext context,
    AppLocalizations l10n,
    ServiceTicketPublic t,
  ) {
    Widget row(String label, String value, {bool highlight = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: AppTextStyles.amount(context).copyWith(
                fontWeight: highlight ? FontWeight.w700 : null,
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
          row(l10n.saleOrderRecordPaymentTotalOrder, _money(t.feeAmount)),
          row(
            l10n.saleOrderRecordPaymentRemaining,
            _money(t.displayAmountDue),
            highlight: t.displayAmountDue > 0,
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(
    BuildContext context,
    AppLocalizations l10n,
    ServiceTicketPaymentPublic p,
  ) {
    final manage = _canManage(context.read<AuthProvider>().user);
    return SectionCard(
      title: l10n.saleOrderRecordPaymentPendingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.methodLabel ?? p.method,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(_money(p.amount), style: AppTextStyles.amount(context)),
            ],
          ),
          if ((p.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.description!.trim()),
          ],
          if ((p.scheduledPaymentDate ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.saleOrderRecordPaymentSchedule}: ${p.scheduledPaymentDate}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (p.proofImageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < p.proofImageUrls.length; i++)
                  InkWell(
                    onTap: () =>
                        _openProofs(p.proofImageUrls, initialIndex: i),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: ProductImageUrl(
                        url: p.proofImageUrls[i],
                        baseUrl: ApiConfig.baseUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (manage) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _confirm(l10n, p.id),
              child: Text(l10n.saleOrderConfirmPaymentProposal),
            ),
          ],
        ],
      ),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    ServiceTicketPublic t,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _method == 'unpaid'
                      ? l10n.saleOrderRecordPaymentScheduleAmountLabel
                      : l10n.saleOrderRecordPaymentRemaining,
                ),
              ),
              Text(_money(t.feeAmount), style: AppTextStyles.amount(context)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TsDropdownField<String>(
          value: _method,
          labelText: l10n.saleOrderRecordPaymentMethod,
          items: const ['cash', 'bank_transfer', 'unpaid'],
          itemLabel: (v) {
            switch (v) {
              case 'bank_transfer':
                return l10n.saleOrderRecordPaymentMethodTransfer;
              case 'unpaid':
                return l10n.saleOrderRecordPaymentSchedule;
              default:
                return l10n.saleOrderRecordPaymentMethodCash;
            }
          },
          enabled: !_busy,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _method = v);
          },
        ),
        if (_method == 'bank_transfer') ...[
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _uploadingProof
                      ? null
                      : () => _pickProof(ImageSource.gallery, l10n),
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: Text(l10n.productsImageFromGallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy || _uploadingProof
                      ? null
                      : () => _pickProof(ImageSource.camera, l10n),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: Text(l10n.productsImageFromCamera),
                ),
              ),
            ],
          ),
          if (_proofs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _proofs)
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: item.url != null
                        ? ProductImageUrl(
                            url: item.url!,
                            baseUrl: ApiConfig.baseUrl,
                            fit: BoxFit.cover,
                          )
                        : LocalMediaPreviewTile(
                            localPath: item.localPath,
                            isVideo: false,
                            progress: item.progress,
                            width: 88,
                            height: 88,
                            loading: item.url == null && !item.failed,
                            error: item.failed,
                          ),
                  ),
              ],
            ),
          ],
        ],
        if (_method == 'unpaid') ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.saleOrderRecordPaymentSchedule),
            subtitle: Text(
              _scheduledDate == null
                  ? l10n.saleOrderRecordPaymentSchedulePick
                  : _formatDate(_scheduledDate!),
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: _busy ? null : _pickScheduledDate,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: l10n.saleOrderRecordPaymentNote,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || _uploadingProof ? null : () => _submit(l10n),
          child: Text(
            _method == 'unpaid'
                ? l10n.saleOrderRecordPaymentScheduleSubmit
                : l10n.saleOrderRecordPaymentSubmit,
          ),
        ),
      ],
    );
  }
}

class _ProofItem {
  _ProofItem({required this.id, required this.localPath});

  final String id;
  final String localPath;
  String? url;
  double? progress;
  bool failed = false;
}
