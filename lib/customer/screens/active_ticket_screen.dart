import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/context_snapshot.dart';
import '../../domain/queue_ticket.dart';
import '../../domain/venue_context.dart';
import '../../shared/brand_widgets.dart';
import '../widgets/arrival_proximity_banner.dart';
import '../widgets/geofence_map_card.dart';

class ActiveTicketScreen extends StatelessWidget {
  const ActiveTicketScreen({
    super.key,
    required this.ticket,
    required this.demoMode,
    required this.contextSnapshot,
    required this.locationBusy,
    required this.locationError,
    required this.backgroundSupported,
    required this.backgroundContextActive,
    required this.backgroundContextBusy,
    required this.backgroundContextError,
    required this.alertsSupported,
    required this.alertsActive,
    required this.alertsBusy,
    required this.alertsError,
    required this.onEnableLocation,
    required this.onEnableBackgroundContext,
    required this.onEnableAlerts,
    required this.onOpenLocationSettings,
    required this.onShowQr,
    required this.onLeave,
    this.onReportDelay,
    this.delayBusy = false,
    this.venueName = 'UIT',
    this.venue,
    this.customerLocation,
    this.onRouteCalculated,
    this.onSimulate,
  });

  final QueueTicket ticket;
  final bool demoMode;
  final ContextSnapshot? contextSnapshot;
  final bool locationBusy;
  final String? locationError;
  final bool backgroundSupported;
  final bool backgroundContextActive;
  final bool backgroundContextBusy;
  final String? backgroundContextError;
  final bool alertsSupported;
  final bool alertsActive;
  final bool alertsBusy;
  final String? alertsError;
  final VoidCallback onEnableLocation;
  final VoidCallback onEnableBackgroundContext;
  final VoidCallback onEnableAlerts;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onShowQr;
  final VoidCallback onLeave;
  final VoidCallback? onReportDelay;
  final bool delayBusy;
  final String venueName;
  final VenueContext? venue;
  final DeviceLocation? customerLocation;
  final void Function(double roadDistanceMeters, int roadTravelMinutes)?
      onRouteCalculated;
  final VoidCallback? onSimulate;

  String get _shortTicketId {
    final raw = ticket.id;
    if (raw.length <= 8) return raw;
    final parts = raw.split('-');
    return '#${parts.first.toUpperCase()}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String get _guidance {
    final snapshot = contextSnapshot;
    if (snapshot == null) {
      return 'Enable location to calculate the best time to leave.';
    }
    if (snapshot.proximity == ProximityBand.near) {
      return 'You are at the venue. Show your arrival QR when called.';
    }
    if (snapshot.shouldLeaveNow) {
      return 'Leave now. Your trip is about ${snapshot.estimatedTravelMinutes} min.';
    }
    final leaveIn =
        snapshot.estimatedWaitMinutes -
        snapshot.estimatedTravelMinutes -
        snapshot.safetyBufferMinutes;
    return 'You are ${snapshot.estimatedTravelMinutes} min away. We will alert you in about ${leaveIn.clamp(1, 999)} min.';
  }

  String get _proximityLabel => switch (contextSnapshot?.proximity) {
    ProximityBand.near => 'Near',
    ProximityBand.approaching => 'Approaching',
    ProximityBand.far => 'Far',
    null => 'Off',
  };

  @override
  Widget build(BuildContext context) {
    final isSeated = ticket.status == TicketStatus.seated;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const BrandMark(),
                      if (onSimulate != null)
                        IconButton(
                          tooltip: 'Context Simulator (MUC)',
                          onPressed: onSimulate,
                          icon: const Icon(
                            Icons.science_outlined,
                            color: AppColors.forest,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  if (contextSnapshot?.proximity == ProximityBand.near &&
                      ticket.status != TicketStatus.arrived &&
                      !isSeated)
                    ArrivalProximityBanner(
                      venueName: venueName,
                      onShowQr: onShowQr,
                    ),
                  if (isSeated)
                    _buildSeatedHeader(context)
                  else
                    _buildQueueHeader(context),
                  const SizedBox(height: 24),
                  if (isSeated)
                    _buildSeatedCard(context)
                  else
                    _buildQueueCard(context),
                  const SizedBox(height: 18),
                  if (!isSeated) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SoftIcon(
                                  Icons.near_me_outlined,
                                  color: AppColors.coral,
                                  background: Color(0xFFFFECE8),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Context engine',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Live location and departure recommendation',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  _proximityLabel,
                                  color:
                                      contextSnapshot?.proximity ==
                                          ProximityBand.near
                                      ? AppColors.forest
                                      : AppColors.amber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAF7),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: AppColors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _guidance,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (contextSnapshot != null) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          'Distance: ${_formatDistance(contextSnapshot!.distanceMeters)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        Text(
                                          'Travel time: ${contextSnapshot!.estimatedTravelMinutes} min',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        Text(
                                          'Safety buffer: ${contextSnapshot!.safetyBufferMinutes} min',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (venue != null) ...[
                      GeofenceMapCard(
                        venue: venue!,
                        customerLocation: customerLocation,
                        contextSnapshot: contextSnapshot,
                        onRouteCalculated: onRouteCalculated,
                        onShowQr: onShowQr,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  if (isSeated)
                    _buildAutoDepartureInfoCard(context)
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const SoftIcon(
                              Icons.location_on_outlined,
                              color: AppColors.forest,
                              background: AppColors.mint,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Live location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locationError ??
                                        (contextSnapshot == null
                                            ? 'Off'
                                            : 'Continuous updates active'),
                                    style: TextStyle(
                                      color: locationError == null
                                          ? AppColors.muted
                                          : AppColors.coral,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (locationBusy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (locationError != null)
                              IconButton(
                                tooltip: 'Open app settings',
                                onPressed: onOpenLocationSettings,
                                icon: const Icon(Icons.settings_outlined),
                              )
                            else
                              Switch(
                                value: contextSnapshot != null,
                                onChanged: contextSnapshot != null
                                    ? null
                                    : (_) => onEnableLocation(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const SoftIcon(
                              Icons.radar_rounded,
                              color: AppColors.forest,
                              background: AppColors.mint,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Background arrival',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    !backgroundSupported
                                        ? 'Platform unsupported'
                                        : backgroundContextError ??
                                            (backgroundContextActive
                                                ? 'Active geofences registered'
                                                : 'Requires Always-allow location'),
                                    style: TextStyle(
                                      color: backgroundContextError == null
                                          ? AppColors.muted
                                          : AppColors.coral,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (backgroundContextBusy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (backgroundContextError != null)
                              IconButton(
                                tooltip: 'Open app settings',
                                onPressed: onOpenLocationSettings,
                                icon: const Icon(Icons.settings_outlined),
                              )
                            else if (backgroundSupported)
                              Switch(
                                value: backgroundContextActive,
                                onChanged: backgroundContextActive
                                    ? null
                                    : (_) => onEnableBackgroundContext(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const SoftIcon(
                              Icons.notifications_none_rounded,
                              color: AppColors.forest,
                              background: AppColors.mint,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Push notifications',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    !alertsSupported
                                        ? 'Platform unsupported'
                                        : alertsError ??
                                            (alertsActive
                                                ? 'Device token registered'
                                                : 'Get alerted when table is ready'),
                                    style: TextStyle(
                                      color: alertsError == null
                                          ? AppColors.muted
                                          : AppColors.coral,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (alertsBusy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              Switch(
                                value: alertsActive,
                                onChanged: (!alertsSupported || alertsActive)
                                    ? null
                                    : (_) => onEnableAlerts(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (ticket.status == TicketStatus.called) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFFFFF8E1),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: AppColors.amber,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Running late?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (ticket.hasDelay)
                                  StatusPill(
                                    '+${ticket.delayMinutes}m delay added',
                                    color: AppColors.amber,
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket.hasDelay
                                  ? 'Host has been notified of your delay. Your arrival window is extended.'
                                  : 'Need extra time? Request a 5-minute grace period to prevent your table from being given away.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (ticket.delayMinutes < 10 && onReportDelay != null) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: delayBusy ? null : onReportDelay,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.amber),
                                    foregroundColor: const Color(0xFF78350F),
                                  ),
                                  icon: delayBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add_alarm_rounded),
                                  label: Text(
                                    ticket.delayMinutes == 0
                                        ? 'Running late (+5 min grace)'
                                        : 'Need 5 min more (+10m max)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (ticket.status == TicketStatus.called ||
                      ticket.status == TicketStatus.arrived) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onShowQr,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          backgroundColor: AppColors.forest,
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: Text(
                          ticket.status == TicketStatus.arrived
                              ? 'Arrival verified'
                              : 'Show arrival QR',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onLeave,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        foregroundColor: AppColors.coral,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: Text(
                        isSeated
                            ? 'Finished dining & leave early'
                            : 'Leave queue',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StatusPill(
        demoMode ? 'DEMO • YOU’RE IN THE QUEUE' : 'YOU’RE IN THE QUEUE',
        icon: Icons.check_circle_rounded,
      ),
      const SizedBox(height: 15),
      Text(
        'Go enjoy your time.\nWe’ll watch your place.',
        style: Theme.of(context).textTheme.displaySmall,
      ),
    ],
  );

  Widget _buildSeatedHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const StatusPill(
        'YOU’RE SEATED • ENJOY YOUR MEAL',
        color: AppColors.forest,
        icon: Icons.restaurant_rounded,
      ),
      const SizedBox(height: 15),
      Text(
        'Welcome to your table.\nRelax & enjoy dining.',
        style: Theme.of(context).textTheme.displaySmall,
      ),
    ],
  );

  Widget _buildQueueCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR POSITION',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '#${ticket.position}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 58,
                    height: .95,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coral, width: 8),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${ticket.estimatedWaitMinutes}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'MIN',
                    style: TextStyle(
                      color: AppColors.sage,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _metric('Party', '${ticket.partySize} guests', flex: 3),
              const SizedBox(width: 8),
              _metric('Ticket', _shortTicketId, flex: 3),
              const SizedBox(width: 8),
              _metric('Status', ticket.status.label, flex: 3, align: TextAlign.end),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSeatedCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: AppColors.forest,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASSIGNED LOCATION',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  ticket.tableLabel ?? 'Table Seated',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.amber,
              child: Icon(
                Icons.restaurant_rounded,
                color: AppColors.ink,
                size: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _metric('Party', '${ticket.partySize} guests', flex: 3),
              const SizedBox(width: 8),
              _metric('Guest', ticket.guestName, flex: 3),
              const SizedBox(width: 8),
              _metric('Pass', _shortTicketId, flex: 3, align: TextAlign.end),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildAutoDepartureInfoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SoftIcon(
                Icons.sensors_rounded,
                color: AppColors.forest,
                background: AppColors.mint,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autonomous Departure',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero-effort table release via spatial context',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const StatusPill(
                'SENSING',
                color: AppColors.forest,
                icon: Icons.check_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.coral,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'When you leave the venue, your device will automatically detect your departure and free your seats for the next guests. No action required!',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _metric(
    String label,
    String value, {
    int flex = 1,
    TextAlign align = TextAlign.start,
  }) => Expanded(
    flex: flex,
    child: Column(
      crossAxisAlignment: align == TextAlign.end
          ? CrossAxisAlignment.end
          : align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.sage, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
