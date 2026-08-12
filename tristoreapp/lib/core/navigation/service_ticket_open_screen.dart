import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/providers/service_requests_provider.dart';

import '../../screens/service_request/online_ticket_screen.dart';
import '../../screens/service_request/onsite_ticket_screen.dart';
import '../../screens/service_request/other_ticket_screen.dart';
import '../../screens/service_request/repair_ticket_screen.dart';

/// Mở đúng màn phiếu từ notification (có `ticketType` hoặc fetch API).
class ServiceTicketOpenScreen extends StatefulWidget {
  const ServiceTicketOpenScreen({
    super.key,
    required this.ticketId,
    this.ticketType,
  });

  final String ticketId;
  final String? ticketType;

  @override
  State<ServiceTicketOpenScreen> createState() =>
      _ServiceTicketOpenScreenState();
}

class _ServiceTicketOpenScreenState extends State<ServiceTicketOpenScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    var type = (widget.ticketType ?? '').trim();
    if (type.isEmpty) {
      try {
        final t = await context
            .read<ServiceRequestsProvider>()
            .fetchTicket(widget.ticketId);
        type = t?.type ?? 'online';
      } catch (e) {
        if (!mounted) return;
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(ServiceRequestsProvider.dioMessage(e))),
        );
        Navigator.pop(context);
        return;
      }
    }
    if (!mounted) return;
    final screen = switch (type) {
      'onsite' => OnsiteTicketScreen(ticketId: widget.ticketId),
      'other' => OtherTicketScreen(ticketId: widget.ticketId),
      'repair' => RepairTicketScreen(ticketId: widget.ticketId),
      _ => OnlineTicketScreen(ticketId: widget.ticketId),
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
