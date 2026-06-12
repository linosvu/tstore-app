import 'package:flutter/material.dart';

import 'ts_dropdown_field.dart';

/// Status picker — cùng shell UI với dropdown «Người quản lý».
class TsStatusDropdownField extends StatelessWidget {
  const TsStatusDropdownField({
    super.key,
    this.caption,
    required this.value,
    required this.options,
    required this.labelFor,
    this.onChanged,
    this.enabled = true,
  });

  final String? caption;
  final String value;
  final List<String> options;
  final String Function(String status) labelFor;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canChange = enabled && options.length > 1 && onChanged != null;
    return TsDropdownField<String>(
      value: value,
      items: options,
      itemLabel: labelFor,
      labelText: caption,
      enabled: canChange,
      onChanged: canChange ? onChanged : null,
    );
  }
}
