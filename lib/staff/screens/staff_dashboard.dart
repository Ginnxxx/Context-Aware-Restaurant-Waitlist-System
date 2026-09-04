import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../domain/queue_ticket.dart';
import '../../domain/venue_context.dart';
import '../widgets/qr_scanner_dialog.dart';
import '../widgets/side_navigation.dart';
import '../widgets/table_assignment_dialog.dart';
import 'checkin_page.dart';
import 'insights_page.dart';
import 'live_queue_page.dart';
import 'overview_page.dart';
import 'staff_settings_page.dart';
import '../../data/queue_repository.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key, required this.repository});

  final QueueRepository repository;

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  StaffPage _selectedPage = StaffPage.overview;
  VenueContext? venue;
  List<VenueContext> _venues = [];
  bool queueOpen = true;
  List<QueueTicket> tickets = const [];
  StreamSubscription<List<QueueTicket>>? _subscription;
  String? error;
  final Set<String> _busyTickets = <String>{};

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  void _loadVenues() {
    widget.repository.getAllVenues().then(
      (venuesList) {
        if (mounted) {
          setState(() {
            _venues = venuesList;
            if (venuesList.isNotEmpty) {
              venue = venuesList.first;
              queueOpen = venuesList.first.queueOpen;
              _subscribeTickets(venuesList.first.id);
            }
          });
        }
      },
      onError: (_) {
        widget.repository.getVenueContext().then(
          (v) {
            if (mounted) {
              setState(() {
                venue = v;
                _venues = [v];
                queueOpen = v.queueOpen;
                _subscribeTickets(v.id);
              });
            }
          },
          onError: (Object value) {
            if (mounted) setState(() => error = value.toString());
          },
        );
      },
    );
  }

  void _subscribeTickets(String venueId) {
    _subscription?.cancel();
    _subscription = widget.repository.watchVenueTickets(venueId: venueId).listen(
      (value) => mounted ? setState(() => tickets = value) : null,
      onError: (Object value) =>
          mounted ? setState(() => error = value.toString()) : null,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> callNext({bool force = false}) async {
    try {
      await widget.repository.callNextParty(venueId: venue?.id, force: force);
    } catch (exception) {
      final msg = exception.toString();
      if (!force &&
          (msg.contains('Not enough seats available') ||
              msg.contains('capacity'))) {
        if (!mounted) return;
        final override = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Capacity Warning'),
            content: Text(
              '$msg\n\nDo you want to call the party anyway (e.g. a table is paying/leaving now)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Wait for tables'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                child: const Text('Call anyway'),
              ),
            ],
          ),
        );
        if (override == true) {
          await callNext(force: true);
        }
      } else {
        if (mounted) setState(() => error = exception.toString());
      }
    }
  }

  Future<void> scanArrivalQr() async {
    final verified = await QrScannerDialog.show(
      context,
      repository: widget.repository,
    );
    if (!mounted || verified == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${verified.guestName} is checked in.'),
        backgroundColor: AppColors.forest,
      ),
    );
  }

  Future<void> transitionTicket(
    QueueTicket ticket,
    TicketStatus nextStatus,
  ) async {
    String? tableLabel;
    if (nextStatus == TicketStatus.seated) {
      tableLabel = await TableAssignmentDialog.show(context, ticket: ticket);
      if (tableLabel == null) return;
    } else if (nextStatus == TicketStatus.cancelled ||
        nextStatus == TicketStatus.noShow) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            nextStatus == TicketStatus.noShow
                ? 'Mark as no-show?'
                : 'Remove from queue?',
          ),
          content: Text(
            '${ticket.guestName} will be removed from the active queue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep ticket'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busyTickets.add(ticket.id));
    try {
      await widget.repository.transitionTicket(
        ticket.id,
        nextStatus,
        tableLabel: tableLabel,
      );
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => _busyTickets.remove(ticket.id));
    }
  }

  Future<void> releaseSeatedTicket(QueueTicket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release these seats?'),
        content: Text(
          '${ticket.guestName}’s ${ticket.partySize} seats will become available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep occupied'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark departed'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyTickets.add(ticket.id));
    try {
      await widget.repository.releaseSeatedTicket(ticket.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ticket.partySize} seats are available again.'),
          backgroundColor: AppColors.forest,
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => _busyTickets.remove(ticket.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 880;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F1),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: _selectedPage.index,
              onDestinationSelected: (index) =>
                  setState(() => _selectedPage = StaffPage.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.format_list_numbered_rounded),
                  label: 'Queue',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner_rounded),
                  label: 'Check-in',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Insights',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!compact)
            SideNavigation(
              selectedPage: _selectedPage,
              onSelected: (page) => setState(() => _selectedPage = page),
              staffName: widget.repository.isDemo ? 'Alex Tan' : 'Staff Host',
              staffRole: widget.repository.isDemo ? 'Demo Mode' : 'Manager',
              onSignOut: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text(
                      'Are you sure you want to sign out of the staff dashboard?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.repository.signOut();
                }
              },
            ),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 18 : 34,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSelectedPage(compact),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      MaterialBanner(
                        content: Text(error!),
                        actions: [
                          TextButton(
                            onPressed: () => setState(() => error = null),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage(bool compact) => switch (_selectedPage) {
    StaffPage.overview => OverviewPage(
      compact: compact,
      queueOpen: queueOpen,
      demoMode: widget.repository.isDemo,
      tickets: tickets,
      venue: venue,
      venues: _venues,
      onVenueChanged: (newVenue) {
        setState(() {
          venue = newVenue;
          queueOpen = newVenue.queueOpen;
          _subscribeTickets(newVenue.id);
        });
      },
      busyTickets: _busyTickets,
      onCallNext: callNext,
      onScanQr: scanArrivalQr,
      onTransition: transitionTicket,
      onQueueChanged: (value) async {
        try {
          await widget.repository.setQueueOpen(value, venueId: venue?.id);
          if (mounted) setState(() => queueOpen = value);
        } catch (exception) {
          if (mounted) setState(() => error = exception.toString());
        }
      },
    ),
    StaffPage.liveQueue => LiveQueuePage(
      tickets: tickets,
      busyTickets: _busyTickets,
      onCallNext: callNext,
      onScanQr: scanArrivalQr,
      onTransition: transitionTicket,
    ),
    StaffPage.checkIn => CheckInPage(
      tickets: tickets,
      busyTickets: _busyTickets,
      onScanQr: scanArrivalQr,
      onTransition: transitionTicket,
      onRelease: releaseSeatedTicket,
    ),
    StaffPage.insights => InsightsPage(tickets: tickets),
    StaffPage.settings => StaffSettingsPage(
      venue: venue,
      queueOpen: queueOpen,
      onQueueChanged: (value) async {
        await widget.repository.setQueueOpen(value, venueId: venue?.id);
        if (mounted) {
          setState(() {
            queueOpen = value;
            venue = venue?.copyWith(queueOpen: value);
          });
        }
      },
      onSave:
          ({
            required String name,
            required String address,
            required double latitude,
            required double longitude,
            required int averageTurnoverMinutes,
            required int outerGeofenceMeters,
            required int arrivalGeofenceMeters,
            required int seatCapacity,
          }) async {
            final updated = await widget.repository.updateVenueSettings(
              venueId: venue?.id,
              name: name,
              address: address,
              latitude: latitude,
              longitude: longitude,
              averageTurnoverMinutes: averageTurnoverMinutes,
              outerGeofenceMeters: outerGeofenceMeters,
              arrivalGeofenceMeters: arrivalGeofenceMeters,
              seatCapacity: seatCapacity,
            );
            if (mounted) {
              setState(() {
                venue = updated;
                final idx = _venues.indexWhere((v) => v.id == updated.id);
                if (idx >= 0) _venues[idx] = updated;
              });
            }
          },
      onCreateBranch:
          ({
            required String name,
            required String address,
            required double latitude,
            required double longitude,
            required int averageTurnoverMinutes,
            required int outerGeofenceMeters,
            required int arrivalGeofenceMeters,
            required int seatCapacity,
          }) async {
            final created = await widget.repository.createVenue(
              name: name,
              address: address,
              latitude: latitude,
              longitude: longitude,
              averageTurnoverMinutes: averageTurnoverMinutes,
              outerGeofenceMeters: outerGeofenceMeters,
              arrivalGeofenceMeters: arrivalGeofenceMeters,
              seatCapacity: seatCapacity,
            );
            if (mounted) {
              setState(() {
                _venues.add(created);
                venue = created;
                queueOpen = created.queueOpen;
                _subscribeTickets(created.id);
              });
            }
          },
    ),
  };
}
