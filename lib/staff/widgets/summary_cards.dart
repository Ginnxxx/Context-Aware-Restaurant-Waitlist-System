import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../../shared/brand_widgets.dart';

class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.tickets,
    required this.seatCapacity,
  });

  final List<QueueTicket> tickets;
  final int seatCapacity;

  @override
  Widget build(BuildContext context) {
    final waiting = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.waiting ||
              ticket.status == TicketStatus.approaching,
        )
        .length;
    final waitingTickets = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.waiting ||
              ticket.status == TicketStatus.approaching,
        )
        .toList(growable: false);
    final averageWait = waitingTickets.isEmpty
        ? 0
        : (waitingTickets.fold<int>(
                    0,
                    (sum, ticket) => sum + ticket.estimatedWaitMinutes,
                  ) /
                  waitingTickets.length)
              .round();
    final occupiedSeats = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.seated && ticket.departedAt == null,
        )
        .fold<int>(0, (sum, ticket) => sum + ticket.partySize);
    final reservedSeats = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.called ||
              ticket.status == TicketStatus.arrived,
        )
        .fold<int>(0, (sum, ticket) => sum + ticket.partySize);
    final committedSeats = occupiedSeats + reservedSeats;
    final availableSeats = (seatCapacity - committedSeats).clamp(0, 9999);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final cards = [
          SummaryCard(
            icon: Icons.groups_2_outlined,
            value: '$waiting',
            label: 'Parties waiting',
            detail: '+2 in 15 min',
            accent: AppColors.coral,
          ),
          SummaryCard(
            icon: Icons.timer_outlined,
            value: '${averageWait}m',
            label: 'Average wait',
            detail: waitingTickets.isEmpty ? 'Queue clear' : 'Live estimate',
            accent: AppColors.amber,
          ),
          SummaryCard(
            icon: Icons.table_restaurant_outlined,
            value: '$occupiedSeats/$seatCapacity',
            label: 'Seats occupied',
            detail: reservedSeats > 0
                ? '+$reservedSeats res • $availableSeats free'
                : '$availableSeats free',
            accent: const Color(0xFF6CB6A0),
          ),
        ];
        return narrow
            ? Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 10),
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 14),
                  ],
                ],
              );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SoftIcon(
            icon,
            color: accent,
            background: accent.withValues(alpha: .12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
