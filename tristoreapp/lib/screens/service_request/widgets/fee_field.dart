import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.feeAmount > 0 ? '${widget.feeAmount}' : '',
    );
  }

  @override
  void didUpdateWidget(covariant FeeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feeAmount != widget.feeAmount &&
        (int.tryParse(_ctrl.text) ?? 0) != widget.feeAmount) {
      _ctrl.text = widget.feeAmount > 0 ? '${widget.feeAmount}' : '';
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
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => widget.onFeeChanged(int.tryParse(v) ?? 0),
          ),
      ],
    );
  }
}
