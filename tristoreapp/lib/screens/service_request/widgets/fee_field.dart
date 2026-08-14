import 'package:flutter/material.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/widgets/integer_thousands_input_formatter.dart';

const _thousandsSep = kAppDefaultThousandsSeparator;

/// Toggle miễn phí + nhập số tiền phí.
class FeeField extends StatefulWidget {
  const FeeField({
    super.key,
    required this.isFree,
    required this.feeAmount,
    required this.onFreeChanged,
    required this.onFeeChanged,
  });

  final bool isFree;
  final int feeAmount;
  final ValueChanged<bool> onFreeChanged;
  final ValueChanged<int> onFeeChanged;

  @override
  State<FeeField> createState() => _FeeFieldState();
}

class _FeeFieldState extends State<FeeField> {
  late final TextEditingController _ctrl;

  String _format(int v) =>
      v > 0 ? formatIntegerWithSeparator(v, _thousandsSep) : '';

  int _parse(String raw) => parseIntegerLoose(raw, _thousandsSep) ?? 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.feeAmount));
  }

  @override
  void didUpdateWidget(covariant FeeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feeAmount != widget.feeAmount &&
        _parse(_ctrl.text) != widget.feeAmount) {
      _ctrl.text = _format(widget.feeAmount);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Miễn phí'),
          value: widget.isFree,
          onChanged: widget.onFreeChanged,
        ),
        if (!widget.isFree)
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Phí hỗ trợ (đ)',
              border: OutlineInputBorder(),
            ),
            keyboardType: integerThousandsKeyboardType(_thousandsSep),
            inputFormatters: [
              IntegerThousandsInputFormatter(separatorKey: _thousandsSep),
            ],
            onChanged: (v) => widget.onFeeChanged(_parse(v)),
          ),
      ],
    );
  }
}
