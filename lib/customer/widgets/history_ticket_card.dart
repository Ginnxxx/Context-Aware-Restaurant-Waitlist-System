import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../../shared/brand_widgets.dart';

class HistoryTicketCard extends StatelessWidget {
  const HistoryTicketCard({super.key, required this.ticket});

  final QueueTicket ticket;

  @override
  Widget build(BuildContext context) {
    final date = ticket.joinedAt.toLocal();
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final successful = ticket.status == TicketStatus.seated;
    final tableText = ticket.tableLabel != null ? ' • ${ticket.tableLabel}' : '';
    final autoText = ticket.isAutoDeparted ? ' • Auto-released' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SoftIcon(
              successful
                  ? Icons.restaurant_rounded
                  : ticket.status == TicketStatus.noShow
                  ? Icons.person_off_outlined
                  : Icons.close_rounded,
              color: successful ? AppColors.forest : AppColors.coral,
              background: successful ? AppColors.mint : const Color(0xFFFFECE8),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.guestName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formatted • ${ticket.partySize} guests$tableText$autoText',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusPill(
              successful ? 'Visited' : ticket.status.label,
              color: successful ? AppColors.forest : AppColors.coral,
              icon: ticket.isAutoDeparted ? Icons.auto_awesome_rounded : null,
            ),
          ],
        ),
      ),
    );
  }
}
