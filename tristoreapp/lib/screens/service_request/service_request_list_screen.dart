import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'create_service_request_screen.dart';
import 'online_ticket_screen.dart';
import 'onsite_ticket_screen.dart';
import 'other_ticket_screen.dart';
import 'repair_ticket_screen.dart';
import 'service_request_detail_screen.dart';
import 'service_ui.dart';
import 'widgets/service_request_list_card.dart';

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
                    : Column(
                        children: [
                          TsDropdownFieldNullable<String>(
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
                          if (widget.tab == 'support') ...[
                            const SizedBox(height: 8),
                            TsDropdownFieldNullable<String>(
                              value: prov.ticketStaffUserId,
                              labelText: 'NV phụ trách',
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
                                prov.setTicketStaffUserId(v);
                                prov.load(reset: true);
                              },
                            ),
                            const SizedBox(height: 8),
                            TsDropdownFieldNullable<String>(
                              value: prov.ticketCostMode,
                              labelText: 'Chi phí',
                              items: const [null, 'free', 'paid'],
                              itemLabel: (id) {
                                if (id == null) return 'Tất cả';
                                if (id == 'free') return 'Miễn phí';
                                return 'Có tính phí';
                              },
                              onChanged: (v) {
                                prov.setTicketCostMode(v);
                                prov.load(reset: true);
                              },
                            ),
                          ],
                        ],
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
    final supportTicketFilters = <(String, String)>[
      ('processing', 'Đang xử lý'),
      ('contact_failed', 'Không liên lạc/gặp được'),
      ('done', 'Hoàn thành'),
      ('failed', 'Không xử lý được'),
      ('cancelled', 'Hủy'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: prov.statusFilter == null &&
                prov.ticketStatus == null &&
                !prov.overdueOnly,
            onSelected: (_) {
              prov.setTicketStatus(null);
              prov.setStatusFilter(null);
              prov.setOverdueOnly(false);
              prov.load(reset: true);
            },
          ),
          const SizedBox(width: 6),
          if (widget.tab == 'support') ...[
            for (final f in supportTicketFilters) ...[
              FilterChip(
                label: Text(f.$2),
                selected: prov.ticketStatus == f.$1,
                onSelected: (_) {
                  prov.setTicketStatus(f.$1);
                  prov.load(reset: true);
                },
              ),
              const SizedBox(width: 6),
            ],
          ] else ...[
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
            return ServiceRequestListCard(
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
