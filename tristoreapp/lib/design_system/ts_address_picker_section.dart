import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import 'ts_add_link_row.dart';
import 'ts_sticky_confirm_bar.dart';

export 'ts_address_radio_tile.dart';
export 'ts_add_link_row.dart';

/// Address list section + optional sticky confirm (DMX Chọn địa chỉ).
class TsAddressPickerSection extends StatelessWidget {
  const TsAddressPickerSection({
    super.key,
    this.sectionTitle,
    required this.children,
    this.addLabel,
    this.onAdd,
    this.confirmLabel,
    this.onConfirm,
    this.confirmEnabled = true,
    this.confirmLoading = false,
  });

  final String? sectionTitle;
  final List<Widget> children;
  final String? addLabel;
  final VoidCallback? onAdd;
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final bool confirmEnabled;
  final bool confirmLoading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sectionTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space2,
              AppSpacing.screenHorizontal,
              AppSpacing.space2,
            ),
            child: Text(
              sectionTitle!,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ...children,
        if (addLabel != null && onAdd != null)
          TsAddLinkRow(label: addLabel!, onTap: onAdd!),
        if (confirmLabel != null && onConfirm != null)
          TsStickyConfirmBar(
            label: confirmLabel!,
            onPressed: onConfirm,
            enabled: confirmEnabled,
            loading: confirmLoading,
          ),
      ],
    );
  }
}
