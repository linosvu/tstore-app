import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/app_date_time.dart';
import 'package:tstore/models/task.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

String taskStatusLabel(String status, AppLocalizations l10n, {bool overdue = false}) {
  if (overdue) return l10n.tasksStatusOverdue;
  switch (status) {
    case 'pending':
      return l10n.tasksStatusPending;
    case 'in_progress':
      return l10n.tasksStatusInProgress;
    case 'completed':
      return l10n.tasksStatusCompleted;
    case 'cancelled':
      return l10n.tasksStatusCancelled;
    default:
      return status;
  }
}

StatusBadgeTone taskStatusTone(String status, {bool overdue = false}) {
  if (overdue) return StatusBadgeTone.error;
  switch (status) {
    case 'pending':
      return StatusBadgeTone.neutral;
    case 'in_progress':
      return StatusBadgeTone.warning;
    case 'completed':
      return StatusBadgeTone.success;
    case 'cancelled':
      return StatusBadgeTone.neutral;
    default:
      return StatusBadgeTone.neutral;
  }
}

Widget taskStatusBadge(TaskPublic task, AppLocalizations l10n) {
  final overdue = task.isOverdue;
  return StatusBadge(
    label: taskStatusLabel(task.status, l10n, overdue: overdue),
    tone: taskStatusTone(task.status, overdue: overdue),
  );
}

String formatTaskDueAt(String? dueAt) {
  if (dueAt == null || dueAt.isEmpty) return '—';
  final d = DateTime.tryParse(dueAt);
  if (d == null) return dueAt;
  return DateFormat('dd/MM/yyyy HH:mm').format(AppDateTime.toVn(d));
}

Widget taskMainAssigneeBadge(AppLocalizations l10n) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      l10n.tasksRoleMain,
      style: const TextStyle(
        color: Color(0xFF6D28D9),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget taskCollaboratorBadge(AppLocalizations l10n) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      l10n.tasksRoleCollaborator,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget taskPriorityFlag(TaskPublic task) {
  if (task.priority != 'high') return const SizedBox.shrink();
  return const Icon(
    Icons.flag_rounded,
    color: AppColors.error,
    size: 18,
  );
}

String taskPerformerInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

Widget taskPerformerTile({
  required String name,
  required Widget badge,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
          child: Text(
            taskPerformerInitials(name),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6D28D9),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        badge,
      ],
    ),
  );
}

Widget taskNoteItem({
  required BuildContext context,
  required String authorLine,
  required String content,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          authorLine,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget taskFilterChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    ),
  );
}
