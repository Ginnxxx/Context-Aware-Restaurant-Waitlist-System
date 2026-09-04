import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/venue_context.dart';
import 'dark_metric.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.venue,
    required this.hasActiveTicket,
    required this.onJoin,
    this.waitingPartiesCount = 0,
  });

  final VenueContext? venue;
  final bool hasActiveTicket;
  final VoidCallback onJoin;
  final int waitingPartiesCount;

  @override
  Widget build(BuildContext context) {
    final turnover = venue?.averageTurnoverMinutes ?? 5;
    final estimatedWait = waitingPartiesCount == 0
        ? '< 5 min'
        : '~${waitingPartiesCount * turnover} min';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24173F35),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.ramen_dining_rounded,
                  size: 38,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue?.name ?? 'Loading venue…',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      venue?.address.isNotEmpty == true
                          ? venue!.address
                          : 'Context-aware queue venue',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_outward_rounded, color: AppColors.sage),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DarkMetric(
                value: venue == null ? '—' : estimatedWait,
                label: 'est. wait time',
              ),
              Container(
                width: 1,
                height: 42,
                color: AppColors.white.withValues(alpha: .16),
              ),
              DarkMetric(
                value: venue == null ? '—' : '$waitingPartiesCount',
                label: 'in queue',
              ),
              Container(
                width: 1,
                height: 42,
                color: AppColors.white.withValues(alpha: .16),
              ),
              DarkMetric(
                value: venue == null
                    ? '—'
                    : venue!.queueOpen
                        ? 'Open'
                        : 'Paused',
                label: 'status',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasActiveTicket || venue == null || venue!.queueOpen
                  ? onJoin
                  : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                hasActiveTicket
                    ? 'View my active ticket'
                    : venue?.queueOpen == false
                        ? 'Queue is paused'
                        : 'Join the queue',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
