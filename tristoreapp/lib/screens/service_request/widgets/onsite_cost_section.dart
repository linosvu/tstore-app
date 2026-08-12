import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/integer_thousands_input_formatter.dart';
import 'package:tstore/widgets/ui/section_card.dart';

const _thousandsSep = ThousandsGroupSeparatorKey.dot;

const freeReasonOptions = <(String, String)>[
  ('warranty', 'Bảo hành'),
  ('maintenance', 'Bảo trì định kỳ'),
  ('vip', 'Khách VIP'),
  ('other', 'Khác'),
];

const paymentMethodOptions = <(String, String)>[
  ('cash', 'Tiền mặt'),
  ('bank_transfer', 'Chuyển khoản'),
  ('unpaid', 'Chưa thu'),
];

const suggestedCostLabels = [
  'Công sửa chữa',
  'Linh kiện',
  'Phí di chuyển',
];

String freeReasonLabel(String? code) {
  for (final o in freeReasonOptions) {
    if (o.$1 == code) return o.$2;
  }
  return code ?? '—';
}

String paymentMethodLabel(String? code) {
  for (final o in paymentMethodOptions) {
    if (o.$1 == code) return o.$2;
  }
  return code ?? '—';
}

String formatTicketMoney(int v) =>
    '${formatIntegerWithSeparator(v, _thousandsSep)} đ';

/// Khối chi phí HTN — khóa sau khi khách đã ký.
class OnsiteCostSection extends StatefulWidget {
  const OnsiteCostSection({
    super.key,
    required this.ticket,
    required this.readOnly,
    required this.onUpdated,
  });

  final ServiceTicketPublic ticket;
  final bool readOnly;
  final ValueChanged<ServiceTicketPublic> onUpdated;

  @override
  State<OnsiteCostSection> createState() => _OnsiteCostSectionState();
}

class _OnsiteCostSectionState extends State<OnsiteCostSection> {
  String? _mode;
  String? _freeReason;
  String? _paymentMethod;
  final _noteCtrl = TextEditingController();
  final _rows = <_CostRowCtrls>[];
  bool _busy = false;
  bool _dirty = false;

  bool get _lockedByCustomerSig => widget.ticket.signatures.any(
        (s) => s.stage == 'onsite_result' && s.signer == 'customer',
      );

  bool get _canEdit => !widget.readOnly && !_lockedByCustomerSig && !_busy;

  @override
  void initState() {
    super.initState();
    _hydrateFromTicket(widget.ticket);
  }

  @override
  void didUpdateWidget(covariant OnsiteCostSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id ||
        oldWidget.ticket.updatedAt != widget.ticket.updatedAt ||
        oldWidget.ticket.costMode != widget.ticket.costMode ||
        oldWidget.ticket.feeAmount != widget.ticket.feeAmount ||
        oldWidget.ticket.signatures.length != widget.ticket.signatures.length) {
      if (!_dirty) _hydrateFromTicket(widget.ticket);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _hydrateFromTicket(ServiceTicketPublic t) {
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    _mode = t.costMode;
    _freeReason = t.freeReason;
    _paymentMethod = t.paymentMethod;
    _noteCtrl.text = t.costNote ?? '';
    if (t.costItems.isNotEmpty) {
      for (final it in t.costItems) {
        _rows.add(_CostRowCtrls.fromItem(it));
      }
    } else {
      for (final label in suggestedCostLabels) {
        _rows.add(_CostRowCtrls(content: label, amount: 0));
      }
    }
    _dirty = false;
  }

  int get _total {
    var s = 0;
    for (final r in _rows) {
      s += r.amount;
    }
    return s;
  }

  String? validationError() {
    if (_mode != 'free' && _mode != 'paid') {
      return 'Chọn Miễn phí hoặc Có tính phí.';
    }
    if (_mode == 'free' && (_freeReason == null || _freeReason!.isEmpty)) {
      return 'Chọn lý do miễn phí.';
    }
    if (_mode == 'paid') {
      if (_total <= 0) return 'Tổng tiền phải lớn hơn 0.';
      if (_paymentMethod == null || _paymentMethod!.isEmpty) {
        return 'Chọn hình thức thanh toán.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = validationError();
    if (err != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(err)));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'costMode': _mode,
        if (_noteCtrl.text.trim().isNotEmpty) 'costNote': _noteCtrl.text.trim(),
        if (_noteCtrl.text.trim().isEmpty) 'costNote': null,
      };
      if (_mode == 'free') {
        body['freeReason'] = _freeReason;
      } else {
        body['paymentMethod'] = _paymentMethod;
        body['items'] = [
          for (final r in _rows)
            if (r.content.trim().isNotEmpty || r.amount > 0)
              {'content': r.content.trim(), 'amount': r.amount},
        ];
      }
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchTicketCost(widget.ticket.id, body);
      if (!mounted) return;
      if (updated != null) {
        _dirty = false;
        _hydrateFromTicket(updated);
        widget.onUpdated(updated);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã lưu chi phí.')),
        );
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Chi phí',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lockedByCustomerSig && !widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Khách đã ký — xóa chữ ký khách nếu cần sửa chi phí.',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Miễn phí'),
            value: 'free',
            groupValue: _mode,
            onChanged: !_canEdit
                ? null
                : (v) => setState(() {
                      _mode = v;
                      _dirty = true;
                    }),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Có tính phí'),
            value: 'paid',
            groupValue: _mode,
            onChanged: !_canEdit
                ? null
                : (v) => setState(() {
                      _mode = v;
                      _dirty = true;
                    }),
          ),
          if (_mode == 'free') ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _freeReason,
              decoration: const InputDecoration(labelText: 'Lý do miễn phí *'),
              items: [
                for (final o in freeReasonOptions)
                  DropdownMenuItem(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: !_canEdit
                  ? null
                  : (v) => setState(() {
                        _freeReason = v;
                        _dirty = true;
                      }),
            ),
          ],
          if (_mode == 'paid') ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _rows.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rows[i].contentCtrl,
                      enabled: _canEdit,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung',
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rows[i].amountCtrl,
                      enabled: _canEdit,
                      keyboardType: integerThousandsKeyboardType(_thousandsSep),
                      inputFormatters: [
                        IntegerThousandsInputFormatter(
                          separatorKey: _thousandsSep,
                        ),
                      ],
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ),
                  if (_canEdit)
                    IconButton(
                      onPressed: _rows.length <= 1
                          ? null
                          : () => setState(() {
                                _rows.removeAt(i).dispose();
                                _dirty = true;
                              }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_canEdit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _rows.add(_CostRowCtrls());
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm khoản'),
                ),
              ),
            Text(
              'Tổng cộng: ${formatTicketMoney(_total)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Hình thức thanh toán *',
              ),
              items: [
                for (final o in paymentMethodOptions)
                  DropdownMenuItem(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: !_canEdit
                  ? null
                  : (v) => setState(() {
                        _paymentMethod = v;
                        _dirty = true;
                      }),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            enabled: _canEdit,
            decoration: const InputDecoration(labelText: 'Ghi chú chi phí'),
            maxLines: 2,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _busy ? null : _save,
                child: const Text('Lưu chi phí'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CostRowCtrls {
  _CostRowCtrls({String content = '', int amount = 0})
      : contentCtrl = TextEditingController(text: content),
        amountCtrl = TextEditingController(
          text: amount > 0
              ? formatIntegerWithSeparator(amount, _thousandsSep)
              : '',
        );

  factory _CostRowCtrls.fromItem(TicketCostItem it) =>
      _CostRowCtrls(content: it.content, amount: it.amount);

  final TextEditingController contentCtrl;
  final TextEditingController amountCtrl;

  String get content => contentCtrl.text;
  int get amount => parseIntegerLoose(amountCtrl.text, _thousandsSep) ?? 0;

  void dispose() {
    contentCtrl.dispose();
    amountCtrl.dispose();
  }
}
