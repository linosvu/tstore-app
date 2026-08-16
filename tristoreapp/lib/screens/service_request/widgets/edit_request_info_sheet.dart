import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/utils/keyboard_utils.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';

import '../service_ui.dart';
import 'fee_field.dart';

bool canEditTicketRequestInfo(ServiceTicketPublic ticket, String? role, String? userId) {
  final closed = isTicketClosed(ticket.type, ticket.status);
  if (closed && !isOnsiteDone(ticket.type, ticket.status)) return false;
  if (role == 'admin' || role == 'manager') return true;
  if (userId == null || userId.isEmpty) return false;
  final assigned = ticket.staffUserId.trim();
  return assigned.isEmpty || assigned == userId;
}

/// Form sửa Tên / SĐT / SP / Lỗi / Phí / Thời gian hẹn / Ghi chú.
Future<ServiceTicketPublic?> showEditRequestInfoSheet({
  required BuildContext context,
  required ServiceTicketPublic ticket,
}) async {
  final req = ticket.request;
  if (req == null) return null;

  return showModalBottomSheet<ServiceTicketPublic>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EditRequestInfoSheet(ticket: ticket, request: req),
  );
}

class _EditRequestInfoSheet extends StatefulWidget {
  const _EditRequestInfoSheet({
    required this.ticket,
    required this.request,
  });

  final ServiceTicketPublic ticket;
  final ServiceRequestBrief request;

  @override
  State<_EditRequestInfoSheet> createState() => _EditRequestInfoSheetState();
}

class _EditRequestInfoSheetState extends State<_EditRequestInfoSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _issueCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _appointmentDate;
  late String _appointmentTime;
  late bool _isFree;
  late int _feeAmount;
  bool _saving = false;

  bool get _showFee =>
      widget.ticket.type == 'online' || widget.ticket.type == 'onsite';

  @override
  void initState() {
    super.initState();
    final req = widget.request;
    final t = widget.ticket;
    _nameCtrl = TextEditingController(text: req.customerName);
    _phoneCtrl = TextEditingController(text: req.customerPhone);
    _productCtrl = TextEditingController(text: req.productName);
    _issueCtrl = TextEditingController(text: req.issueDescription);
    _noteCtrl = TextEditingController(text: req.customerNote ?? '');
    final slot = normalizeAppointmentTimeLabel(t.appointmentSlot);
    _appointmentTime =
        slot.isEmpty ? formatAppointmentTimeOfDay(defaultAppointmentTime) : slot;
    final parsed = DateTime.tryParse(t.appointmentDate ?? '');
    _appointmentDate = parsed ?? DateTime.now().add(const Duration(days: 1));
    _isFree = t.isCostFree;
    _feeAmount = _isFree ? 0 : t.feeAmount;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _productCtrl.dispose();
    _issueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _appointmentDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickAppointmentTimeOfDay(
      context,
      initial: parseAppointmentTimeOfDay(_appointmentTime),
    );
    if (picked != null) {
      setState(() => _appointmentTime = formatAppointmentTimeOfDay(picked));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _productCtrl.text.trim().isEmpty ||
        _issueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập đủ tên khách, SĐT, sản phẩm và lỗi.')),
      );
      return;
    }
    if (_showFee && !_isFree && _feeAmount <= 0) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Nhập phí hỗ trợ hoặc chọn miễn phí.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'customerName': _nameCtrl.text.trim(),
        'customerPhone': _phoneCtrl.text.trim(),
        'productName': _productCtrl.text.trim(),
        'issueDescription': _issueCtrl.text.trim(),
        'customerNote': _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
        'appointmentDate': yyyyMmDd(_appointmentDate),
        'appointmentSlot': _appointmentTime,
        if (_showFee) ...{
          'isFree': _isFree,
          'feeAmount': _isFree ? 0 : _feeAmount,
        },
      };
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchTicketRequestInfo(widget.ticket.id, body);
      if (!mounted) return;
      if (updated == null) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không thể lưu.')),
        );
        return;
      }
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sửa thông tin yêu cầu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên khách'),
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'SĐT'),
              keyboardType: TextInputType.phone,
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _productCtrl,
              decoration: const InputDecoration(labelText: 'Sản phẩm'),
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _issueCtrl,
              decoration: const InputDecoration(labelText: 'Mô tả lỗi'),
              minLines: 2,
              maxLines: 4,
              enabled: !_saving,
            ),
            if (_showFee) ...[
              const SizedBox(height: 8),
              FeeField(
                isFree: _isFree,
                feeAmount: _feeAmount,
                onFreeChanged: (v) => setState(() {
                  _isFree = v;
                  if (v) _feeAmount = 0;
                }),
                onFeeChanged: (v) => setState(() => _feeAmount = v),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ngày hẹn'),
              subtitle: Text(yyyyMmDd(_appointmentDate)),
              trailing: const Icon(Icons.calendar_today),
              enabled: !_saving,
              onTap: _saving ? null : _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giờ hẹn'),
              subtitle: Text(_appointmentTime),
              trailing: const Icon(Icons.access_time),
              enabled: !_saving,
              onTap: _saving ? null : _pickTime,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onTapOutside: dismissKeyboardOnTapOutside,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper: quyền sửa từ AuthProvider hiện tại.
bool canEditTicketRequestInfoFromContext(
  BuildContext context,
  ServiceTicketPublic ticket,
) {
  final user = context.read<AuthProvider>().user;
  return canEditTicketRequestInfo(ticket, user?.role, user?.id);
}
