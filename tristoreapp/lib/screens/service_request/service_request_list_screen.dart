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
  Map<String, int> _repairStats = {};
  List<RepairVendorPublic> _vendors = [];
  List<RepairTechnicianPublic> _technicians = [];

  static const _repairSubFilters = <(String, String)>[
    ('pending_check', 'Chưa KT'),
    ('pending_send', 'Chờ gửi'),
    ('in_repair', 'Sửa shop'),
    ('at_vendor', 'Sửa ngoài'),
    ('pending_delivery', 'Trả KH'),
    ('pending_payment', 'Chờ TT'),
    ('pending_approval', 'Chờ duyệt'),
    ('debt_open', 'Công nợ'),
  ];

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
      if (widget.tab == 'repair') _loadRepairFilters();
      _prov.load(reset: true);
    });
  }

  Future<void> _loadRepairFilters() async {
    final stats = await _prov.fetchRepairStats();
    final vendors = await _prov.fetchRepairVendors();
    final techs = await _prov.fetchRepairTechnicians();
    if (!mounted) return;
    setState(() {
      _repairStats = stats;
      _vendors = vendors;
      _technicians = techs;
    });
  }

  Future<void> _reloadList() async {
    await _prov.load(reset: true);
    if (widget.tab == 'repair') await _loadRepairFilters();
  }

  Future<void> _openRepairFilterSheet(ServiceRequestsProvider prov) async {
    final selected = (prov.subStatusIn ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    String? vendorId = prov.vendorIdFilter;
    String? technicianId = prov.technicianIdFilter;
    String? repairType = prov.repairTypeFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Lọc phiếu sửa chữa',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in _repairSubFilters)
                        FilterChip(
                          label: Text(f.$2),
                          selected: selected.contains(f.$1),
                          onSelected: (v) {
                            setLocal(() {
                              if (v) {
                                selected.add(f.$1);
                              } else {
                                selected.remove(f.$1);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TsDropdownFieldNullable<String>(
                    value: repairType,
                    labelText: 'Hình thức',
                    items: const [null, 'in_store', 'external'],
                    itemLabel: (v) {
                      if (v == null) return 'Tất cả';
                      return repairTypeLabel(v);
                    },
                    onChanged: (v) => setLocal(() => repairType = v),
                  ),
                  const SizedBox(height: 8),
                  TsDropdownFieldNullable<String>(
                    value: vendorId,
                    labelText: 'Đơn vị sửa ngoài',
                    items: [null, ..._vendors.map((v) => v.id)],
                    itemLabel: (id) {
                      if (id == null) return 'Tất cả';
                      for (final v in _vendors) {
                        if (v.id == id) return v.name;
                      }
                      return id;
                    },
                    onChanged: (v) => setLocal(() => vendorId = v),
                  ),
                  const SizedBox(height: 8),
                  TsDropdownFieldNullable<String>(
                    value: technicianId,
                    labelText: 'Kỹ thuật viên',
                    items: [null, ..._technicians.map((t) => t.id)],
                    itemLabel: (id) {
                      if (id == null) return 'Tất cả';
                      for (final t in _technicians) {
                        if (t.id == id) return t.name;
                      }
                      return id;
                    },
                    onChanged: (v) => setLocal(() => technicianId = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      prov.setRepairListFilters(
                        subStatusIn: selected.isEmpty
                            ? null
                            : selected.join(','),
                        repairType: repairType,
                        vendorId: vendorId,
                        technicianId: technicianId,
                        clearSubStatus: selected.isEmpty,
                        clearRepairType: repairType == null,
                        clearVendor: vendorId == null,
                        clearTechnician: technicianId == null,
                      );
                      Navigator.pop(ctx);
                      _reloadList();
                    },
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
    if (ok == true) await _reloadList();
  }

  void _openRequest(ServiceRequestPublic req) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceRequestDetailScreen(requestId: req.id),
      ),
    ).then((_) => _reloadList());
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
    ).then((_) => _reloadList());
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: l10n.serviceSearchHint,
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              prov.setSearch('');
                              prov.load(reset: true);
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          prov.setSearch(v);
                          prov.load(reset: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _loadingUsers
                          ? const SizedBox(
                              height: 48,
                              child: Center(
                                child: LinearProgressIndicator(),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: TsDropdownFieldNullable<String>(
                                    value: prov.supportStaffUserId,
                                    items: [
                                      null,
                                      ..._users.map((u) => u.$1),
                                    ],
                                    itemLabel: (id) {
                                      if (id == null) return 'Tất cả NV';
                                      for (final u in _users) {
                                        if (u.$1 == id) return u.$2;
                                      }
                                      return id;
                                    },
                                    onChanged: (v) {
                                      prov.setSupportStaffUserId(v);
                                      _reloadList();
                                    },
                                  ),
                                ),
                                if (widget.tab == 'repair') ...[
                                  IconButton(
                                    tooltip: 'Lọc nâng cao',
                                    onPressed: () => _openRepairFilterSheet(prov),
                                    icon: Badge(
                                      isLabelVisible: prov.subStatusIn != null ||
                                          prov.vendorIdFilter != null ||
                                          prov.technicianIdFilter != null ||
                                          prov.repairTypeFilter != null,
                                      child: const Icon(Icons.tune),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
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

    final repairClearAll = prov.statusFilter == null &&
        prov.ticketStatus == null &&
        !prov.overdueOnly &&
        !prov.dueSoonOnly &&
        prov.subStatusIn == null &&
        prov.vendorIdFilter == null &&
        prov.technicianIdFilter == null &&
        prov.repairTypeFilter == null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: widget.tab == 'repair'
                ? repairClearAll
                : prov.statusFilter == null &&
                    prov.ticketStatus == null &&
                    !prov.overdueOnly &&
                    !prov.dueSoonOnly,
            onSelected: (_) {
              prov.setTicketStatus(null);
              prov.setStatusFilter(null);
              prov.setOverdueOnly(false);
              prov.setDueSoonOnly(false);
              if (widget.tab == 'repair') {
                prov.setRepairListFilters(
                  clearSubStatus: true,
                  clearRepairType: true,
                  clearVendor: true,
                  clearTechnician: true,
                );
              }
              _reloadList();
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Cần xử lý 24h'),
            selected: prov.dueSoonOnly,
            onSelected: (_) {
              prov.setDueSoonOnly(true);
              _reloadList();
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Quá hạn'),
            selected: prov.overdueOnly,
            onSelected: (_) {
              prov.setOverdueOnly(true);
              _reloadList();
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
                  _reloadList();
                },
              ),
              const SizedBox(width: 6),
            ],
          ] else if (widget.tab == 'repair') ...[
            for (final f in _repairSubFilters) ...[
              FilterChip(
                label: Text(
                  _repairStats[f.$1] != null && _repairStats[f.$1]! > 0
                      ? '${f.$2} (${_repairStats[f.$1]})'
                      : f.$2,
                ),
                selected: prov.subStatusIn == f.$1,
                onSelected: (_) {
                  prov.setRepairListFilters(subStatusIn: f.$1);
                  _reloadList();
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
                  _reloadList();
                },
              ),
              const SizedBox(width: 6),
            ],
          ],
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
        onRetry: () => _reloadList(),
      );
    }
    if (prov.items.isEmpty) {
      return EmptyState(
        icon: Icons.support_agent_outlined,
        message: l10n.serviceListEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _reloadList(),
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
