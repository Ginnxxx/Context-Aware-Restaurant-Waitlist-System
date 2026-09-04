import 'package:flutter/material.dart';

import '../../domain/queue_ticket.dart';
import 'empty_queue.dart';
import 'ticket_row.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.tickets,
    required this.onCallNext,
    required this.onScanQr,
    required this.busyTickets,
    required this.onTransition,
  });

  final List<QueueTicket> tickets;
  final VoidCallback onCallNext;
  final VoidCallback onScanQr;
  final Set<String> busyTickets;
  final void Function(QueueTicket ticket, TicketStatus nextStatus) onTransition;

  @override
  Widget build(BuildContext context) {
    final activeTickets = tickets
        .where(
          (ticket) => switch (ticket.status) {
            TicketStatus.waiting ||
            TicketStatus.approaching ||
            TicketStatus.called ||
            TicketStatus.arrived => true,
            _ => false,
          },
        )
        .toList(growable: false);
    final canCallNext = activeTickets.any(
      (ticket) =>
          ticket.status == TicketStatus.waiting ||
          ticket.status == TicketStatus.approaching,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live queue',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updates in real time',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onScanQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                      label: const Text('Scan arrival'),
                    ),
                    FilledButton.icon(
                      onPressed: canCallNext ? onCallNext : null,
                      icon: const Icon(Icons.campaign_outlined, size: 19),
                      label: const Text('Call next'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (activeTickets.isEmpty)
              const EmptyQueue()
            else
              for (final ticket in activeTickets)
                TicketRow(
                  ticket: ticket,
                  busy: busyTickets.contains(ticket.id),
                  onTransition: (status) => onTransition(ticket, status),
                ),
          ],
        ),
      ),
    );
  }
}
