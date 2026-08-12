import 'package:flutter/material.dart';

/// Dropdown chọn user với ô tìm kiếm (bottom sheet).
class SearchableUserDropdown extends StatelessWidget {
  const SearchableUserDropdown({
    super.key,
    required this.labelText,
    required this.value,
    required this.users,
    required this.onChanged,
    this.enabled = true,
    this.hintText = 'Chọn nhân viên',
  });

  final String labelText;
  final String? value;
  final List<(String, String)> users;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String hintText;

  String get _selectedLabel {
    if (value == null || value!.isEmpty) return hintText;
    for (final u in users) {
      if (u.$1 == value) return u.$2;
    }
    return value!;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _SearchableUserSheet(
        users: users,
        selectedId: value,
        title: labelText,
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        enabled: enabled,
      ),
      child: InkWell(
        onTap: enabled ? () => _openPicker(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedLabel,
                  style: TextStyle(
                    color: (value == null || value!.isEmpty)
                        ? Theme.of(context).hintColor
                        : null,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled
                    ? Theme.of(context).iconTheme.color
                    : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchableUserSheet extends StatefulWidget {
  const _SearchableUserSheet({
    required this.users,
    required this.selectedId,
    required this.title,
  });

  final List<(String, String)> users;
  final String? selectedId;
  final String title;

  @override
  State<_SearchableUserSheet> createState() => _SearchableUserSheetState();
}

class _SearchableUserSheetState extends State<_SearchableUserSheet> {
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<(String, String)> get _filtered {
    final q = _queryCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return widget.users
        .where(
          (u) =>
              u.$2.toLowerCase().contains(q) || u.$1.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _queryCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Không có kết quả'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      final selected = u.$1 == widget.selectedId;
                      return ListTile(
                        title: Text(u.$2),
                        trailing: selected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, u.$1),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
