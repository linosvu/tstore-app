import 'package:flutter/material.dart';

/// Sheet sửa nội dung cam kết tiếp nhận (SC v3).
class RepairTermsSheet extends StatefulWidget {
  const RepairTermsSheet({
    super.key,
    required this.initialText,
    required this.defaultText,
    required this.onSave,
  });

  final String initialText;
  final String defaultText;
  final Future<void> Function(String text) onSave;

  @override
  State<RepairTermsSheet> createState() => _RepairTermsSheetState();
}

class _RepairTermsSheetState extends State<RepairTermsSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cam kết với khách',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Nội dung cam kết',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _ctrl.text = widget.defaultText),
              child: const Text('Khôi phục mặc định'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_ctrl.text.trim());
                    if (mounted) Navigator.pop(context);
                  },
            child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
