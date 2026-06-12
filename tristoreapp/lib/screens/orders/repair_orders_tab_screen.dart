import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/repair_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/repair_orders_provider.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/section_card.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';
import 'package:tstore/widgets/ui/ts_status_dropdown_field.dart';

const _repairStatuses = [
  'received',
  'diagnosing',
  'repairing',
  'waiting_parts',
  'done',
  'returned',
  'cancelled',
];

const _repairPriorities = ['low', 'normal', 'high', 'urgent'];

String _repairStatusLabel(String s, AppLocalizations l10n) {
  switch (s) {
    case 'received':
      return 'Đã nhận';
    case 'diagnosing':
      return 'Đang kiểm tra';
    case 'repairing':
      return 'Đang sửa';
    case 'waiting_parts':
      return 'Chờ linh kiện';
    case 'done':
      return 'Đã sửa xong';
    case 'returned':
      return 'Đã trả khách';
    case 'cancelled':
      return 'Đã hủy';
    default:
      return s;
  }
}

StatusBadgeTone _repairStatusTone(String s) {
  switch (s) {
    case 'done':
    case 'returned':
      return StatusBadgeTone.success;
    case 'cancelled':
      return StatusBadgeTone.error;
    case 'waiting_parts':
      return StatusBadgeTone.warning;
    default:
      return StatusBadgeTone.info;
  }
}

StatusBadgeTone _repairPriorityTone(String p) {
  switch (p) {
    case 'urgent':
    case 'high':
      return StatusBadgeTone.error;
    case 'low':
      return StatusBadgeTone.neutral;
    default:
      return StatusBadgeTone.info;
  }
}

String _repairPriorityLabel(String p, AppLocalizations l10n) {
  switch (p) {
    case 'low':
      return 'Thấp';
    case 'normal':
      return 'Bình thường';
    case 'high':
      return 'Cao';
    case 'urgent':
      return 'Khẩn';
    default:
      return p;
  }
}

/// Tab Sửa chữa trong màn Đơn hàng (dữ liệu từ backend).
class RepairOrdersTabScreen extends StatefulWidget {
  const RepairOrdersTabScreen({super.key});

  @override
  State<RepairOrdersTabScreen> createState() => _RepairOrdersTabScreenState();
}

class _RepairOrdersTabScreenState extends State<RepairOrdersTabScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'received';
  String _priority = 'normal';
  String? _received;
  String? _promised;
  bool _submitting = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _received = _todayYmd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<RepairOrdersProvider>();
      final elevated = _elevated(context);
      if (!elevated) {
        p.setScope('mine');
      }
      p.load(reset: true);
    });
  }

  bool _elevated(BuildContext context) {
    final u = context.read<AuthProvider>().user;
    return u != null && (u.role == 'admin' || u.role == 'manager');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _itemCtrl.dispose();
    _issueCtrl.dispose();
    _notesCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _todayYmd() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty && digits.length < 9) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.saleOrderNeedNameOrPhone)),
      );
      return;
    }
    if (_itemCtrl.text.trim().isEmpty || _issueCtrl.text.trim().isEmpty) {
      AppMessenger.showSnackBar(context, 
        const SnackBar(content: Text('Nhập thiết bị và nội dung sửa chữa.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final p = context.read<RepairOrdersProvider>();
    final body = <String, dynamic>{
      'customerName': name.isNotEmpty ? name : _phoneCtrl.text.trim(),
      'customerPhone': _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      'itemDescription': _itemCtrl.text.trim(),
      'issueDescription': _issueCtrl.text.trim(),
      'status': _status,
      'priority': _priority,
      'receivedDate': _received,
      if (_promised != null && _promised!.isNotEmpty) 'promisedDate': _promised,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    try {
      final created = await p.create(body);
      if (!mounted) return;
      if (created != null) {
        AppMessenger.showSnackBar(context, 
          SnackBar(content: Text(l10n.repairCreated)),
        );
        _itemCtrl.clear();
        _issueCtrl.clear();
        _notesCtrl.clear();
        await p.load(reset: true);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showSnackBar(context, 
          const SnackBar(content: Text('Không tạo được đơn.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Consumer<RepairOrdersProvider>(
            builder: (context, prov, _) {
              if (prov.error != null && prov.items.isEmpty) {
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    ErrorBanner(
                      message: prov.error!,
                      retryLabel: l10n.productsRetry,
                      onRetry: () => prov.load(reset: true),
                    ),
                  ],
                );
              }
              if (prov.isLoading && prov.items.isEmpty) {
                return const ListSkeleton(
                  rows: 5,
                  variant: ListSkeletonVariant.orderRow,
                );
              }
              return RefreshIndicator(
                onRefresh: () => prov.load(reset: true),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                        child: SectionCard(
                          title: l10n.repairFormTitle,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.repairCustomerName,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _phoneCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.repairCustomerPhone,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _itemCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.repairItemDescription,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _issueCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.repairIssueDescription,
                                    border: const OutlineInputBorder(),
                                  ),
                                  minLines: 2,
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TsDropdownField<String>(
                                        value: _status,
                                        labelText: l10n.repairStatus,
                                        items: _repairStatuses,
                                        itemLabel: (s) =>
                                            _repairStatusLabel(s, l10n),
                                        onChanged: (v) => setState(
                                          () => _status = v ?? 'received',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TsDropdownField<String>(
                                        value: _priority,
                                        labelText: l10n.repairPriority,
                                        items: _repairPriorities,
                                        itemLabel: (p) =>
                                            _repairPriorityLabel(p, l10n),
                                        onChanged: (v) => setState(
                                          () => _priority = v ?? 'normal',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: l10n.repairReceivedDate,
                                          border: const OutlineInputBorder(),
                                        ),
                                        child: Text(_received ?? '—'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.tryParse(
                                                    '${_received ?? _todayYmd()}T12:00:00',
                                                  ) ??
                                              DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (d != null && mounted) {
                                          setState(() {
                                            _received =
                                                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.calendar_today_outlined),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: l10n.repairPromisedDate,
                                          border: const OutlineInputBorder(),
                                        ),
                                        child: Text(_promised ?? '—'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                        );
                                        if (d != null && mounted) {
                                          setState(() {
                                            _promised =
                                                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.event_outlined),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _notesCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.repairNotes,
                                    border: const OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _submitting ? null : () => _submit(l10n),
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(l10n.repairSubmit),
                                ),
                              ],
                            ),
                        ),
                      ),
                    ),
                    if (_elevated(context))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenHorizontal,
                          ),
                          child: TsDropdownField<String>(
                            value: prov.listScope,
                            labelText: l10n.fulfillmentScopeLabel,
                            items: const ['mine', 'all'],
                            itemLabel: (v) =>
                                v == 'mine' ? 'Của tôi' : 'Toàn hệ thống',
                            onChanged: (v) {
                              if (v == null) return;
                              prov.setScope(v);
                              prov.load(reset: true);
                            },
                          ),
                        ),
                      ),
                    if (prov.items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(message: l10n.repairListEmpty),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          0,
                          AppSpacing.screenHorizontal,
                          AppSpacing.space4,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final item = prov.items[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RepairCard(
                                  item: item,
                                  l10n: l10n,
                                  scheme: scheme,
                                  onStatus: (st) async {
                                    await prov.patchStatus(item.id, st);
                                    if (context.mounted) {
                                      await prov.load(reset: true);
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: prov.items.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
    );
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({
    required this.item,
    required this.l10n,
    required this.scheme,
    required this.onStatus,
  });

  final RepairOrderPublic item;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final Future<void> Function(String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                StatusBadge(
                  label: _repairStatusLabel(item.status, l10n),
                  tone: item.status == 'cancelled'
                      ? StatusBadgeTone.error
                      : item.status == 'done' || item.status == 'returned'
                          ? StatusBadgeTone.success
                          : StatusBadgeTone.info,
                ),
              ],
            ),
            if (item.customerPhone != null && item.customerPhone!.isNotEmpty)
              Text(item.customerPhone!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(item.itemDescription),
            Text(item.issueDescription, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              '${l10n.repairReceivedDate}: ${item.receivedDate ?? '—'} · ${l10n.repairPromisedDate}: ${item.promisedDate ?? '—'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            TsStatusDropdownField(
              caption: l10n.repairStatus,
              value: item.status,
              options: _repairStatuses,
              labelFor: (s) => _repairStatusLabel(s, l10n),
              onChanged: (v) {
                if (v != null && v != item.status) onStatus(v);
              },
            ),
          ],
        ),
    );
  }
}
