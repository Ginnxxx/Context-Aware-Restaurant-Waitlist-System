import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/venue_context.dart';
import '../../shared/brand_widgets.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.compact,
    required this.queueOpen,
    required this.demoMode,
    required this.onQueueChanged,
    this.venues = const [],
    this.currentVenue,
    this.onVenueChanged,
  });

  final bool compact;
  final bool queueOpen;
  final bool demoMode;
  final ValueChanged<bool> onQueueChanged;
  final List<VenueContext> venues;
  final VenueContext? currentVenue;
  final ValueChanged<VenueContext>? onVenueChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (compact) ...[
        const BrandMark(compact: true),
        const SizedBox(width: 14),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  'Good evening, Host',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (venues.length > 1 && onVenueChanged != null)
                  PopupMenuButton<VenueContext>(
                    tooltip: 'Switch Branch',
                    initialValue: currentVenue,
                    onSelected: onVenueChanged,
                    itemBuilder: (context) => venues
                        .map(
                          (v) => PopupMenuItem(
                            value: v,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 18,
                                  color: v.id == currentVenue?.id
                                      ? AppColors.forest
                                      : AppColors.muted,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  v.name,
                                  style: TextStyle(
                                    fontWeight: v.id == currentVenue?.id
                                        ? FontWeight.w800
                                        : FontWeight.normal,
                                    color: v.id == currentVenue?.id
                                        ? AppColors.forest
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.forest.withValues(alpha: .3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.store_mall_directory_rounded,
                            size: 15,
                            color: AppColors.forest,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentVenue?.name ?? 'Select Branch',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              currentVenue != null
                  ? '${currentVenue!.name} • ${currentVenue!.address}'
                  : 'Here’s how tonight is moving.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      if (demoMode && !compact) ...[
        const StatusPill(
          'DEMO DATA',
          color: AppColors.amber,
          icon: Icons.science_outlined,
        ),
        const SizedBox(width: 10),
      ],
      if (!compact)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              StatusPill(
                queueOpen ? 'QUEUE OPEN' : 'QUEUE PAUSED',
                color: queueOpen ? AppColors.forest : AppColors.coral,
              ),
              Switch(value: queueOpen, onChanged: onQueueChanged),
            ],
          ),
        ),
      const SizedBox(width: 10),
      IconButton.filledTonal(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ],
  );
}
