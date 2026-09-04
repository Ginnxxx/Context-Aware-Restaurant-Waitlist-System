import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/context_snapshot.dart';
import '../../shared/brand_widgets.dart';

class ContextSimulatorSheet extends StatelessWidget {
  const ContextSimulatorSheet({
    super.key,
    required this.onSimulateFar,
    required this.onSimulateApproaching,
    required this.onSimulateNear,
    required this.onSimulateDeparture,
    this.currentBand,
  });

  final VoidCallback onSimulateFar;
  final VoidCallback onSimulateApproaching;
  final VoidCallback onSimulateNear;
  final VoidCallback onSimulateDeparture;
  final ProximityBand? currentBand;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSimulateFar,
    required VoidCallback onSimulateApproaching,
    required VoidCallback onSimulateNear,
    required VoidCallback onSimulateDeparture,
    ProximityBand? currentBand,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ContextSimulatorSheet(
      onSimulateFar: onSimulateFar,
      onSimulateApproaching: onSimulateApproaching,
      onSimulateNear: onSimulateNear,
      onSimulateDeparture: onSimulateDeparture,
      currentBand: currentBand,
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
    decoration: const BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Context Simulator',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Simulate live MUC triggers for presentation',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const StatusPill(
              'DEMO LAB',
              color: AppColors.amber,
              icon: Icons.science_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _simulatorOption(
          context,
          icon: Icons.directions_walk_rounded,
          title: 'Scenario 1: Far (> 2.5 km away)',
          subtitle: 'Simulates distance band: FAR. Calculates ETA and leave-in time.',
          active: currentBand == ProximityBand.far,
          color: AppColors.muted,
          onTap: () {
            Navigator.pop(context);
            onSimulateFar();
          },
        ),
        const SizedBox(height: 10),
        _simulatorOption(
          context,
          icon: Icons.directions_car_rounded,
          title: 'Scenario 2: Approaching (400m away)',
          subtitle: 'Inside outer geofence (800m). Recommends "Leave now".',
          active: currentBand == ProximityBand.approaching,
          color: AppColors.amber,
          onTap: () {
            Navigator.pop(context);
            onSimulateApproaching();
          },
        ),
        const SizedBox(height: 10),
        _simulatorOption(
          context,
          icon: Icons.storefront_rounded,
          title: 'Scenario 3: Arrived (50m at venue)',
          subtitle: 'Inside arrival perimeter. Triggers the ambient Arrival QR Pass banner.',
          active: currentBand == ProximityBand.near,
          color: AppColors.forest,
          onTap: () {
            Navigator.pop(context);
            onSimulateNear();
          },
        ),
        const SizedBox(height: 10),
        _simulatorOption(
          context,
          icon: Icons.sensor_door_outlined,
          title: 'Scenario 4: Physical Departure (Geofence Exit)',
          subtitle: 'Simulates walking away from venue to auto-release seated dining tables.',
          active: false,
          color: AppColors.coral,
          onTap: () {
            Navigator.pop(context);
            onSimulateDeparture();
          },
        ),
      ],
    ),
  );

  Widget _simulatorOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: .08) : const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color : AppColors.line,
          width: active ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
        ],
      ),
    ),
  );
}
