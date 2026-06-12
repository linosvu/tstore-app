import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/task.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/tasks_provider.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';

import 'task_create_screen.dart';
import 'task_detail_screen.dart';
import 'task_ui.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TasksProvider>().load(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = context.read<TasksProvider>();
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!p.isLoading && !p.isLoadingMore && p.page < p.totalPages) {
        p.load(reset: false);
      }
    }
  }

  void _applyFilter(TasksProvider p, {String? status, bool overdue = false}) {
    if (overdue) {
      p.setOverdueFilter(true);
    } else {
      p.setStatusFilter(status);
    }
    p.load(reset: true);
  }

  bool _elevated() {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin' || role == 'manager';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tasksListTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => const TaskCreateScreen(),
            ),
          );
          if (created == true && mounted) {
            context.read<TasksProvider>().load(reset: true);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.tasksCreateNew),
      ),
      body: Consumer<TasksProvider>(
        builder: (context, p, _) {
          return RefreshIndicator(
            onRefresh: () => p.load(reset: true),
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.space3,
                      AppSpacing.screenHorizontal,
                      AppSpacing.space2,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          taskFilterChip(
                            label: l10n.tasksFilterAll,
                            selected: p.statusFilter == null && !p.overdueFilter,
                            onTap: () => _applyFilter(p, status: null),
                          ),
                          taskFilterChip(
                            label: l10n.tasksStatusPending,
                            selected: p.statusFilter == 'pending',
                            onTap: () => _applyFilter(p, status: 'pending'),
                          ),
                          taskFilterChip(
                            label: l10n.tasksStatusInProgress,
                            selected: p.statusFilter == 'in_progress',
                            onTap: () => _applyFilter(p, status: 'in_progress'),
                          ),
                          taskFilterChip(
                            label: l10n.tasksStatusOverdue,
                            selected: p.overdueFilter,
                            onTap: () => _applyFilter(p, overdue: true),
                          ),
                          taskFilterChip(
                            label: l10n.tasksStatusCompleted,
                            selected: p.statusFilter == 'completed',
                            onTap: () => _applyFilter(p, status: 'completed'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_elevated())
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'mine',
                            label: Text(l10n.tasksScopeMine),
                          ),
                          ButtonSegment(
                            value: 'all',
                            label: Text(l10n.tasksScopeAll),
                          ),
                        ],
                        selected: {p.listScope},
                        onSelectionChanged: (s) {
                          p.setScope(s.first);
                          p.load(reset: true);
                        },
                      ),
                    ),
                  ),
                if (p.error != null)
                  SliverToBoxAdapter(
                    child: ErrorBanner(
                      message: p.error!,
                      retryLabel: l10n.productsRetry,
                      onRetry: () => p.load(reset: true),
                    ),
                  ),
                if (p.isLoading && p.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: ListSkeleton(
                      rows: 6,
                      variant: ListSkeletonVariant.orderRow,
                    ),
                  )
                else if (p.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(message: l10n.tasksListEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.space2,
                      AppSpacing.screenHorizontal,
                      88,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i >= p.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _TaskCard(
                            task: p.items[i],
                            l10n: l10n,
                            onTap: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => TaskDetailScreen(
                                    taskId: p.items[i].id,
                                  ),
                                ),
                              );
                              if (mounted) p.load(reset: true);
                            },
                          );
                        },
                        childCount: p.items.length + (p.isLoadingMore ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.l10n,
    required this.onTap,
  });

  final TaskPublic task;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      taskPriorityFlag(task),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.tasksDueLabel}: ${formatTaskDueAt(task.dueAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            taskStatusBadge(task, l10n),
          ],
        ),
      ),
    );
  }
}
