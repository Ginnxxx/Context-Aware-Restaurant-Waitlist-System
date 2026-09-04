import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../../shared/brand_widgets.dart';
import '../widgets/empty_queue.dart';
import '../widgets/page_intro.dart';
import '../widgets/ticket_row.dart';

class CheckInPage extends StatelessWidget {
  const CheckInPage({
    super.key,
    required this.tickets,
    required this.busyTickets,
    required this.onScanQr,
    required this.onTransition,
    required this.onRelease,
  });

  final List<QueueTicket> tickets;
  final Set<String> busyTickets;
  final VoidCallback onScanQr;
  final void Function(QueueTicket ticket, TicketStatus nextStatus) onTransition;
  final ValueChanged<QueueTicket> onRelease;

  @override
  Widget build(BuildContext context) {
    final ready = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.called ||
              ticket.status == TicketStatus.arrived,
        )
        .toList(growable: false);
    final seatedNow = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.seated && ticket.departedAt == null,
        )
        .toList(growable: false);
    final completed =
        tickets
            .where(
              (ticket) =>
                  (ticket.status == TicketStatus.seated &&
                      ticket.departedAt != null) ||
                  ticket.status == TicketStatus.noShow,
            )
            .toList(growable: false)
          ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'ARRIVALS',
          title: 'Check-in',
          subtitle:
              'Verify a secure arrival pass or check in a called party manually.',
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Wrap(
            spacing: 24,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const SizedBox(
                width: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftIcon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.forest,
                      background: AppColors.mint,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scan an arrival pass',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'The code is tied to the venue, ticket and current called status.',
                      style: TextStyle(color: AppColors.sage),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onScanQr,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  minimumSize: const Size(190, 54),
                ),
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: const Text('Open scanner'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awaiting arrival (${ready.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (ready.isEmpty)
                  const EmptyQueue()
                else
                  for (final ticket in ready)
                    TicketRow(
                      ticket: ticket,
                      busy: busyTickets.contains(ticket.id),
                      onTransition: (next) => onTransition(ticket, next),
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
                Text(
                  'Currently seated (${seatedNow.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (seatedNow.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No parties are currently seated.'),
                    ),
                  )
                else
                  for (final ticket in seatedNow)
                    TicketRow(
                      ticket: ticket,
                      busy: busyTickets.contains(ticket.id),
                      onTransition: (next) => onTransition(ticket, next),
                      onRelease: () => onRelease(ticket),
                    ),
              ],
            ),
          ),
        ),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent departures & outcomes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final ticket in completed.take(6))
                    TicketRow(
                      ticket: ticket,
                      busy: false,
                      onTransition: (_) {},
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
