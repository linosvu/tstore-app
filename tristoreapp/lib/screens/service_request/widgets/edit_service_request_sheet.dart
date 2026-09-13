import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/utils/keyboard_utils.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';

/// Form sửa thông tin yêu cầu (YC) từ trang chi tiết.
Future<ServiceRequestPublic?> showEditServiceRequestSheet({
  required BuildContext context,
  required ServiceRequestPublic request,
}) {
  return showModalBottomSheet<ServiceRequestPublic>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _EditServiceRequestSheet(request: request),
  );
}

class _EditServiceRequestSheet extends StatefulWidget {
  const _EditServiceRequestSheet({required this.request});

  final ServiceRequestPublic request;

  @override
  State<_EditServiceRequestSheet> createState() =>
      _EditServiceRequestSheetState();
}

class _EditServiceRequestSheetState extends State<_EditServiceRequestSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _issueCtrl;
  late final TextEditingController _buyerNameCtrl;
  late final TextEditingController _buyerPhoneCtrl;
  late final TextEditingController _buyerAddressCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _nameCtrl = TextEditingController(text: r.customerName);
    _phoneCtrl = TextEditingController(text: r.customerPhone);
    _addressCtrl = TextEditingController(text: r.customerAddress ?? '');
    _noteCtrl = TextEditingController(text: r.customerNote ?? '');
    _productCtrl = TextEditingController(text: r.productName);
    _serialCtrl = TextEditingController(text: r.productSerial ?? '');
    _issueCtrl = TextEditingController(text: r.issueDescription);
    _buyerNameCtrl = TextEditingController(text: r.buyerName ?? '');
    _buyerPhoneCtrl = TextEditingController(text: r.buyerPhone ?? '');
    _buyerAddressCtrl = TextEditingController(text: r.buyerAddress ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _productCtrl.dispose();
    _serialCtrl.dispose();
    _issueCtrl.dispose();
    _buyerNameCtrl.dispose();
    _buyerPhoneCtrl.dispose();
    _buyerAddressCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _productCtrl.text.trim().isEmpty ||
        _issueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(
          content: Text('Nhập đủ tên khách, SĐT, sản phẩm và lỗi.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'customerName': _nameCtrl.text.trim(),
        'customerPhone': _phoneCtrl.text.trim(),
        'customerAddress': _nullIfEmpty(_addressCtrl.text),
        'customerNote': _nullIfEmpty(_noteCtrl.text),
        'productName': _productCtrl.text.trim(),
        'productSerial': _nullIfEmpty(_serialCtrl.text),
        'issueDescription': _issueCtrl.text.trim(),
        'buyerName': _nullIfEmpty(_buyerNameCtrl.text),
        'buyerPhone': _nullIfEmpty(_buyerPhoneCtrl.text),
        'buyerAddress': _nullIfEmpty(_buyerAddressCtrl.text),
      };
      final updated = await context
          .read<ServiceRequestsProvider>()
          .patchRequest(widget.request.id, body);
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
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
              maxLines: 2,
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
              controller: _serialCtrl,
              decoration: const InputDecoration(labelText: 'Serial'),
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
            const SizedBox(height: 12),
            Text(
              'Người mua (tuỳ chọn)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buyerNameCtrl,
              decoration: const InputDecoration(labelText: 'Người mua'),
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buyerPhoneCtrl,
              decoration: const InputDecoration(labelText: 'SĐT mua'),
              keyboardType: TextInputType.phone,
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buyerAddressCtrl,
              decoration: const InputDecoration(labelText: 'Địa chỉ mua'),
              maxLines: 2,
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
