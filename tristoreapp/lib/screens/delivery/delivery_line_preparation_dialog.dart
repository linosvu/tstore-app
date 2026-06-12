import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/delivery_preparation.dart';
import 'package:tstore/providers/delivery_provider.dart';

Future<DeliveryPublic?> showDeliveryLinePreparationDialog({
  required BuildContext context,
  required String deliveryId,
  required DeliveryLinePublic line,
  required List<DeliveryPreparationChecklistItem> template,
  required AppLocalizations l10n,
  required bool terminal,
}) {
  return showDialog<DeliveryPublic?>(
    context: context,
    builder: (ctx) => _DeliveryLinePreparationDialog(
      deliveryId: deliveryId,
      line: line,
      template: template,
      l10n: l10n,
      terminal: terminal,
    ),
  );
}

class _DeliveryLinePreparationDialog extends StatefulWidget {
  const _DeliveryLinePreparationDialog({
    required this.deliveryId,
    required this.line,
    required this.template,
    required this.l10n,
    required this.terminal,
  });

  final String deliveryId;
  final DeliveryLinePublic line;
  final List<DeliveryPreparationChecklistItem> template;
  final AppLocalizations l10n;
  final bool terminal;

  @override
  State<_DeliveryLinePreparationDialog> createState() =>
      _DeliveryLinePreparationDialogState();
}

class _DeliveryLinePreparationDialogState
    extends State<_DeliveryLinePreparationDialog> {
  late Map<String, bool> _checks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checks = {
      for (final item in widget.template)
        item.id: widget.line.preparationChecklistState[item.id] ?? false,
    };
  }

  bool get _readonly => widget.terminal || widget.line.isPrepared;

  Future<void> _save({required bool confirm}) async {
    if (_readonly) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final p = context.read<DeliveryProvider>();
      final d = await p.patchLine(
        widget.deliveryId,
        widget.line.id,
        preparationChecklistState: Map<String, bool>.from(_checks),
        confirmPreparation: confirm ? true : null,
      );
      if (!mounted) return;
      if (d != null) {
        Navigator.of(context).pop(d);
      } else {
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(context, 
        SnackBar(
          content: Text(
            e.response?.data?.toString() ?? e.message ?? widget.l10n.error,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(context, 
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.line.saleOrderLine?.productName ??
        widget.line.saleOrderLineId.substring(0, 8);
    return AlertDialog(
      title: Text(widget.l10n.deliveryLinePreparationTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (_readonly) ...[
              const SizedBox(height: 8),
              Text(
                widget.l10n.deliveryPreparationReadonlyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            if (widget.template.isEmpty)
              Text(widget.l10n.deliveryPreparationEmptyTemplate)
            else
              ...widget.template.map((item) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  value: _checks[item.id] ?? false,
                  onChanged: _readonly || _saving
                      ? null
                      : (v) => setState(() => _checks[item.id] = v ?? false),
                );
              }),
          ],
        ),
      ),
      actions: [
        if (!_readonly) ...[
          TextButton(
            onPressed: _saving ? null : () => _save(confirm: false),
            child: Text(widget.l10n.deliveryPreparationSaveClose),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _save(confirm: true),
            child: Text(widget.l10n.deliveryPreparationDone),
          ),
        ]
        else
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(widget.l10n.ok),
          ),
      ],
    );
  }
}
