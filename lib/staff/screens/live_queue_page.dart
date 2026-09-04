import 'package:flutter/material.dart';

import '../../domain/queue_ticket.dart';
import '../widgets/empty_queue.dart';
import '../widgets/page_intro.dart';
import '../widgets/ticket_row.dart';

class LiveQueuePage extends StatefulWidget {
  const LiveQueuePage({
    super.key,
    required this.tickets,
    required this.busyTickets,
    required this.onCallNext,
    required this.onScanQr,
    required this.onTransition,
  });

  final List<QueueTicket> tickets;
  final Set<String> busyTickets;
  final VoidCallback onCallNext;
  final VoidCallback onScanQr;
  final void Function(QueueTicket ticket, TicketStatus nextStatus) onTransition;

  @override
  State<LiveQueuePage> createState() => _LiveQueuePageState();
}

class _LiveQueuePageState extends State<LiveQueuePage> {
  String query = '';
  TicketStatus? status;

  @override
  Widget build(BuildContext context) {
    final visible = widget.tickets
        .where((ticket) {
          final active = switch (ticket.status) {
            TicketStatus.waiting ||
            TicketStatus.approaching ||
            TicketStatus.called ||
            TicketStatus.arrived => true,
            _ => false,
          };
          if (!active || status != null && ticket.status != status) {
            return false;
          }
          final needle = query.trim().toLowerCase();
          return needle.isEmpty ||
              ticket.guestName.toLowerCase().contains(needle) ||
              ticket.id.toLowerCase().contains(needle);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'OPERATIONS',
          title: 'Live queue',
          subtitle:
              'Find a party quickly, monitor arrival context and move each ticket forward.',
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search guest name or ticket ID',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All active'),
                        selected: status == null,
                        onSelected: (_) => setState(() => status = null),
                      ),
                      const SizedBox(width: 8),
                      for (final item in const [
                        TicketStatus.waiting,
                        TicketStatus.approaching,
                        TicketStatus.called,
                        TicketStatus.arrived,
                      ]) ...[
                        FilterChip(
                          label: Text(item.label),
                          selected: status == item,
                          onSelected: (_) => setState(() => status = item),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${visible.length} parties matching',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onScanQr,
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 19,
                          ),
                          label: const Text('Scan arrival'),
                        ),
                        FilledButton.icon(
                          onPressed: widget.onCallNext,
                          icon: const Icon(Icons.campaign_outlined, size: 19),
                          label: const Text('Call next'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const EmptyQueue()
                else
                  for (final ticket in visible)
                    TicketRow(
                      ticket: ticket,
                      busy: widget.busyTickets.contains(ticket.id),
                      onTransition: (next) => widget.onTransition(ticket, next),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
