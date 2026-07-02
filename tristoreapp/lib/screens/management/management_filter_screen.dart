import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';

import 'management_date_presets.dart';

class ManagementFilterScreen extends StatefulWidget {
  const ManagementFilterScreen({
    super.key,
    required this.entity,
    required this.initialFilters,
    this.titleOverride,
  });

  final ManagementEntity entity;
  final ManagementFilters initialFilters;
  final String? titleOverride;

  @override
  State<ManagementFilterScreen> createState() => _ManagementFilterScreenState();
}

class _ManagementFilterScreenState extends State<ManagementFilterScreen> {
  late ManagementFilters _filters = widget.initialFilters;
  List<({String id, String name, String email})> _staff = [];
  bool _loadingStaff = true;

  ManagementProvider get _mgmt =>
      ManagementProvider(api: context.read<AuthProvider>().api);

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final list = await _mgmt.fetchStaffUsers();
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

  String _title(AppLocalizations l10n) {
    if (widget.titleOverride != null && widget.titleOverride!.isNotEmpty) {
      return widget.titleOverride!;
    }
    switch (widget.entity) {
      case ManagementEntity.saleOrders:
        return '${l10n.managementFilterTitle} — ${l10n.managementCardOrders}';
      case ManagementEntity.deliveries:
        return '${l10n.managementFilterTitle} — ${l10n.managementCardDeliveries}';
      case ManagementEntity.preparations:
        return '${l10n.managementFilterTitle} — ${l10n.managementCardPreparations}';
      case ManagementEntity.tasks:
        return '${l10n.managementFilterTitle} — ${l10n.managementCardTasks}';
    }
  }

  bool _datePresetMatches(({String? from, String? to}) preset) {
    return _filters.from == preset.from && _filters.to == preset.to;
  }

  bool get _isDateCustomSelected {
    if (_filters.from == null && _filters.to == null) return false;
    return !_datePresetMatches(ManagementDatePresets.today()) &&
        !_datePresetMatches(ManagementDatePresets.yesterday()) &&
        !_datePresetMatches(ManagementDatePresets.last7Days()) &&
        !_datePresetMatches(ManagementDatePresets.thisMonth()) &&
        !_datePresetMatches(ManagementDatePresets.all());
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _filters.from != null && _filters.to != null
          ? DateTimeRange(
              start: DateTime.parse(_filters.from!),
              end: DateTime.parse(_filters.to!),
            )
          : null,
    );
    if (range == null || !mounted) return;
    final from =
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final to =
        '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
    setState(() => _filters = _filters.copyWith(from: from, to: to));
  }

  void _applyDatePreset(({String? from, String? to}) preset) {
    setState(() => _filters = _filters.copyWith(
          from: preset.from,
          to: preset.to,
          clearFrom: preset.from == null,
          clearTo: preset.to == null,
        ));
  }

  void _togglePayment(String value) {
    setState(() {
      if (_filters.paymentFilter == value) {
        _filters = _filters.copyWith(clearPaymentFilter: true);
      } else {
        _filters = _filters.copyWith(paymentFilter: value);
      }
    });
  }

  void _togglePriority(String value) {
    setState(() {
      if (_filters.priority == value) {
        _filters = _filters.copyWith(clearPriority: true);
      } else {
        _filters = _filters.copyWith(priority: value);
      }
    });
  }

  void _toggleExpectedDelivery(String value) {
    setState(() {
      if (_filters.expectedDeliveryFilter == value) {
        _filters = _filters.copyWith(clearExpectedDeliveryFilter: true);
      } else {
        _filters = _filters.copyWith(expectedDeliveryFilter: value);
      }
    });
  }

  bool get _prepUnassignedPresetSelected =>
      _filters.status == 'in_progress' && _filters.assigneeUnassigned == true;

  bool get _deliveryUnassignedPresetSelected =>
      _filters.status == 'pending' && _filters.assigneeUnassigned == true;

  void _applyPrepUnassignedPreset() {
    setState(() {
      if (_prepUnassignedPresetSelected) {
        _filters = _filters.copyWith(
          clearStatus: true,
          clearAssigneeUnassigned: true,
        );
      } else {
        _filters = _filters.copyWith(
          status: 'in_progress',
          assigneeUnassigned: true,
          clearAssigned: true,
        );
      }
    });
  }

  void _applyDeliveryUnassignedPreset() {
    setState(() {
      if (_deliveryUnassignedPresetSelected) {
        _filters = _filters.copyWith(
          clearStatus: true,
          clearAssigneeUnassigned: true,
        );
      } else {
        _filters = _filters.copyWith(
          status: 'pending',
          assigneeUnassigned: true,
          clearAssigned: true,
        );
      }
    });
  }

  void _togglePrepInProgressOnly() {
    setState(() {
      if (_filters.status == 'in_progress' && _filters.assigneeUnassigned != true) {
        _filters = _filters.copyWith(clearStatus: true);
      } else {
        _filters = _filters.copyWith(
          status: 'in_progress',
          clearAssigneeUnassigned: true,
          clearAssigned: true,
        );
      }
    });
  }

  void _toggleDeliveryPendingOnly() {
    setState(() {
      if (_filters.status == 'pending' && _filters.assigneeUnassigned != true) {
        _filters = _filters.copyWith(clearStatus: true);
      } else {
        _filters = _filters.copyWith(
          status: 'pending',
          clearAssigneeUnassigned: true,
          clearAssigned: true,
        );
      }
    });
  }

  void _apply() {
    Navigator.pop(context, _filters);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = context.read<AuthProvider>().user?.id;
    final creatorPicked = _filters.createdByUserId != null &&
        _filters.createdByUserId != me;
    final assigneePicked = _filters.assignedUserId != null;
    final assigneeUnassigned = _filters.assigneeUnassigned == true;
    final assigneeAll =
        _filters.assignedUserId == null && _filters.assigneeUnassigned != true;

    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          _sectionTitle(l10n.managementSectionDate),
          _chipRow([
            _chip(
              l10n.managementDateToday,
              selected: _datePresetMatches(ManagementDatePresets.today()),
              onTap: () => _applyDatePreset(ManagementDatePresets.today()),
            ),
            _chip(
              l10n.managementDateYesterday,
              selected: _datePresetMatches(ManagementDatePresets.yesterday()),
              onTap: () => _applyDatePreset(ManagementDatePresets.yesterday()),
            ),
            _chip(
              l10n.managementDateLast7,
              selected: _datePresetMatches(ManagementDatePresets.last7Days()),
              onTap: () => _applyDatePreset(ManagementDatePresets.last7Days()),
            ),
            _chip(
              l10n.managementDateThisMonth,
              selected: _datePresetMatches(ManagementDatePresets.thisMonth()),
              onTap: () => _applyDatePreset(ManagementDatePresets.thisMonth()),
            ),
            _chip(
              l10n.managementDateAll,
              selected: _datePresetMatches(ManagementDatePresets.all()),
              onTap: () => _applyDatePreset(ManagementDatePresets.all()),
            ),
            _chip(
              _isDateCustomSelected && _filters.from != null && _filters.to != null
                  ? '${l10n.managementDateCustom}: ${_filters.from} → ${_filters.to}'
                  : l10n.managementDateCustom,
              selected: _isDateCustomSelected,
              onTap: _pickDateRange,
            ),
          ]),
          const SizedBox(height: AppSpacing.sectionGap),
          _sectionTitle(l10n.managementSectionCreator),
          _chipRow([
            _chip(
              l10n.managementCreatorAll,
              selected: _filters.createdByUserId == null,
              onTap: () {
                setState(() => _filters = _filters.copyWith(clearCreatedBy: true));
              },
            ),
            if (me != null)
              _chip(
                l10n.managementCreatorMe,
                selected: _filters.createdByUserId == me,
                onTap: () {
                  final u = context.read<AuthProvider>().user!;
                  setState(() => _filters = _filters.copyWith(
                        createdByUserId: u.id,
                        createdByUserName: u.fullName,
                      ));
                },
              ),
            if (!_loadingStaff)
              _chip(
                l10n.managementCreatorPick,
                selected: creatorPicked,
                onTap: () => _pickStaff(isCreator: true),
              ),
            if (creatorPicked && (_filters.createdByUserName ?? '').isNotEmpty)
              _chip(
                _filters.createdByUserName!,
                selected: true,
                onTap: () => _pickStaff(isCreator: true),
              ),
          ]),
          if (widget.entity == ManagementEntity.preparations) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.managementSectionPrepInProgress),
            _chipRow([
              _chip(
                l10n.managementPrepNoAssignee,
                selected: _prepUnassignedPresetSelected,
                onTap: _applyPrepUnassignedPreset,
              ),
              _chip(
                l10n.prepStatusInProgress,
                selected: _filters.status == 'in_progress' &&
                    _filters.assigneeUnassigned != true,
                onTap: _togglePrepInProgressOnly,
              ),
            ]),
          ],
          if (widget.entity == ManagementEntity.deliveries) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.managementSectionDeliveryPending),
            _chipRow([
              _chip(
                l10n.managementDeliveryNoAssignee,
                selected: _deliveryUnassignedPresetSelected,
                onTap: _applyDeliveryUnassignedPreset,
              ),
              _chip(
                l10n.deliveryStatusPending,
                selected: _filters.status == 'pending' &&
                    _filters.assigneeUnassigned != true,
                onTap: _toggleDeliveryPendingOnly,
              ),
            ]),
          ],
          if (widget.entity == ManagementEntity.saleOrders) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.managementSectionExpectedDelivery),
            _chipRow([
              _chip(
                l10n.managementExpectedDueSoon,
                selected: _filters.expectedDeliveryFilter == 'due_soon',
                onTap: () => _toggleExpectedDelivery('due_soon'),
              ),
              _chip(
                l10n.managementExpectedOverdue,
                selected: _filters.expectedDeliveryFilter == 'overdue',
                onTap: () => _toggleExpectedDelivery('overdue'),
              ),
            ]),
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.managementSectionPayment),
            _chipRow([
              _chip(
                l10n.managementPaymentPaid,
                selected: _filters.paymentFilter == 'paid',
                onTap: () => _togglePayment('paid'),
              ),
              _chip(
                l10n.managementPaymentUnpaid,
                selected: _filters.paymentFilter == 'unpaid',
                onTap: () => _togglePayment('unpaid'),
              ),
              _chip(
                l10n.managementPaymentScheduled,
                selected: _filters.paymentFilter == 'scheduled',
                onTap: () => _togglePayment('scheduled'),
              ),
              _chip(
                l10n.managementPaymentPendingConfirm,
                selected: _filters.paymentFilter == 'pending_confirmation',
                onTap: () => _togglePayment('pending_confirmation'),
              ),
            ]),
          ],
          if (widget.entity == ManagementEntity.deliveries ||
              widget.entity == ManagementEntity.preparations ||
              widget.entity == ManagementEntity.tasks) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.managementSectionAssignee),
            _chipRow([
              _chip(
                l10n.managementAssigneeAll,
                selected: assigneeAll,
                onTap: () {
                  setState(() => _filters = _filters.copyWith(
                        clearAssigned: true,
                        clearAssigneeUnassigned: true,
                      ));
                },
              ),
              _chip(
                l10n.managementAssigneeUnassigned,
                selected: assigneeUnassigned && !assigneePicked,
                onTap: () {
                  setState(() => _filters = _filters.copyWith(
                        assigneeUnassigned: true,
                        clearAssigned: true,
                      ));
                },
              ),
              if (!_loadingStaff)
                _chip(
                  l10n.managementAssigneePick,
                  selected: assigneePicked,
                  onTap: () => _pickStaff(isCreator: false),
                ),
              if (assigneePicked && (_filters.assignedUserName ?? '').isNotEmpty)
                _chip(
                  _filters.assignedUserName!,
                  selected: true,
                  onTap: () => _pickStaff(isCreator: false),
                ),
            ]),
          ],
          if (widget.entity == ManagementEntity.deliveries ||
              widget.entity == ManagementEntity.preparations) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _chipRow([
              _chip(
                l10n.managementScheduledDelivery,
                selected: _filters.hasScheduledDelivery == true,
                onTap: () {
                  setState(() {
                    if (_filters.hasScheduledDelivery == true) {
                      _filters = _filters.copyWith(clearScheduled: true);
                    } else {
                      _filters = _filters.copyWith(hasScheduledDelivery: true);
                    }
                  });
                },
              ),
            ]),
          ],
          if (widget.entity == ManagementEntity.tasks) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle(l10n.tasksPrioritySection),
            _chipRow([
              _chip(
                l10n.managementPriorityNormal,
                selected: _filters.priority == 'normal',
                onTap: () => _togglePriority('normal'),
              ),
              _chip(
                l10n.managementPriorityHigh,
                selected: _filters.priority == 'high',
                onTap: () => _togglePriority('high'),
              ),
            ]),
          ],
          if (widget.entity == ManagementEntity.deliveries) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _sectionTitle('Ưu tiên'),
            _chipRow([
              _chip(
                l10n.managementPriorityLow,
                selected: _filters.priority == 'low',
                onTap: () => _togglePriority('low'),
              ),
              _chip(
                l10n.managementPriorityNormal,
                selected: _filters.priority == 'normal',
                onTap: () => _togglePriority('normal'),
              ),
              _chip(
                l10n.managementPriorityHigh,
                selected: _filters.priority == 'high',
                onTap: () => _togglePriority('high'),
              ),
              _chip(
                l10n.managementPriorityUrgent,
                selected: _filters.priority == 'urgent',
                onTap: () => _togglePriority('urgent'),
              ),
            ]),
          ],
          const SizedBox(height: AppSpacing.space6),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _filters = ManagementFilters.empty);
                  },
                  child: Text(l10n.managementClearFilter),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _apply,
                  child: Text(l10n.managementApplyFilter),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStaff({required bool isCreator}) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<({String id, String name, String email})?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (!isCreator)
              ListTile(
                title: Text(l10n.managementAssigneeUnassigned),
                onTap: () => Navigator.pop(ctx, null),
              ),
            if (!isCreator && _staff.isNotEmpty) const Divider(height: 1),
            for (final u in _staff)
              ListTile(
                title: Text(u.name),
                subtitle: Text(u.email),
                onTap: () => Navigator.pop(ctx, u),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (isCreator) {
        if (picked == null) return;
        _filters = _filters.copyWith(
          createdByUserId: picked.id,
          createdByUserName: picked.name,
        );
      } else {
        if (picked == null) {
          _filters = _filters.copyWith(
            assigneeUnassigned: true,
            clearAssigned: true,
          );
        } else {
          _filters = _filters.copyWith(
            assignedUserId: picked.id,
            assignedUserName: picked.name,
            clearAssigneeUnassigned: true,
          );
        }
      }
    });
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Text(
        t,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: chips,
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? AppColors.primary : scheme.outline;
    final bg = selected ? AppColors.primaryTint : scheme.surface;
    final fg = selected ? AppColors.primary : scheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_circle_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
