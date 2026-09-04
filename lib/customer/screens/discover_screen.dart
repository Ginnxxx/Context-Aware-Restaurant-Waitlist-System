import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/context_snapshot.dart';
import '../../domain/venue_context.dart';
import '../../services/context_engine.dart';
import '../../shared/brand_widgets.dart';
import '../widgets/how_tile.dart';
import '../widgets/restaurant_card.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.venue,
    required this.hasActiveTicket,
    required this.onJoin,
    this.venues = const [],
    this.selectedVenue,
    this.onSelectVenue,
    this.userLocation,
    this.onRefresh,
    this.waitingPartiesCount = 0,
  });

  final VenueContext? venue;
  final bool hasActiveTicket;
  final VoidCallback onJoin;
  final List<VenueContext> venues;
  final VenueContext? selectedVenue;
  final ValueChanged<VenueContext>? onSelectVenue;
  final DeviceLocation? userLocation;
  final Future<void> Function()? onRefresh;
  final int waitingPartiesCount;

  String? _formatDistance(VenueContext v) {
    if (userLocation == null) return null;
    final distanceMeters = ContextEngine.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      v.latitude,
      v.longitude,
    );
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m away';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
  }

  @override
  Widget build(BuildContext context) {
    final activeVenue = selectedVenue ?? venue;
    final displayVenues = venues.isNotEmpty
        ? venues
        : (venue != null ? [venue!] : <VenueContext>[]);

    final body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BrandMark(),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.white,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 38),
              const StatusPill('LIVE NEAR YOU', icon: Icons.near_me_rounded),
              const SizedBox(height: 18),
              Text(
                'Your table,\nwithout the wait.',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Join from anywhere. QueueLess watches the queue and your journey, then tells you exactly when to leave.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (displayVenues.length > 1) ...[
                const SizedBox(height: 24),
                Text(
                  'Select a branch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayVenues.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final v = displayVenues[index];
                      final selected = v.id == activeVenue?.id;
                      final distanceLabel = _formatDistance(v);

                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.name,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            if (distanceLabel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.white.withValues(alpha: 0.25)
                                      : AppColors.mint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  distanceLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppColors.white
                                        : AppColors.forest,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: selected,
                        selectedColor: AppColors.forest,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.white : AppColors.ink,
                        ),
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected ? AppColors.forest : AppColors.line,
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (val) {
                          if (val && onSelectVenue != null) {
                            onSelectVenue!(v);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 28),
              RestaurantCard(
                venue: activeVenue,
                hasActiveTicket: hasActiveTicket,
                onJoin: onJoin,
                waitingPartiesCount: waitingPartiesCount,
              ),
              const SizedBox(height: 38),
              Text(
                'How it works',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  HowTile(
                    number: '01',
                    icon: Icons.group_add_outlined,
                    label: 'Join remotely',
                  ),
                  SizedBox(width: 10),
                  HowTile(
                    number: '02',
                    icon: Icons.route_outlined,
                    label: 'Leave on time',
                  ),
                  SizedBox(width: 10),
                  HowTile(
                    number: '03',
                    icon: Icons.qr_code_2_rounded,
                    label: 'Scan & dine',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: onRefresh != null
            ? RefreshIndicator(
                onRefresh: onRefresh!,
                child: body,
              )
            : body,
      ),
    );
  }
}
