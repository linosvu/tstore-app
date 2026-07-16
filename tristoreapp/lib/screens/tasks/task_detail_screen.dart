import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/media_upload.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/task.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/providers/tasks_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';

import 'task_ui.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskPublic? _task;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _noteCtrl = TextEditingController();
  List<({String id, String name, String email})> _staff = [];
  UploadConfig? _uploadConfig;
  final List<PendingMediaUpload> _pendingMedia = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadStaff();
    _loadUploadConfig();
  }

  Future<void> _loadUploadConfig() async {
    final api = context.read<AuthProvider>().api;
    final cfg = await fetchUploadConfig(api);
    if (!mounted) return;
    setState(() => _uploadConfig = cfg);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    try {
      final mgmt = ManagementProvider(api: context.read<AuthProvider>().api);
      final list = await mgmt.fetchStaffUsers();
      if (!mounted) return;
      setState(() => _staff = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await context.read<TasksProvider>().fetchOne(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = t;
        _loading = false;
        if (t == null) _error = 'Không tìm thấy nhiệm vụ';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = TasksProvider.dioMessage(e);
        _loading = false;
      });
    }
  }

  bool _canEdit(TaskPublic task) {
    final me = context.read<AuthProvider>().user;
    if (me == null) return false;
    if (me.role == 'admin' || me.role == 'manager') return true;
    if (task.createdByUserId == me.id) return true;
    if (task.assignedUserId == me.id) return true;
    return task.collaborators.any((c) => c.userId == me.id && c.canEdit);
  }

  String _userName(String id) {
    if (id.isEmpty) return '—';
    final me = context.read<AuthProvider>().user;
    if (me != null && me.id == id) {
      return AppLocalizations.of(context).tasksAssigneeMe;
    }
    final u = _staff.where((s) => s.id == id).firstOrNull;
    if (u != null && u.name.isNotEmpty) return u.name;
    if (u != null && u.email.isNotEmpty) return u.email;
    return id;
  }

  Future<void> _editPerformers() async {
    final l10n = AppLocalizations.of(context);
    final task = _task;
    if (task == null || !_canEdit(task)) return;

    var assigneeId = task.assignedUserId;
    final draftCollaborators = task.collaborators
        .map((c) => (userId: c.userId, canEdit: c.canEdit))
        .toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickAssignee() async {
              final me = context.read<AuthProvider>().user?.id;
              final picked = await showModalBottomSheet<String>(
                context: ctx,
                builder: (inner) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (me != null)
                        ListTile(
                          title: Text(l10n.tasksAssigneeMe),
                          selected: assigneeId == me,
                          onTap: () => Navigator.pop(inner, me),
                        ),
                      ..._staff.where((s) => s.id != me).map(
                            (s) => ListTile(
                              title: Text(s.name),
                              subtitle: Text(s.email),
                              selected: assigneeId == s.id,
                              onTap: () => Navigator.pop(inner, s.id),
                            ),
                          ),
                    ],
                  ),
                ),
              );
              if (picked != null) {
                setSheetState(() {
                  assigneeId = picked;
                  draftCollaborators.removeWhere((c) => c.userId == picked);
                });
              }
            }

            Future<void> addCollaborator() async {
              final picked = await showModalBottomSheet<String>(
                context: ctx,
                builder: (inner) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: _staff
                        .where((s) => s.id != assigneeId)
                        .where(
                          (s) => !draftCollaborators.any((c) => c.userId == s.id),
                        )
                        .map(
                          (s) => ListTile(
                            title: Text(s.name),
                            subtitle: Text(s.email),
                            onTap: () => Navigator.pop(inner, s.id),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
              if (picked != null) {
                setSheetState(() {
                  draftCollaborators.add((userId: picked, canEdit: false));
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                top: AppSpacing.space3,
                bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.space3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.tasksEditPerformers,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    l10n.tasksAssigneeMain,
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: pickAssignee,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_userName(assigneeId)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.tasksCollaboratorsSection,
                          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: addCollaborator,
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: Text(l10n.tasksAddCollaborator),
                      ),
                    ],
                  ),
                  if (draftCollaborators.isEmpty)
                    Text(
                      '—',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    )
                  else
                    ...draftCollaborators.map(
                      (c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_userName(c.userId)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setSheetState(() {
                            draftCollaborators.removeWhere(
                              (x) => x.userId == c.userId,
                            );
                          }),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.space3),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved != true || !mounted) return;

    setState(() => _busy = true);
    final p = context.read<TasksProvider>();
    try {
      TaskPublic? updated = task;
      if (assigneeId != task.assignedUserId) {
        updated = await p.patch(task.id, {'assignedUserId': assigneeId});
      }
      for (final old in task.collaborators) {
        if (!draftCollaborators.any((c) => c.userId == old.userId)) {
          updated = await p.removeCollaborator(task.id, old.userId);
        }
      }
      for (final c in draftCollaborators) {
        if (!task.collaborators.any((old) => old.userId == c.userId)) {
          updated = await p.addCollaborator(
            task.id,
            userId: c.userId,
            canEdit: c.canEdit,
          );
        }
      }
      if (!mounted) return;
      if (updated != null) {
        setState(() => _task = updated);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.success)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.error)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    final task = _task;
    if (task == null) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<TasksProvider>().patchStatus(
            task.id,
            'completed',
          );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _task = updated);
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(l10n.tasksCompletedSuccess)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.error)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelTask() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tasksCancelTitle),
        content: Text(l10n.tasksCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tasksCancelAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final task = _task;
    if (task == null) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<TasksProvider>().patchStatus(
            task.id,
            'cancelled',
          );
      if (!mounted) return;
      if (updated != null) setState(() => _task = updated);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.error)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTask() async {
    final l10n = AppLocalizations.of(context);
    final task = _task;
    if (task == null) return;
    final titleCtrl = TextEditingController(text: task.title);
    final contentCtrl = TextEditingController(text: task.content ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tasksEditTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: l10n.tasksTitleLabel),
              ),
              TextField(
                controller: contentCtrl,
                decoration: InputDecoration(labelText: l10n.tasksContentLabel),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<TasksProvider>().patch(
            task.id,
            {
              'title': titleCtrl.text.trim(),
              'content': contentCtrl.text.trim(),
            },
          );
      if (!mounted) return;
      if (updated != null) setState(() => _task = updated);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.error)),
      );
    } finally {
      titleCtrl.dispose();
      contentCtrl.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final l10n = AppLocalizations.of(context);
    final content = _noteCtrl.text.trim();
    if (content.isEmpty) return;
    final task = _task;
    if (task == null) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<TasksProvider>().addNote(
            task.id,
            content: content,
          );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _task = updated);
        _noteCtrl.clear();
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(TasksProvider.dioMessage(e) ?? l10n.error)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMedia() async {
    final l10n = AppLocalizations.of(context);
    final task = _task;
    if (task == null) return;
    final picks = await showMediaPickerSheet(context, config: _uploadConfig);
    if (picks == null || picks.isEmpty || !mounted) return;

    final p = context.read<TasksProvider>();
    var anyFail = false;

    for (final pick in picks) {
      if (!mounted) return;
      final ok = await validateMediaPick(
        context: context,
        pick: pick,
        config: _uploadConfig,
        tooLargeMessage: pick.isVideo
            ? l10n.mediaVideoTooLarge
            : l10n.mediaUploadFailed,
        tooLongMessage: l10n.mediaVideoTooLong,
      );
      if (!ok || !mounted) {
        anyFail = true;
        continue;
      }

      final pending = enqueuePendingMedia(pick: pick);
      setState(() => _pendingMedia.add(pending));

      try {
        final result = await uploadPickedMedia(
          pick: pick,
          api: p.api,
          onProgress: (v) {
            if (!mounted) return;
            setState(() => pending.progress = v);
          },
        );
        if (!mounted) return;
        if (result == null || result.url.trim().isEmpty) {
          anyFail = true;
          continue;
        }
        final updated = await p.addAttachment(
          task.id,
          url: result.url,
          mediaType: result.mediaType,
        );
        if (updated != null && mounted) setState(() => _task = updated);
      } on DioException catch (e) {
        anyFail = true;
        if (!mounted) return;
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(
              e.response?.data?.toString() ?? e.message ?? l10n.error,
            ),
          ),
        );
      } catch (_) {
        anyFail = true;
      } finally {
        if (mounted) {
          setState(() => _pendingMedia.removeWhere((e) => e.id == pending.id));
        }
      }
    }

    if (anyFail && mounted) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaUploadFailed)),
      );
    }
  }

  Future<void> _openMediaViewer(List<TaskAttachment> items, int index) async {
    if (items.isEmpty) return;
    final safeIndex = index.clamp(0, items.length - 1);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          items: items
              .map((e) => MediaViewerItem(url: e.url, mediaType: e.mediaType))
              .toList(),
          initialIndex: safeIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tasksDetailTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _task == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tasksDetailTitle)),
        body: Center(child: Text(_error ?? '—')),
      );
    }
    final task = _task!;
    final editable = _canEdit(task);
    final canComplete =
        editable && task.status != 'completed' && task.status != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tasksDetailTitle),
        actions: [
          if (editable) ...[
            IconButton(
              tooltip: l10n.tasksEditTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _editTask,
            ),
            IconButton(
              tooltip: l10n.tasksCancelAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy || task.status == 'cancelled' ? null : _cancelTask,
            ),
          ],
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.space3,
              AppSpacing.screenHorizontal,
              100,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  taskPriorityFlag(task),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  taskStatusBadge(task, l10n),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatTaskDueAt(task.dueAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if ((task.content ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(task.content!.trim()),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              SectionCard(
                title: l10n.tasksPerformersSection,
                titleTrailing: editable
                    ? IconButton(
                        tooltip: l10n.tasksEditPerformers,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: _busy ? null : _editPerformers,
                      )
                    : null,
                child: Column(
                  children: [
                    taskPerformerTile(
                      name: _userName(task.assignedUserId),
                      badge: taskMainAssigneeBadge(l10n),
                    ),
                    ...task.collaborators.map(
                      (c) => taskPerformerTile(
                        name: _userName(c.userId),
                        badge: taskCollaboratorBadge(l10n),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              SectionCard(
                title: l10n.tasksAttachmentsSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (task.attachments.isEmpty && _pendingMedia.isEmpty)
                      Text(
                        l10n.tasksAttachmentsEmpty,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pending in _pendingMedia)
                            LocalMediaPreviewTile(
                              localPath: pending.localPath,
                              isVideo: pending.isVideo,
                              progress: pending.progress,
                              width: 88,
                              height: 88,
                            ),
                          for (var i = 0; i < task.attachments.length; i++)
                            MediaTile(
                              url: task.attachments[i].url,
                              mediaType: task.attachments[i].mediaType,
                              width: 88,
                              height: 88,
                              onTap: () => _openMediaViewer(task.attachments, i),
                            ),
                        ],
                      ),
                    if (editable) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addMedia,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(l10n.tasksAddAttachment),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              SectionCard(
                title: l10n.tasksNotesSection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (task.notes.isEmpty)
                      Text(
                        l10n.tasksNotesEmpty,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      ...task.notes.map((n) {
                        final dt = DateTime.tryParse(n.createdAt);
                        final when = dt != null
                            ? DateFormat('dd/MM HH:mm').format(dt.toLocal())
                            : n.createdAt;
                        return taskNoteItem(
                          context: context,
                          authorLine: '${_userName(n.userId)} · $when',
                          content: n.content,
                        );
                      }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.tasksNoteHint,
                        border: const OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _busy ? null : _addNote,
                        child: Text(l10n.tasksAddNote),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: canComplete
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: FilledButton(
                  onPressed: _busy ? null : _complete,
                  child: Text(l10n.tasksCompleteAction),
                ),
              ),
            )
          : null,
    );
  }
}
