import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../widgets/insight_widgets.dart';
import '../widgets/page_intro.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.tickets});

  final List<QueueTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = tickets
        .where((ticket) {
          final joined = ticket.joinedAt.toLocal();
          return joined.year == now.year &&
              joined.month == now.month &&
              joined.day == now.day;
        })
        .toList(growable: false);
    final active = today
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
    final seated = today
        .where((ticket) => ticket.status == TicketStatus.seated)
        .length;
    final noShows = today
        .where((ticket) => ticket.status == TicketStatus.noShow)
        .length;
    final completed = seated + noShows;
    final showRate = completed == 0 ? 100 : (seated / completed * 100).round();
    final guests = today.fold<int>(0, (sum, item) => sum + item.partySize);
    final waiting = active
        .where(
          (ticket) =>
              ticket.status == TicketStatus.waiting ||
              ticket.status == TicketStatus.approaching,
        )
        .toList(growable: false);
    final averageWait = waiting.isEmpty
        ? 0
        : (waiting.fold<int>(
                    0,
                    (sum, ticket) => sum + ticket.estimatedWaitMinutes,
                  ) /
                  waiting.length)
              .round();
    final statusCounts = {
      for (final status in TicketStatus.values)
        status: today.where((ticket) => ticket.status == status).length,
    };
    final maxStatus = statusCounts.values.fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'TODAY',
          title: 'Insights',
          subtitle:
              'A live operational view calculated from today’s queue activity.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 760
                ? constraints.maxWidth
                : (constraints.maxWidth - 42) / 4;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                InsightMetric(
                  width: width,
                  icon: Icons.confirmation_number_outlined,
                  value: '${today.length}',
                  label: 'Parties joined',
                  detail: '$guests guests',
                  color: AppColors.coral,
                ),
                InsightMetric(
                  width: width,
                  icon: Icons.timer_outlined,
                  value: '${averageWait}m',
                  label: 'Current average wait',
                  detail: '${waiting.length} waiting',
                  color: AppColors.amber,
                ),
                InsightMetric(
                  width: width,
                  icon: Icons.table_restaurant_outlined,
                  value: '$seated',
                  label: 'Parties seated',
                  detail: '$completed outcomes',
                  color: const Color(0xFF6CB6A0),
                ),
                InsightMetric(
                  width: width,
                  icon: Icons.verified_outlined,
                  value: '$showRate%',
                  label: 'Show rate',
                  detail: '$noShows no-show',
                  color: AppColors.forest,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 820;
            final statusCard = InsightCard(
              title: 'Queue outcomes',
              subtitle: 'Distribution of today’s ticket states',
              child: Column(
                children: [
                  for (final status in TicketStatus.values)
                    InsightBar(
                      label: status.label,
                      value: statusCounts[status]!,
                      fraction: statusCounts[status]! / maxStatus,
                    ),
                ],
              ),
            );
            final paceCard = InsightCard(
              title: 'Service pulse',
              subtitle: 'What staff should focus on right now',
              child: Column(
                children: [
                  PulseRow(
                    icon: Icons.groups_2_outlined,
                    label: 'Active parties',
                    value: '${active.length}',
                  ),
                  PulseRow(
                    icon: Icons.near_me_outlined,
                    label: 'Approaching',
                    value:
                        '${active.where((ticket) => ticket.status == TicketStatus.approaching).length}',
                  ),
                  PulseRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Awaiting check-in',
                    value:
                        '${active.where((ticket) => ticket.status == TicketStatus.called).length}',
                  ),
                  PulseRow(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Arrived',
                    value:
                        '${active.where((ticket) => ticket.status == TicketStatus.arrived).length}',
                  ),
                ],
              ),
            );
            if (narrow) {
              return Column(
                children: [statusCard, const SizedBox(height: 18), paceCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statusCard),
                const SizedBox(width: 18),
                Expanded(child: paceCard),
              ],
            );
          },
        ),
      ],
    );
  }
}
