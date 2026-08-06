import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'create_service_request_screen.dart';
import 'online_ticket_screen.dart';
import 'onsite_ticket_screen.dart';
import 'other_ticket_screen.dart';
import 'repair_ticket_screen.dart';
import 'service_request_detail_screen.dart';
import 'service_ui.dart';

class ServiceRequestListScreen extends StatefulWidget {
  const ServiceRequestListScreen({
    super.key,
    required this.tab,
    this.initialStatusFilter,
    this.initialOverdue = false,
    this.embedded = false,
  });

  final String tab;
  final String? initialStatusFilter;
  final bool initialOverdue;
  final bool embedded;

  @override
  State<ServiceRequestListScreen> createState() =>
      _ServiceRequestListScreenState();
}

class _ServiceRequestListScreenState extends State<ServiceRequestListScreen> {
  final _searchCtrl = TextEditingController();
  late final ServiceRequestsProvider _prov;
  List<(String, String)> _users = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _prov = ServiceRequestsProvider(api: context.read<AuthProvider>().api);
    _prov.setTab(widget.tab);
    if (widget.initialStatusFilter != null) {
      _prov.setStatusFilter(widget.initialStatusFilter);
    }
    if (widget.initialOverdue) {
      _prov.setOverdueOnly(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _prov.load(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _prov.dispose();
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

  Future<void> _openCreate() async {
    final defaultDirection = widget.tab == 'repair' ? 'repair' : 'online';
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateServiceRequestScreen(
          defaultTicketType: defaultDirection,
        ),
      ),
    );
    if (ok == true) await _prov.load(reset: true);
  }

  void _openRequest(ServiceRequestPublic req) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceRequestDetailScreen(requestId: req.id),
      ),
    ).then((_) => _prov.load(reset: true));
  }

  void _openTicket(ServiceTicketBrief t) {
    final Widget screen = switch (t.type) {
      'online' => OnlineTicketScreen(ticketId: t.id),
      'onsite' => OnsiteTicketScreen(ticketId: t.id),
      'other' => OtherTicketScreen(ticketId: t.id),
      'repair' => RepairTicketScreen(ticketId: t.id),
      _ => OnlineTicketScreen(ticketId: t.id),
    };
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    ).then((_) => _prov.load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ChangeNotifierProvider<ServiceRequestsProvider>.value(
      value: _prov,
      child: Consumer<ServiceRequestsProvider>(
        builder: (context, prov, _) {
          final body = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  8,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.serviceSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        prov.setSearch('');
                        prov.load(reset: true);
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    prov.setSearch(v);
                    prov.load(reset: true);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  8,
                  AppSpacing.screenHorizontal,
                  0,
                ),
                child: _loadingUsers
                    ? const LinearProgressIndicator()
                    : TsDropdownFieldNullable<String>(
                        value: prov.supportStaffUserId,
                        labelText: widget.tab == 'repair'
                            ? l10n.serviceFilterRepairStaff
                            : l10n.serviceFilterSupportStaff,
                        items: [
                          null,
                          ..._users.map((u) => u.$1),
                        ],
                        itemLabel: (id) {
                          if (id == null) return 'Tất cả';
                          for (final u in _users) {
                            if (u.$1 == id) return u.$2;
                          }
                          return id;
                        },
                        onChanged: (v) {
                          prov.setSupportStaffUserId(v);
                          prov.load(reset: true);
                        },
                      ),
              ),
              _filterChips(prov),
              Expanded(child: _buildBody(l10n, prov)),
            ],
          );

          if (widget.embedded) {
            return Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: _openCreate,
                child: const Icon(Icons.add),
              ),
              body: body,
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.tab == 'repair'
                    ? l10n.serviceTabRepair
                    : l10n.serviceTabSupport,
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _filterChips(ServiceRequestsProvider prov) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: prov.statusFilter == null && !prov.overdueOnly,
            onSelected: (_) {
              prov.setStatusFilter(null);
              prov.setOverdueOnly(false);
              prov.load(reset: true);
            },
          ),
          const SizedBox(width: 6),
          for (final s in serviceRequestStatuses) ...[
            FilterChip(
              label: Text(requestStatusLabel(s)),
              selected: prov.statusFilter == s,
              onSelected: (_) {
                prov.setStatusFilter(s);
                prov.load(reset: true);
              },
            ),
            const SizedBox(width: 6),
          ],
          FilterChip(
            label: const Text('Quá hạn'),
            selected: prov.overdueOnly,
            onSelected: (_) {
              prov.setOverdueOnly(true);
              prov.load(reset: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ServiceRequestsProvider prov) {
    if (prov.isLoading && prov.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.error != null && prov.items.isEmpty) {
      return ErrorBanner(
        message: prov.error!,
        onRetry: () => prov.load(reset: true),
      );
    }
    if (prov.items.isEmpty) {
      return EmptyState(
        icon: Icons.support_agent_outlined,
        message: l10n.serviceListEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: () => prov.load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
            prov.load(reset: false);
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            88,
          ),
          itemCount: prov.items.length + (prov.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i >= prov.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _RequestCard(
              request: prov.items[i],
              onOpen: () => _openRequest(prov.items[i]),
              onOpenTicket: _openTicket,
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onOpen,
    required this.onOpenTicket,
  });

  final ServiceRequestPublic request;
  final VoidCallback onOpen;
  final void Function(ServiceTicketBrief) onOpenTicket;

  String _deadlineRemaining(String? iso, {bool markOverdue = false}) {
    if (iso == null || iso.isEmpty) return '';
    final deadline = DateTime.tryParse(iso);
    if (deadline == null) return '';
    final now = DateTime.now();
    final overdue = markOverdue || deadline.isBefore(now);
    if (overdue) {
      final late = now.difference(deadline);
      return 'Quá hạn ${late.inHours}h ${late.inMinutes.remainder(60)}p';
    }
    final diff = deadline.difference(now);
    if (diff.inDays >= 1) {
      return 'Còn ${diff.inDays} ngày ${diff.inHours.remainder(24)}h';
    }
    return 'Còn ${diff.inHours}h ${diff.inMinutes.remainder(60)}p';
  }

  String? _appointmentLabel(ServiceTicketBrief ticket) {
    final date = (ticket.appointmentDate ?? '').trim();
    if (date.isEmpty) return null;
    String displayDate = date;
    final parsed = DateTime.tryParse(date);
    if (parsed != null) {
      displayDate =
          '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
    }
    final slot = (ticket.appointmentSlot ?? '').trim();
    if (slot.isEmpty) return 'Lịch: $displayDate';
    return 'Lịch: $displayDate · $slot';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = request.latestTicket;
    final isRepair = request.isRepairDirection || latest?.type == 'repair';
    final creator = (request.createdByName ?? '').trim();
    final manager = (request.managerName ?? '').trim();
    final elapsed = formatRepairElapsed(
      latest?.repairStartedAt,
      fallbackIso: latest?.createdAt ?? request.createdAt,
    );
    final appointment = latest != null ? _appointmentLabel(latest) : null;

    // SC: ưu tiên lịch hẹn / hẹn gọi; cả SC & YC: hạn xử lý deadlineAt.
    String? secondaryLabel;
    var secondaryOverdue = false;
    if (isRepair) {
      if (appointment != null) {
        secondaryLabel = appointment;
      } else if (latest?.contactDeadlineAt != null &&
          latest!.contactDeadlineAt!.trim().isNotEmpty) {
        final rem = _deadlineRemaining(latest.contactDeadlineAt);
        secondaryLabel = rem.isEmpty
            ? 'Hẹn gọi · ${formatServiceTime(latest.contactDeadlineAt)}'
            : 'Hẹn gọi · $rem';
        final dt = DateTime.tryParse(latest.contactDeadlineAt!);
        secondaryOverdue = dt != null && dt.isBefore(DateTime.now());
      } else if (latest != null) {
        final rem = _deadlineRemaining(
          latest.deadlineAt,
          markOverdue: latest.isOverdue,
        );
        secondaryLabel = rem.isEmpty ? null : rem;
        secondaryOverdue = latest.isOverdue;
      }
    } else if (latest != null) {
      final rem = _deadlineRemaining(
        latest.deadlineAt,
        markOverdue: latest.isOverdue,
      );
      secondaryLabel = rem.isEmpty ? null : rem;
      secondaryOverdue = latest.isOverdue;
    }

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.displayCode,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(
                          label: requestStatusLabel(request.status),
                          tone: requestStatusTone(request.status),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (elapsed != '—')
                        Text(
                          elapsed,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      if (secondaryLabel != null) ...[
                        const SizedBox(height: 2),
                        if (isRepair && appointment != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                secondaryLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            secondaryLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryOverdue
                                  ? Colors.red
                                  : (isRepair
                                      ? scheme.primary
                                      : const Color(0xFF92400E)),
                            ),
                            textAlign: TextAlign.right,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${request.customerName} · ${request.customerPhone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                request.productName,
                style: const TextStyle(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (request.issueDescription.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Lỗi: ${request.issueDescription.trim()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (creator.isNotEmpty || manager.isNotEmpty) ...[
                const SizedBox(height: 2),
                if (creator.isNotEmpty)
                  Text(
                    'Người tạo: $creator',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (manager.isNotEmpty)
                  Text(
                    'NV quản lý: $manager',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
              if (isRepair && latest != null && latest.type == 'repair') ...[
                const SizedBox(height: 8),
                _RepairProgressBar(
                  status: latest.status,
                  receiveStaffName: latest.receiveStaffName,
                  techStaffName: latest.staffName,
                  deliveryStaffName: latest.deliveryStaffName,
                  managerName: request.managerName,
                ),
              ],
              if (latest != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => onOpenTicket(latest),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          latest.type == 'repair'
                              ? Icons.build_outlined
                              : latest.type == 'onsite'
                                  ? Icons.home_repair_service_outlined
                                  : Icons.headset_mic_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${latest.displayCode} · ${ticketTypeLabel(latest.type)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        StatusBadge(
                          label: ticketStatusLabel(latest.type, latest.status),
                          tone: ticketStatusTone(latest.status),
                        ),
                        if (latest.isOverdue) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: Colors.red,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _RepairFlowStepState { pending, active, done, failed }

class _RepairProgressBar extends StatelessWidget {
  const _RepairProgressBar({
    required this.status,
    this.receiveStaffName,
    this.techStaffName,
    this.deliveryStaffName,
    this.managerName,
  });

  final String status;
  final String? receiveStaffName;
  final String? techStaffName;
  final String? deliveryStaffName;
  final String? managerName;

  static const _labels = [
    'Tiếp nhận',
    'Kiểm tra',
    'Sửa chữa',
    'Bàn giao',
    'Thanh toán',
  ];

  _RepairFlowStepState _stateFor(int i, int activeIndex, bool failed) {
    if (failed) {
      if (i < activeIndex) return _RepairFlowStepState.done;
      if (i == activeIndex) return _RepairFlowStepState.failed;
      return _RepairFlowStepState.pending;
    }
    // activeIndex == length → hoàn thành (tất cả done)
    if (activeIndex >= _labels.length) return _RepairFlowStepState.done;
    if (i < activeIndex) return _RepairFlowStepState.done;
    if (i == activeIndex) return _RepairFlowStepState.active;
    return _RepairFlowStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = status == 'cancelled' || status == 'customer_rejected';
    final rawIndex = repairStepIndex(status);
    // 0..4 = bước đang làm; >=5 = Xong. Khi failed ở Xong → đánh dấu bước cuối.
    final int activeIndex;
    if (failed) {
      activeIndex = rawIndex >= _labels.length
          ? _labels.length - 1
          : rawIndex.clamp(0, _labels.length - 1);
    } else if (rawIndex >= _labels.length) {
      activeIndex = _labels.length; // all done
    } else {
      activeIndex = rawIndex;
    }

    final steps = List.generate(
      _labels.length,
      (i) => (_labels[i], _stateFor(i, activeIndex, failed)),
    );

    Color colorOf(_RepairFlowStepState state) {
      switch (state) {
        case _RepairFlowStepState.done:
          return const Color(0xFF22C55E);
        case _RepairFlowStepState.active:
          return const Color(0xFF5C60E6);
        case _RepairFlowStepState.failed:
          return scheme.error;
        case _RepairFlowStepState.pending:
          return scheme.outlineVariant;
      }
    }

    final connectorColor = (steps[0].$2 == _RepairFlowStepState.pending)
        ? scheme.outlineVariant
        : const Color(0xFF5C60E6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = steps.length;
              final stepWidth = constraints.maxWidth / count;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    top: 11,
                    child: Container(height: 2, color: connectorColor),
                  ),
                  Row(
                    children: List.generate(count, (i) {
                      final state = steps[i].$2;
                      final color = colorOf(state);
                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state == _RepairFlowStepState.pending
                                  ? Colors.transparent
                                  : color,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Center(
                              child: state == _RepairFlowStepState.done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${i + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: state ==
                                                    _RepairFlowStepState
                                                        .pending
                                                ? color
                                                : Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final assignedName = switch (i) {
              0 => receiveStaffName?.trim(),
              1 || 2 => techStaffName?.trim(),
              3 => deliveryStaffName?.trim(),
              4 => managerName?.trim(),
              _ => null,
            };
            return Expanded(
              child: Column(
                children: [
                  Text(
                    s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                  ),
                  if (assignedName != null && assignedName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      assignedName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
