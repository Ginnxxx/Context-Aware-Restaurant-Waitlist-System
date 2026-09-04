import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../../shared/brand_widgets.dart';
import 'ticket_actions.dart';

class TicketRow extends StatelessWidget {
  const TicketRow({
    super.key,
    required this.ticket,
    required this.busy,
    required this.onTransition,
    this.onRelease,
  });

  final QueueTicket ticket;
  final bool busy;
  final ValueChanged<TicketStatus> onTransition;
  final VoidCallback? onRelease;

  String _shortId(String id) {
    if (id.length <= 8) return id;
    final parts = id.split('-');
    return '#${parts.first.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final called = ticket.status == TicketStatus.called;
    final approaching = ticket.status == TicketStatus.approaching;
    final arrived = ticket.status == TicketStatus.arrived;
    final seated = ticket.status == TicketStatus.seated && ticket.departedAt == null;
    final departed = ticket.departedAt != null;
    final actions = actionsForStatus(ticket.status);
    final statusColor = called
        ? AppColors.coral
        : seated
        ? AppColors.forest
        : approaching || arrived
        ? const Color(0xFF267B67)
        : AppColors.muted;

    final statusText = departed
        ? (ticket.isAutoDeparted ? 'Auto-departed (Geofence)' : 'Departed')
        : ticket.status.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: called ? const Color(0xFFFFF1ED) : const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: called ? AppColors.coral : AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              called
                  ? '✓'
                  : seated
                  ? '🍽️'
                  : '${ticket.position}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: called ? AppColors.white : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ticket.guestName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (ticket.tableLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.tableLabel!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                    if (ticket.hasDelay) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          border: Border.all(
                            color: AppColors.amber,
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${ticket.delayMinutes}m delay',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(_shortId(ticket.id), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${ticket.partySize} guests',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 600)
            Expanded(
              child: Text(
                called
                    ? (ticket.hasDelay ? '+${ticket.delayMinutes}m delay' : 'Now')
                    : seated
                    ? 'Dining'
                    : '~${ticket.estimatedWaitMinutes} min',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (called && ticket.hasDelay) ? const Color(0xFFB45309) : null,
                ),
              ),
            ),
          StatusPill(
            statusText,
            color: statusColor,
            icon: approaching
                ? Icons.near_me_rounded
                : seated
                ? Icons.sensors_rounded
                : (ticket.isAutoDeparted ? Icons.auto_awesome_rounded : null),
          ),
          const SizedBox(width: 3),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onRelease != null)
            IconButton(
              tooltip: 'Manual departure override',
              onPressed: onRelease,
              icon: const Icon(Icons.chair_alt_outlined, size: 20),
            )
          else if (actions.isNotEmpty)
            PopupMenuButton<TicketStatus>(
              tooltip: 'Ticket actions',
              onSelected: onTransition,
              itemBuilder: (context) => actions
                  .map(
                    (action) => PopupMenuItem(
                      value: action.status,
                      child: Row(
                        children: [
                          Icon(action.icon, size: 19, color: action.color),
                          const SizedBox(width: 10),
                          Text(action.label),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              icon: const Icon(Icons.more_horiz_rounded, size: 19),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}
