import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'service_ui.dart';
import 'widgets/fee_field.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  const CreateServiceRequestScreen({
    super.key,
    this.defaultTicketType = 'online',
  });

  final String defaultTicketType;

  @override
  State<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  String _channel = 'phone';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _slotCtrl = TextEditingController(text: '09:00-11:00');

  late String _ticketType;
  bool _isFree = true;
  int _feeAmount = 0;
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  String? _managerUserId;
  String? _staffUserId;
  List<(String, String)> _users = [];
  final List<Map<String, String>> _attachments = [];
  bool _loadingUsers = false;
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _ticketType = widget.defaultTicketType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthProvider>().user;
      if (me != null) {
        setState(() {
          _managerUserId = me.id;
          _staffUserId = me.id;
        });
      }
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _addressCtrl.dispose();
    _productCtrl.dispose();
    _serialCtrl.dispose();
    _issueCtrl.dispose();
    _noteCtrl.dispose();
    _slotCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
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
          if (id != null && active) {
            list.add((id, name.isEmpty ? id : name));
          }
        }
      }
      if (mounted) setState(() => _users = list);
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _pickAttachments() async {
    final picks = await showMediaPickerSheet(context, allowVideo: true);
    if (picks == null || picks.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    final api = context.read<AuthProvider>().api;
    try {
      for (final pick in picks) {
        final uploaded = await uploadPickedMedia(pick: pick, api: api);
        if (uploaded == null) continue;
        _attachments.add({
          'url': uploaded.url,
          'mediaType': pick.isVideo ? 'video' : 'image',
        });
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _appointmentDate = d);
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _productCtrl.text.trim().isEmpty ||
        _issueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập đủ khách, SĐT, sản phẩm và lỗi.')),
      );
      return;
    }
    if (_staffUserId == null) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Chọn nhân viên xử lý.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'channel': _channel,
        'customerName': _nameCtrl.text.trim(),
        'customerPhone': _phoneCtrl.text.trim(),
        if (_phone2Ctrl.text.trim().isNotEmpty)
          'customerPhone2': _phone2Ctrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty)
          'customerAddress': _addressCtrl.text.trim(),
        'productName': _productCtrl.text.trim(),
        if (_serialCtrl.text.trim().isNotEmpty)
          'productSerial': _serialCtrl.text.trim(),
        'issueDescription': _issueCtrl.text.trim(),
        if (_attachments.isNotEmpty) 'attachments': _attachments,
        if (_managerUserId != null) 'managerUserId': _managerUserId,
        'ticketType': _ticketType,
        'isFree': _isFree,
        'feeAmount': _isFree ? 0 : _feeAmount,
        'appointmentDate': yyyyMmDd(_appointmentDate),
        'appointmentSlot': _slotCtrl.text.trim().isEmpty
            ? '09:00-11:00'
            : _slotCtrl.text.trim(),
        'staffUserId': _staffUserId,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };
      final created =
          await context.read<ServiceRequestsProvider>().createRequest(body);
      if (!mounted) return;
      if (created != null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.serviceRequestCreated)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('Không tạo được: $e')),
        );
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
      appBar: AppBar(title: Text(l10n.serviceRequestCreate)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          SectionCard(
            title: l10n.serviceChannel,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in serviceRequestChannels)
                  ChoiceChip(
                    label: Text(channelLabel(c)),
                    selected: _channel == c,
                    onSelected: (_) => setState(() => _channel = c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceCustomerSection,
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.repairCustomerName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.repairCustomerPhone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone2Ctrl,
                  decoration: InputDecoration(labelText: l10n.servicePhone2),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(labelText: l10n.serviceAddress),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceProductSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _productCtrl,
                  decoration: InputDecoration(labelText: l10n.serviceProductName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serialCtrl,
                  decoration: InputDecoration(labelText: l10n.serviceSerial),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueCtrl,
                  decoration: InputDecoration(labelText: l10n.serviceIssue),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickAttachments,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  label: Text(
                    'Đính kèm (${_attachments.length})',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceManager,
            child: _loadingUsers
                ? const LinearProgressIndicator()
                : TsDropdownFieldNullable<String>(
                    value: _managerUserId,
                    items: userIds,
                    itemLabel: (id) =>
                        id == null ? '—' : (nameOf[id] ?? id),
                    onChanged: (v) => setState(() => _managerUserId = v),
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.serviceDirection,
            child: Row(
              children: [
                for (final t in serviceTicketTypes)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _ticketType = t),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _ticketType == t
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: _ticketType == t ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t == 'online'
                                    ? Icons.headset_mic_outlined
                                    : t == 'onsite'
                                        ? Icons.home_outlined
                                        : Icons.build_outlined,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ticketTypeLabel(t),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.serviceAppointmentDate),
                  subtitle: Text(yyyyMmDd(_appointmentDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
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
            child: _loadingUsers
                ? const LinearProgressIndicator()
                : TsDropdownFieldNullable<String>(
                    value: _staffUserId,
                    items: userIds,
                    itemLabel: (id) =>
                        id == null ? '—' : (nameOf[id] ?? id),
                    onChanged: (v) => setState(() => _staffUserId = v),
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.repairNotes,
            child: TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: l10n.repairNotes),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(l10n),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.serviceRequestCreate),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
