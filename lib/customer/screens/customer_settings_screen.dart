import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/venue_context.dart';
import '../widgets/context_simulator_sheet.dart';
import '../widgets/customer_page_header.dart';
import '../widgets/preference_tile.dart';

class CustomerSettingsScreen extends StatelessWidget {
  const CustomerSettingsScreen({
    super.key,
    required this.venue,
    required this.locationActive,
    required this.backgroundSupported,
    required this.backgroundActive,
    required this.alertsSupported,
    required this.alertsActive,
    required this.onOpenAppSettings,
    required this.onEnableAlerts,
    this.onSimulateFar,
    this.onSimulateApproaching,
    this.onSimulateNear,
    this.onSimulateDeparture,
  });

  final VenueContext? venue;
  final bool locationActive;
  final bool backgroundSupported;
  final bool backgroundActive;
  final bool alertsSupported;
  final bool alertsActive;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onEnableAlerts;
  final VoidCallback? onSimulateFar;
  final VoidCallback? onSimulateApproaching;
  final VoidCallback? onSimulateNear;
  final VoidCallback? onSimulateDeparture;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
        children: [
          const CustomerPageHeader(
            eyebrow: 'PREFERENCES',
            title: 'Settings & help',
            subtitle:
                'Understand and control the permissions used by QueueLess.',
          ),
          const SizedBox(height: 24),
          if (onSimulateFar != null) ...[
            InkWell(
              onTap: () => ContextSimulatorSheet.show(
                context,
                onSimulateFar: onSimulateFar!,
                onSimulateApproaching: onSimulateApproaching!,
                onSimulateNear: onSimulateNear!,
                onSimulateDeparture: onSimulateDeparture!,
              ),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF143026), Color(0xFF1F4839)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: .2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.amber,
                      radius: 20,
                      child: Icon(
                        Icons.science_rounded,
                        color: AppColors.ink,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MUC Context Simulator',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Simulate proximity, arrival & auto-departure',
                            style: TextStyle(
                              color: AppColors.sage,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.sage,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Card(
            child: Column(
              children: [
                PreferenceTile(
                  icon: Icons.location_on_outlined,
                  title: 'Smart location',
                  subtitle: locationActive
                      ? 'Active for your current ticket'
                      : 'Off until you enable it on a ticket',
                  status: locationActive ? 'Active' : 'Optional',
                  onTap: onOpenAppSettings,
                ),
                const Divider(height: 1),
                PreferenceTile(
                  icon: Icons.radar_rounded,
                  title: 'Background arrival',
                  subtitle: !backgroundSupported
                      ? 'Available on supported Android devices'
                      : backgroundActive
                      ? 'Geofences are registered for your ticket'
                      : 'Requires “Allow all the time” location access',
                  status: backgroundActive ? 'Active' : 'Optional',
                  onTap: onOpenAppSettings,
                ),
                const Divider(height: 1),
                PreferenceTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Table-ready notifications',
                  subtitle: alertsSupported
                      ? 'Receive an alert when staff calls your party'
                      : 'Push notifications are unavailable on this device',
                  status: alertsActive ? 'Active' : 'Enable',
                  onTap: alertsActive || !alertsSupported
                      ? onOpenAppSettings
                      : onEnableAlerts,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Card(
            child: Column(
              children: [
                ExpansionTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Privacy by design'),
                  childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      'QueueLess calculates distance on your phone. It records meaningful context events—such as entering the approach boundary—instead of continuously storing your raw location.',
                    ),
                  ],
                ),
                Divider(height: 1),
                ExpansionTile(
                  leading: Icon(Icons.help_outline_rounded),
                  title: Text('How arrival works'),
                  childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      'Join the queue, enable the permissions you want, and wait for your table-ready alert. When called, show your secure QR pass to staff for check-in.',
                    ),
                  ],
                ),
                Divider(height: 1),
                ExpansionTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('About QueueLess'),
                  childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      'A Flutter mobile and ubiquitous computing project using contextual location, geofencing, realtime queues and secure arrival verification.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (venue != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${venue!.name}\n${venue!.address}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
