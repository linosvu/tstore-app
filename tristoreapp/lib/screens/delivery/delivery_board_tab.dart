import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/delivery_provider.dart';
import 'package:tstore/screens/delivery/delivery_compact_card.dart';
import 'package:tstore/screens/delivery/delivery_detail_screen.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';

class DeliveryBoardTab extends StatelessWidget {
  const DeliveryBoardTab({super.key});
  static const _todayStatuses = {'pending', 'delivering'};

  Future<void> _assign(
    BuildContext context,
    DeliveryProvider p,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await p.assignToMe(id);
      if (!context.mounted) return;
      AppMessenger.showSnackBar(context, SnackBar(content: Text(l10n.success)));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeliveryDetailScreen(deliveryId: id),
        ),
      );
    } on DioException catch (e) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(
            content:
                Text(e.response?.data?.toString() ?? e.message ?? l10n.error)),
      );
    } catch (e) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = context.watch<DeliveryProvider>();

    if (p.isLoadingBoard && p.boardDeliveries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.errorBoard != null && p.boardDeliveries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          ErrorBanner(message: p.errorBoard!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => p.loadBoard(),
            child: Text(l10n.deliveryRetry),
          ),
        ],
      );
    }
    if (p.boardDeliveries.isEmpty) {
      return EmptyState(
        icon: Icons.dashboard_outlined,
        message: l10n.deliveryBoardEmpty,
      );
    }

    return RefreshIndicator(
      onRefresh: () => p.loadBoard(),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.space2,
        ),
        children: () {
          final todayItems = p.boardDeliveries
              .where((e) => _todayStatuses.contains(e.status))
              .toList();
          final nextItems = p.boardDeliveries
              .where((e) => !_todayStatuses.contains(e.status))
              .toList();
          return [
            _groupDivider(context, l10n.groupTodayCount(todayItems.length)),
            ...todayItems.map((d) => DeliveryCompactCard(
                  d: d,
                  l10n: l10n,
                  scheme: scheme,
                  onOpenDetail: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeliveryDetailScreen(deliveryId: d.id),
                      ),
                    );
                  },
                  onAssignMe: () => _assign(context, p, d.id),
                )),
            if (nextItems.isNotEmpty) _groupDivider(context, l10n.groupNext),
            ...nextItems.map((d) => DeliveryCompactCard(
                  d: d,
                  l10n: l10n,
                  scheme: scheme,
                  onOpenDetail: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeliveryDetailScreen(deliveryId: d.id),
                      ),
                    );
                  },
                  onAssignMe: () => _assign(context, p, d.id),
                )),
          ];
        }(),
      ),
    );
  }

  Widget _groupDivider(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(0, AppSpacing.space2, 0, AppSpacing.space2),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
