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

import 'create_service_request_screen.dart';
import 'online_ticket_screen.dart';
import 'onsite_ticket_screen.dart';
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
      _prov.load(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _prov.dispose();
    super.dispose();
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
    Widget screen;
    switch (t.type) {
      case 'online':
        screen = OnlineTicketScreen(ticketId: t.id);
      case 'onsite':
        screen = OnsiteTicketScreen(ticketId: t.id);
      case 'repair':
        screen = RepairTicketScreen(ticketId: t.id);
      default:
        screen = OnlineTicketScreen(ticketId: t.id);
    }
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

  @override
  Widget build(BuildContext context) {
    final latest = request.latestTicket;
    return Material(
      color: Theme.of(context).colorScheme.surface,
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
                children: [
                  Expanded(
                    child: Text(
                      request.displayCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusBadge(
                    label: requestStatusLabel(request.status),
                    tone: requestStatusTone(request.status),
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
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
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
