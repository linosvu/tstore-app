import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/app_date_time.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/repair_orders_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'repair_ui.dart';

class CreateRepairOrderScreen extends StatefulWidget {
  const CreateRepairOrderScreen({super.key});

  @override
  State<CreateRepairOrderScreen> createState() => _CreateRepairOrderScreenState();
}

class _CreateRepairOrderScreenState extends State<CreateRepairOrderScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'received';
  String _priority = 'normal';
  String? _received;
  String? _promised;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _received = AppDateTime.calendarDate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _itemCtrl.dispose();
    _issueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty && digits.length < 9) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderNeedNameOrPhone)),
      );
      return;
    }
    if (_itemCtrl.text.trim().isEmpty || _issueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập thiết bị và nội dung sửa chữa.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final p = context.read<RepairOrdersProvider>();
    final body = <String, dynamic>{
      'customerName': name.isNotEmpty ? name : _phoneCtrl.text.trim(),
      'customerPhone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'itemDescription': _itemCtrl.text.trim(),
      'issueDescription': _issueCtrl.text.trim(),
      'status': _status,
      'priority': _priority,
      'receivedDate': _received,
      if (_promised != null && _promised!.isNotEmpty) 'promisedDate': _promised,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    try {
      final created = await p.create(body);
      if (!mounted) return;
      if (created != null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.repairCreated)),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không tạo được đơn.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repairFormTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          SectionCard(
            title: l10n.repairFormTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.repairCustomerName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(labelText: l10n.repairCustomerPhone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _itemCtrl,
                  decoration: InputDecoration(labelText: l10n.repairItemDescription),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueCtrl,
                  decoration: InputDecoration(labelText: l10n.repairIssueDescription),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TsDropdownField<String>(
                        value: _status,
                        labelText: l10n.repairStatus,
                        items: repairStatuses,
                        itemLabel: (s) => repairStatusLabel(s, l10n),
                        onChanged: (v) => setState(() => _status = v ?? 'received'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TsDropdownField<String>(
                        value: _priority,
                        labelText: l10n.repairPriority,
                        items: repairPriorities,
                        itemLabel: (p) => repairPriorityLabel(p, l10n),
                        onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _dateRow(l10n.repairReceivedDate, _received, (d) {
                  setState(() {
                    _received =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  });
                }),
                const SizedBox(height: 8),
                _dateRow(l10n.repairPromisedDate, _promised, (d) {
                  setState(() {
                    _promised =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  });
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(labelText: l10n.repairNotes),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(l10n),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.repairSubmit),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, String? value, ValueChanged<DateTime> onPick) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(value ?? '—'),
          ),
        ),
        IconButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) onPick(d);
          },
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    );
  }
}
