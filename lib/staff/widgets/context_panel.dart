import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import 'guest_dot.dart';

class ContextPanel extends StatelessWidget {
  const ContextPanel({super.key, required this.tickets});

  final List<QueueTicket> tickets;

  @override
  Widget build(BuildContext context) {
    final approaching = tickets
        .where((ticket) => ticket.status == TicketStatus.approaching)
        .toList(growable: false);
    final approachingGuests = approaching.fold<int>(
      0,
      (sum, ticket) => sum + ticket.partySize,
    );
    final arrivedGuests = tickets
        .where((ticket) => ticket.status == TicketStatus.arrived)
        .fold<int>(0, (sum, ticket) => sum + ticket.partySize);
    final seated = tickets
        .where((ticket) => ticket.status == TicketStatus.seated)
        .length;
    final noShows = tickets
        .where((ticket) => ticket.status == TicketStatus.noShow)
        .length;
    final completed = seated + noShows;
    final serviceRate = completed == 0 ? 1.0 : seated / completed;
    final servicePercent = (serviceRate * 100).round();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Arrival context',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.radar_rounded, color: AppColors.sage),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF285348),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.sage.withValues(alpha: .18),
                          width: 20,
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.coral.withValues(alpha: .32),
                          width: 15,
                        ),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.coral,
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.white,
                        size: 17,
                      ),
                    ),
                    const Positioned(
                      left: 43,
                      top: 48,
                      child: GuestDot(label: 'N', color: AppColors.amber),
                    ),
                    const Positioned(
                      right: 35,
                      bottom: 38,
                      child: GuestDot(label: 'M', color: AppColors.sage),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    color: AppColors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      approachingGuests == 0
                          ? 'No guests currently approaching'
                          : '$approachingGuests guest${approachingGuests == 1 ? '' : 's'} approaching',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Based on consented geofence events',
                style: TextStyle(
                  color: AppColors.sage.withValues(alpha: .75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service pace',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Show rate',
                      style: TextStyle(
                        color: Color(0xFF267B67),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$servicePercent%',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: serviceRate,
                    minHeight: 8,
                    backgroundColor: AppColors.mint,
                    color: const Color(0xFF6CB6A0),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  arrivedGuests == 0
                      ? 'No parties are waiting at the host stand.'
                      : '$arrivedGuests guest${arrivedGuests == 1 ? '' : 's'} checked in and ready to seat.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
