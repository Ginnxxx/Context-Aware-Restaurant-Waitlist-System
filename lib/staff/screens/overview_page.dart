import 'package:flutter/material.dart';

import '../../domain/queue_ticket.dart';
import '../../domain/venue_context.dart';
import '../widgets/context_panel.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/queue_panel.dart';
import '../widgets/summary_cards.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.compact,
    required this.queueOpen,
    required this.demoMode,
    required this.tickets,
    required this.venue,
    required this.busyTickets,
    required this.onCallNext,
    required this.onScanQr,
    required this.onTransition,
    required this.onQueueChanged,
    this.venues = const [],
    this.onVenueChanged,
  });

  final bool compact;
  final bool queueOpen;
  final bool demoMode;
  final List<QueueTicket> tickets;
  final VenueContext? venue;
  final Set<String> busyTickets;
  final VoidCallback onCallNext;
  final VoidCallback onScanQr;
  final void Function(QueueTicket ticket, TicketStatus nextStatus) onTransition;
  final ValueChanged<bool> onQueueChanged;
  final List<VenueContext> venues;
  final ValueChanged<VenueContext>? onVenueChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DashboardHeader(
        compact: compact,
        queueOpen: queueOpen,
        demoMode: demoMode,
        onQueueChanged: onQueueChanged,
        venues: venues,
        currentVenue: venue,
        onVenueChanged: onVenueChanged,
      ),
      const SizedBox(height: 26),
      SummaryRow(tickets: tickets, seatCapacity: venue?.seatCapacity ?? 40),
      const SizedBox(height: 24),
      if (compact) ...[
        QueuePanel(
          tickets: tickets,
          onCallNext: onCallNext,
          onScanQr: onScanQr,
          busyTickets: busyTickets,
          onTransition: onTransition,
        ),
        const SizedBox(height: 18),
        ContextPanel(tickets: tickets),
      ] else
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: QueuePanel(
                tickets: tickets,
                onCallNext: onCallNext,
                onScanQr: onScanQr,
                busyTickets: busyTickets,
                onTransition: onTransition,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: ContextPanel(tickets: tickets)),
          ],
        ),
    ],
  );
}
