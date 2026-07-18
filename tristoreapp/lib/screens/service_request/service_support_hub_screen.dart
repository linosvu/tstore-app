import 'package:flutter/material.dart';
import 'package:tstore/core/localization/app_localizations.dart';

import 'service_request_list_screen.dart';

/// Hub Hỗ trợ & Sửa chữa — 2 tab.
class ServiceSupportHubScreen extends StatefulWidget {
  const ServiceSupportHubScreen({
    super.key,
    this.initialTab = 0,
    this.statusFilter,
    this.overdueOnly = false,
  });

  final int initialTab;
  final String? statusFilter;
  final bool overdueOnly;

  @override
  State<ServiceSupportHubScreen> createState() =>
      _ServiceSupportHubScreenState();
}

class _ServiceSupportHubScreenState extends State<ServiceSupportHubScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceSupportHubTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.serviceTabSupport)),
                ButtonSegment(value: 1, label: Text(l10n.serviceTabRepair)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ServiceRequestListScreen(
                  tab: 'support',
                  initialStatusFilter:
                      widget.initialTab == 0 ? widget.statusFilter : null,
                  initialOverdue:
                      widget.initialTab == 0 && widget.overdueOnly,
                  embedded: true,
                ),
                ServiceRequestListScreen(
                  tab: 'repair',
                  initialStatusFilter:
                      widget.initialTab == 1 ? widget.statusFilter : null,
                  initialOverdue:
                      widget.initialTab == 1 && widget.overdueOnly,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
