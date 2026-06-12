import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/providers/tasks_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';

class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  DateTime? _dueAt;
  bool _highPriority = false;
  String? _assigneeId;
  final List<({String id, String name})> _collaborators = [];
  bool _submitting = false;
  List<({String id, String name, String email})> _staff = [];
  bool _loadingStaff = true;

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user?.id;
    _assigneeId = me;
    _loadStaff();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    try {
      final mgmt = ManagementProvider(api: context.read<AuthProvider>().api);
      final list = await mgmt.fetchStaffUsers();
      if (!mounted) return;
      setState(() {
        _staff = list;
        _loadingStaff = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStaff = false);
    }
  }

  String _userLabel(String id) {
    final me = context.read<AuthProvider>().user;
    if (me != null && me.id == id) return AppLocalizations.of(context).tasksAssigneeMe;
    final u = _staff.where((s) => s.id == id).firstOrNull;
    return u?.name ?? id.substring(0, 8);
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickAssignee() async {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthProvider>().user?.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (me != null)
              ListTile(
                title: Text(l10n.tasksAssigneeMe),
                selected: _assigneeId == me,
                onTap: () => Navigator.pop(ctx, me),
              ),
            ..._staff.where((s) => s.id != me).map(
                  (s) => ListTile(
                    title: Text(s.name),
                    subtitle: Text(s.email),
                    selected: _assigneeId == s.id,
                    onTap: () => Navigator.pop(ctx, s.id),
                  ),
                ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _assigneeId = picked);
  }

  Future<void> _addCollaborator() async {
    final me = context.read<AuthProvider>().user?.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _staff
              .where((s) => s.id != _assigneeId && s.id != me)
              .where((s) => !_collaborators.any((c) => c.id == s.id))
              .map(
                (s) => ListTile(
                  title: Text(s.name),
                  subtitle: Text(s.email),
                  onTap: () => Navigator.pop(ctx, s.id),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null) return;
    final name = _staff.where((s) => s.id == picked).firstOrNull?.name ?? picked;
    setState(() => _collaborators.add((id: picked, name: name)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.tasksTitleRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'title': title,
        'priority': _highPriority ? 'high' : 'normal',
        if (_contentCtrl.text.trim().isNotEmpty) 'content': _contentCtrl.text.trim(),
        if (_dueAt != null) 'dueAt': _dueAt!.toUtc().toIso8601String(),
        if (_assigneeId != null) 'assignedUserId': _assigneeId,
        if (_collaborators.isNotEmpty)
          'collaborators': _collaborators
              .map((c) => {'userId': c.id, 'canEdit': false})
              .toList(),
      };
      final created = await context.read<TasksProvider>().create(body);
      if (!mounted) return;
      if (created == null) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.tasksCreateFailed)),
        );
        return;
      }
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.tasksCreated)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.tasksCreateFailed)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tasksCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          SectionCard(
            title: l10n.tasksCreateTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.tasksTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.space3),
                TextField(
                  controller: _contentCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.tasksContentLabel,
                    border: const OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.space3),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tasksDueLabel),
                  subtitle: Text(
                    _dueAt == null
                        ? l10n.tasksDuePick
                        : '${_dueAt!.day.toString().padLeft(2, '0')}/${_dueAt!.month.toString().padLeft(2, '0')}/${_dueAt!.year} ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDueAt,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Text(l10n.tasksPriorityHigh),
                      const SizedBox(width: 6),
                      const Icon(Icons.flag_rounded, color: Colors.red, size: 18),
                    ],
                  ),
                  subtitle: Text(l10n.tasksPriorityNormal),
                  value: _highPriority,
                  onChanged: (v) => setState(() => _highPriority = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          SectionCard(
            title: l10n.tasksAssigneeSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tasksAssigneeMain),
                  subtitle: Text(_loadingStaff ? '…' : _userLabel(_assigneeId ?? '')),
                  trailing: const Icon(Icons.person_outline),
                  onTap: _loadingStaff ? null : _pickAssignee,
                ),
                const Divider(),
                Text(
                  l10n.tasksCollaboratorsSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (_collaborators.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.tasksCollaboratorsEmpty,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  ..._collaborators.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() => _collaborators.remove(c));
                        },
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _loadingStaff ? null : _addCollaborator,
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(l10n.tasksAddCollaborator),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.tasksSubmit),
          ),
          const SizedBox(height: AppSpacing.space6),
        ],
      ),
    );
  }
}
