import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/support_tickets_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import '../repair/repair_ui.dart';

class CreateSupportTicketScreen extends StatefulWidget {
  const CreateSupportTicketScreen({super.key});

  @override
  State<CreateSupportTicketScreen> createState() => _CreateSupportTicketScreenState();
}

class _CreateSupportTicketScreenState extends State<CreateSupportTicketScreen> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _category = 'other';
  String _priority = 'normal';
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (_subjectCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập tiêu đề và nội dung ticket.')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderNeedNameOrPhone)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final created = await context.read<SupportTicketsProvider>().create({
        'subject': _subjectCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'priority': _priority,
        'customerName': name,
        'customerPhone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      });
      if (!mounted) return;
      if (created != null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.supportTicketCreated)),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không tạo được ticket.')),
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
      appBar: AppBar(title: Text(l10n.supportTicketCreate)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          SectionCard(
            title: l10n.supportTicketCreate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(labelText: l10n.supportSubject),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(labelText: l10n.supportDescription),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 8),
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
                TsDropdownField<String>(
                  value: _category,
                  labelText: l10n.supportCategory,
                  items: supportTicketCategories,
                  itemLabel: supportCategoryLabel,
                  onChanged: (v) => setState(() => _category = v ?? 'other'),
                ),
                const SizedBox(height: 8),
                TsDropdownField<String>(
                  value: _priority,
                  labelText: l10n.repairPriority,
                  items: supportTicketPriorities,
                  itemLabel: (p) => repairPriorityLabel(p, l10n),
                  onChanged: (v) => setState(() => _priority = v ?? 'normal'),
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
                      : Text(l10n.supportTicketCreate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
