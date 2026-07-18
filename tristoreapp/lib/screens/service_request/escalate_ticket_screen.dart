import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'service_ui.dart';
import 'widgets/fee_field.dart';

class EscalateTicketScreen extends StatefulWidget {
  const EscalateTicketScreen({
    super.key,
    required this.requestId,
    this.previousTicketId,
    this.suggestedType = 'onsite',
  });

  final String requestId;
  final String? previousTicketId;
  final String suggestedType;

  @override
  State<EscalateTicketScreen> createState() => _EscalateTicketScreenState();
}

class _EscalateTicketScreenState extends State<EscalateTicketScreen> {
  late String _type;
  bool _isFree = true;
  int _feeAmount = 0;
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  final _slotCtrl = TextEditingController(text: '09:00-11:00');
  final _noteCtrl = TextEditingController();
  String? _staffUserId;
  List<(String, String)> _users = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.suggestedType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthProvider>().user;
      _staffUserId = me?.id;
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _slotCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final api = context.read<AuthProvider>().api;
    final res = await api.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {'page': 1, 'limit': 100},
    );
    final items = res.data?['items'];
    final list = <(String, String)>[];
    if (items is List) {
      for (final e in items) {
        if (e is! Map<String, dynamic>) continue;
        final id = e['id'] as String?;
        final name = e['fullName'] as String? ?? '';
        final active = e['isActive'] as bool? ?? true;
        if (id != null && active) list.add((id, name.isEmpty ? id : name));
      }
    }
    if (mounted) setState(() => _users = list);
  }

  Future<void> _submit() async {
    if (_staffUserId == null) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Chọn nhân viên.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final ticket =
          await context.read<ServiceRequestsProvider>().createChildTicket(
        widget.requestId,
        {
          'type': _type,
          if (widget.previousTicketId != null)
            'previousTicketId': widget.previousTicketId,
          'isFree': _isFree,
          'feeAmount': _isFree ? 0 : _feeAmount,
          'appointmentDate': yyyyMmDd(_appointmentDate),
          'appointmentSlot': _slotCtrl.text.trim(),
          'staffUserId': _staffUserId,
          if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (ticket != null) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã tạo phiếu leo thang.')),
        );
        Navigator.pop(context, ticket);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userIds = _users.map((e) => e.$1).toList();
    final nameOf = {for (final u in _users) u.$1: u.$2};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceEscalate)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          SectionCard(
            title: l10n.serviceDirection,
            child: Wrap(
              spacing: 8,
              children: [
                for (final t in serviceTicketTypes)
                  ChoiceChip(
                    label: Text(ticketTypeLabel(t)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceFeeAppointment,
            child: Column(
              children: [
                FeeField(
                  isFree: _isFree,
                  feeAmount: _feeAmount,
                  onFreeChanged: (v) => setState(() => _isFree = v),
                  onFeeChanged: (v) => setState(() => _feeAmount = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.serviceAppointmentDate),
                  subtitle: Text(yyyyMmDd(_appointmentDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _appointmentDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _appointmentDate = d);
                  },
                ),
                TextField(
                  controller: _slotCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.serviceAppointmentSlot,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceStaff,
            child: TsDropdownFieldNullable<String>(
              value: _staffUserId,
              items: userIds,
              itemLabel: (id) => id == null ? '—' : (nameOf[id] ?? id),
              onChanged: (v) => setState(() => _staffUserId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(labelText: l10n.repairNotes),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.serviceEscalate),
          ),
        ],
      ),
    );
  }
}
