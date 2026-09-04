import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/demo_queue_repository.dart';
import '../data/queue_repository.dart';
import '../domain/context_snapshot.dart';
import '../domain/queue_ticket.dart';
import '../domain/venue_context.dart';
import '../services/background_geofence_service.dart';
import '../services/context_engine.dart';
import '../services/location_service.dart';
import '../services/push_notification_service.dart';
import 'screens/active_ticket_screen.dart';
import 'screens/customer_settings_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/history_screen.dart';
import 'screens/join_queue_screen.dart';
import 'screens/no_active_ticket_screen.dart';
import 'widgets/qr_pass_dialog.dart';

export 'screens/active_ticket_screen.dart';
export 'screens/customer_settings_screen.dart';
export 'screens/discover_screen.dart';
export 'screens/history_screen.dart';
export 'screens/join_queue_screen.dart';
export 'screens/no_active_ticket_screen.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({
    super.key,
    this.repository,
    this.locationService,
    this.backgroundGeofenceService,
    this.pushNotificationService,
  });

  final QueueRepository? repository;
  final LocationService? locationService;
  final BackgroundGeofenceService? backgroundGeofenceService;
  final PushNotificationService? pushNotificationService;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QueueLess',
    debugShowCheckedModeBanner: false,
    theme: QueueLessTheme.light,
    home: CustomerFlow(
      repository: repository ?? DemoQueueRepository(),
      locationService: locationService ?? GeolocatorLocationService(),
      backgroundGeofenceService:
          backgroundGeofenceService ?? BackgroundGeofenceService(),
      pushNotificationService:
          pushNotificationService ?? PushNotificationService(),
    ),
  );
}

enum CustomerStep { discover, join, ticket }

enum CustomerTab { home, ticket, history, settings }

class CustomerFlow extends StatefulWidget {
  const CustomerFlow({
    super.key,
    required this.repository,
    required this.locationService,
    required this.backgroundGeofenceService,
    required this.pushNotificationService,
  });

  final QueueRepository repository;
  final LocationService locationService;
  final BackgroundGeofenceService backgroundGeofenceService;
  final PushNotificationService pushNotificationService;

  @override
  State<CustomerFlow> createState() => _CustomerFlowState();
}

class _CustomerFlowState extends State<CustomerFlow> {
  CustomerStep step = CustomerStep.discover;
  CustomerTab selectedTab = CustomerTab.home;
  int historyRevision = 0;
  int partySize = 2;
  String guestName = '';
  QueueTicket? ticket;
  bool busy = false;
  String? error;
  StreamSubscription<QueueTicket?>? _ticketSubscription;
  StreamSubscription<List<QueueTicket>>? _venueTicketsSubscription;
  Timer? _ticketPollTimer;
  StreamSubscription<DeviceLocation>? _locationSubscription;
  StreamSubscription<PushNotice>? _noticeSubscription;
  final _contextEngine = const ContextEngine();
  VenueContext? _venue;
  List<VenueContext> _venues = [];
  int _venueWaitingCount = 0;
  DeviceLocation? _lastLocation;
  ContextSnapshot? contextSnapshot;
  double? _roadDistance;
  int? _roadTravelMinutes;
  bool locationBusy = false;
  String? locationError;
  bool backgroundContextActive = false;
  bool backgroundContextBusy = false;
  String? backgroundContextError;
  ProximityBand? _lastReportedBand;
  bool _leaveNowReported = false;
  bool alertsActive = false;
  bool alertsBusy = false;
  String? alertsError;
  bool delayBusy = false;

  @override
  void initState() {
    super.initState();
    _initCustomerApp();
  }

  void _subscribeVenueTickets() {
    _venueTicketsSubscription?.cancel();
    _venueTicketsSubscription = widget.repository
        .watchVenueTickets(venueId: _venue?.id)
        .listen((tickets) {
      if (!mounted) return;
      final waiting = tickets.where((t) =>
          t.status == TicketStatus.waiting ||
          t.status == TicketStatus.called ||
          t.status == TicketStatus.approaching);
      setState(() => _venueWaitingCount = waiting.length);
    });
  }

  Future<void> _initCustomerApp() async {
    try {
      await widget.repository.ensureCustomerSession();
      final venuesList = await widget.repository.getAllVenues();
      if (mounted) {
        setState(() {
          _venues = venuesList;
          if (_venue == null && venuesList.isNotEmpty) {
            _venue = venuesList.first;
          }
        });
      }
    } catch (_) {
      try {
        final single = await widget.repository.getVenueContext();
        if (mounted) {
          setState(() {
            _venue = single;
            _venues = [single];
          });
        }
      } catch (err) {
        if (mounted) setState(() => error = err.toString());
      }
    }

    if (!mounted) return;
    _subscribeVenueTickets();

    if (widget.pushNotificationService.isSupported) {
      _noticeSubscription = widget.pushNotificationService.notices.listen((
        notice,
      ) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${notice.title}: ${notice.body}'),
            backgroundColor: AppColors.forest,
          ),
        );
      });
      _restorePushRegistration();
    }

    _ticketSubscription = widget.repository.watchMyActiveTicket().listen(
      (value) {
        if (!mounted) return;
        final ticketChanged = ticket?.id != value?.id;
        final becameHistorical = ticket != null && value == null;
        setState(() {
          ticket = value;
          if (becameHistorical) historyRevision++;
          if (value != null) {
            step = CustomerStep.ticket;
            if (ticketChanged) selectedTab = CustomerTab.ticket;
          } else if (becameHistorical) {
            step = CustomerStep.discover;
            if (selectedTab == CustomerTab.ticket) {
              selectedTab = CustomerTab.home;
            }
          }
          if (value != null && value.venueId != null && _venue?.id != value.venueId) {
            for (final v in _venues) {
              if (v.id == value.venueId) {
                _venue = v;
                break;
              }
            }
          }
          if (ticketChanged) {
            _lastReportedBand = null;
            _leaveNowReported = false;
            backgroundContextActive = false;
          }
          _refreshContext();
        });
        if (value != null) _refreshBackgroundRegistration(value.id);
        if (value == null) {
          _locationSubscription?.cancel();
          _locationSubscription = null;
        }
      },
      onError: (Object value) {
        if (mounted) setState(() => error = value.toString());
      },
    );
  }

  /// Android may remember notification permission from an earlier launch.
  /// In that case the switch is already shown as active, but the FCM token
  /// still needs to be registered with Supabase after reinstall/session reset.
  Future<void> _restorePushRegistration() async {
    try {
      final authorized = await widget.pushNotificationService.isAuthorized();
      if (!authorized) return;
      await widget.pushNotificationService.enable(widget.repository);
      if (mounted) setState(() => alertsActive = true);
    } catch (exception) {
      if (mounted) setState(() => alertsError = exception.toString());
    }
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _venueTicketsSubscription?.cancel();
    _ticketPollTimer?.cancel();
    _locationSubscription?.cancel();
    _noticeSubscription?.cancel();
    widget.pushNotificationService.dispose();
    super.dispose();
  }

  void _refreshContext() {
    final activeTicket = ticket;
    final venue = _venue;
    final location = _lastLocation;
    if (activeTicket == null || venue == null || location == null) return;
    contextSnapshot = _contextEngine.evaluate(
      location: location,
      venue: venue,
      estimatedWaitMinutes: activeTicket.estimatedWaitMinutes,
      overrideDistanceMeters: _roadDistance,
      overrideTravelMinutes: _roadTravelMinutes,
    );
  }

  Future<void> _refreshVenues() async {
    try {
      final venuesList = await widget.repository.getAllVenues();
      if (mounted && venuesList.isNotEmpty) {
        setState(() {
          _venues = venuesList;
          if (_venue == null || !_venues.any((v) => v.id == _venue!.id)) {
            _venue = venuesList.first;
          }
          _refreshContext();
        });
        _subscribeVenueTickets();
      }
    } catch (_) {}
  }

  Future<void> _refreshBackgroundRegistration(String ticketId) async {
    try {
      final active = await widget.backgroundGeofenceService.isRegistered(
        ticketId,
      );
      if (mounted && ticket?.id == ticketId) {
        setState(() => backgroundContextActive = active);
      }
    } catch (_) {
      // Registration status is optional; foreground location remains available.
    }
  }

  Future<void> _reportContextSnapshot(ContextSnapshot snapshot) async {
    final activeTicket = ticket;
    if (activeTicket == null) return;
    final previous = _lastReportedBand;
    _lastReportedBand = snapshot.proximity;

    String? eventType;
    if (snapshot.proximity == ProximityBand.near &&
        previous != ProximityBand.near) {
      eventType = 'arrival_geofence_entered';
    } else if (snapshot.proximity == ProximityBand.approaching &&
        previous != ProximityBand.approaching) {
      eventType = 'outer_geofence_entered';
    } else if (snapshot.proximity == ProximityBand.far &&
        previous != null &&
        previous != ProximityBand.far) {
      eventType = 'outer_geofence_exited';
    }

    try {
      if (eventType != null) {
        await widget.repository.recordContextEvent(
          ticketId: activeTicket.id,
          eventType: eventType,
          distanceBand: snapshot.proximity.name,
        );
      }
      if (snapshot.shouldLeaveNow && !_leaveNowReported) {
        _leaveNowReported = true;
        await widget.repository.recordContextEvent(
          ticketId: activeTicket.id,
          eventType: 'leave_now_recommended',
          distanceBand: snapshot.proximity.name,
        );
      }
    } catch (exception) {
      if (mounted) setState(() => locationError = exception.toString());
    }
  }

  Future<void> enableLocationContext() async {
    setState(() {
      locationBusy = true;
      locationError = null;
    });
    try {
      _venue ??= await widget.repository.getVenueContext();
      await widget.locationService.ensurePermission();
      await _locationSubscription?.cancel();
      _locationSubscription = widget.locationService.watchPositions().listen(
        (location) {
          if (!mounted) return;
          setState(() {
            _lastLocation = location;
            locationBusy = false;
            locationError = null;
            _refreshContext();
          });
          final snapshot = contextSnapshot;
          if (snapshot != null) _reportContextSnapshot(snapshot);
        },
        onError: (Object exception) {
          if (!mounted) return;
          setState(() {
            locationBusy = false;
            locationError = exception.toString();
          });
        },
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          locationBusy = false;
          locationError = exception.toString();
        });
      }
    }
  }

  Future<void> enableBackgroundContext() async {
    final activeTicket = ticket;
    if (activeTicket == null) return;
    setState(() {
      backgroundContextBusy = true;
      backgroundContextError = null;
    });
    try {
      _venue ??= await widget.repository.getVenueContext();
      await widget.backgroundGeofenceService.registerForTicket(
        ticketId: activeTicket.id,
        venue: _venue!,
      );
      if (mounted) setState(() => backgroundContextActive = true);
    } catch (exception) {
      if (mounted) {
        setState(() => backgroundContextError = exception.toString());
      }
    } finally {
      if (mounted) setState(() => backgroundContextBusy = false);
    }
  }

  Future<void> enableAlerts() async {
    setState(() {
      alertsBusy = true;
      alertsError = null;
    });
    try {
      await widget.pushNotificationService.enable(widget.repository);
      if (mounted) setState(() => alertsActive = true);
    } catch (exception) {
      if (mounted) setState(() => alertsError = exception.toString());
    } finally {
      if (mounted) setState(() => alertsBusy = false);
    }
  }

  Future<void> showTicketQr() async {
    final activeTicket = ticket;
    if (activeTicket == null) return;
    try {
      final payload = await widget.repository.getTicketQrPayload(
        activeTicket.id,
      );
      if (!mounted) return;
      await QrPassDialog.show(context, payload: payload);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  void go(CustomerStep next) => setState(() => step = next);

  Future<void> joinQueue() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final joined = await widget.repository.joinQueue(
        guestName: guestName.trim().isEmpty ? 'Guest' : guestName,
        partySize: partySize,
        venueId: _venue?.id,
      );
      if (mounted) {
        setState(() {
          ticket = joined;
          step = CustomerStep.ticket;
          selectedTab = CustomerTab.ticket;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leaveQueue() async {
    final active = ticket;
    if (active == null) return;

    if (active.status == TicketStatus.seated) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish dining & leave?'),
          content: const Text(
            'Your table will be released and marked as available for the next guests.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay seated'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
              child: const Text('Release table'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await widget.repository.autoReleaseMyTicket(
          active.id,
          reason: 'self_checkout',
        );
        await widget.backgroundGeofenceService.removeForTicket(active.id);
        if (mounted) {
          setState(() {
            ticket = null;
            historyRevision++;
            step = CustomerStep.discover;
            selectedTab = CustomerTab.home;
            contextSnapshot = null;
            _lastReportedBand = null;
            _leaveNowReported = false;
            backgroundContextActive = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Thank you for dining with us! Your table is released.',
              ),
              backgroundColor: AppColors.forest,
            ),
          );
        }
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not release table: $exception')),
          );
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave queue?'),
        content: const Text('You will forfeit your place in line.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay in line'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Leave queue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.cancelMyTicket(active.id);
      await widget.backgroundGeofenceService.removeForTicket(active.id);
      if (mounted) {
        setState(() {
          ticket = null;
          historyRevision++;
          step = CustomerStep.discover;
          selectedTab = CustomerTab.home;
          contextSnapshot = null;
          _lastReportedBand = null;
          _leaveNowReported = false;
          backgroundContextActive = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave the queue: $exception')),
        );
      }
    }
  }

  Future<void> reportDelay() async {
    final activeTicket = ticket;
    if (activeTicket == null) return;
    setState(() => delayBusy = true);
    try {
      final updated = await widget.repository.reportTicketDelay(activeTicket.id);
      if (mounted) {
        setState(() {
          ticket = updated;
          delayBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text(
              'Staff notified! +${updated.delayMinutes}m added to your arrival window.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (mounted) {
        setState(() => delayBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request delay: $exception')),
        );
      }
    }
  }

  void _simulateFarContext() {
    final activeTicket = ticket;
    final venueLat = _venue?.latitude ?? 16.85585;
    final venueLng = _venue?.longitude ?? 96.13527;
    setState(() {
      _lastLocation = DeviceLocation(
        latitude: venueLat - 0.022,
        longitude: venueLng - 0.012,
        accuracyMeters: 10,
        recordedAt: DateTime.now(),
      );
      contextSnapshot = ContextSnapshot(
        distanceMeters: 2600,
        estimatedTravelMinutes: 34,
        estimatedWaitMinutes: activeTicket?.estimatedWaitMinutes ?? 24,
        safetyBufferMinutes: 5,
        proximity: ProximityBand.far,
        shouldLeaveNow: false,
        recordedAt: DateTime.now(),
      );
      if (activeTicket != null) selectedTab = CustomerTab.ticket;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.forest,
        content: Text('Simulated: Far (> 2.5 km away) • Map updated'),
      ),
    );
  }

  void _simulateApproachingContext() {
    final activeTicket = ticket;
    final venueLat = _venue?.latitude ?? 16.85585;
    final venueLng = _venue?.longitude ?? 96.13527;
    setState(() {
      _lastLocation = DeviceLocation(
        latitude: venueLat - 0.0032,
        longitude: venueLng - 0.0018,
        accuracyMeters: 10,
        recordedAt: DateTime.now(),
      );
      contextSnapshot = ContextSnapshot(
        distanceMeters: 400,
        estimatedTravelMinutes: 5,
        estimatedWaitMinutes: activeTicket?.estimatedWaitMinutes ?? 10,
        safetyBufferMinutes: 5,
        proximity: ProximityBand.approaching,
        shouldLeaveNow: true,
        recordedAt: DateTime.now(),
      );
      if (activeTicket != null) selectedTab = CustomerTab.ticket;
    });
    if (activeTicket != null) {
      widget.repository.recordContextEvent(
        ticketId: activeTicket.id,
        eventType: 'outer_geofence_entered',
        distanceBand: 'approaching',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.amber,
        content: Text('Simulated: Approaching (400m) • Map pin moved inside 800m'),
      ),
    );
  }

  void _simulateNearContext() {
    final activeTicket = ticket;
    final venueLat = _venue?.latitude ?? 16.85585;
    final venueLng = _venue?.longitude ?? 96.13527;
    setState(() {
      _lastLocation = DeviceLocation(
        latitude: venueLat - 0.0004,
        longitude: venueLng - 0.0002,
        accuracyMeters: 5,
        recordedAt: DateTime.now(),
      );
      contextSnapshot = ContextSnapshot(
        distanceMeters: 50,
        estimatedTravelMinutes: 1,
        estimatedWaitMinutes: activeTicket?.estimatedWaitMinutes ?? 0,
        safetyBufferMinutes: 2,
        proximity: ProximityBand.near,
        shouldLeaveNow: true,
        recordedAt: DateTime.now(),
      );
      if (activeTicket != null) selectedTab = CustomerTab.ticket;
    });
    if (activeTicket != null) {
      widget.repository.recordContextEvent(
        ticketId: activeTicket.id,
        eventType: 'arrival_geofence_entered',
        distanceBand: 'near',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.forest,
        content: Text('Simulated: Arrived at Venue (50m) • Map pin inside 100m'),
      ),
    );
  }

  void _simulateDepartureContext() async {
    final activeTicket = ticket;
    if (activeTicket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active ticket to depart.')),
      );
      return;
    }
    try {
      await widget.repository.recordContextEvent(
        ticketId: activeTicket.id,
        eventType: 'outer_geofence_exited',
        distanceBand: 'far',
      );
      setState(() {
        contextSnapshot = null;
        selectedTab = CustomerTab.home;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.coral,
            content: Text('Simulated Geofence Exit: Seated party auto-departed!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Departure error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (step == CustomerStep.join) {
      return JoinQueueScreen(
        partySize: partySize,
        busy: busy,
        error: error,
        demoMode: widget.repository.isDemo,
        onNameChanged: (value) => guestName = value,
        onPartyChanged: (value) => setState(() => partySize = value),
        onBack: () => go(CustomerStep.discover),
        onJoin: joinQueue,
      );
    }

    final activeTicket = ticket;
    final pages = <Widget>[
      DiscoverScreen(
        venue: _venue,
        venues: _venues,
        selectedVenue: _venue,
        waitingPartiesCount: _venueWaitingCount,
        onSelectVenue: (v) {
          setState(() {
            _venue = v;
            _refreshContext();
          });
          _subscribeVenueTickets();
        },
        userLocation: _lastLocation,
        hasActiveTicket: activeTicket != null,
        onRefresh: _refreshVenues,
        onJoin: () {
          if (activeTicket != null) {
            setState(() => selectedTab = CustomerTab.ticket);
          } else {
            go(CustomerStep.join);
          }
        },
      ),
      activeTicket == null
          ? NoActiveTicketScreen(
              onBrowse: () => setState(() => selectedTab = CustomerTab.home),
            )
          : ActiveTicketScreen(
              ticket: activeTicket,
              demoMode: widget.repository.isDemo,
              contextSnapshot: contextSnapshot,
              locationBusy: locationBusy,
              locationError: locationError,
              backgroundSupported: widget.backgroundGeofenceService.isSupported,
              backgroundContextActive: backgroundContextActive,
              backgroundContextBusy: backgroundContextBusy,
              backgroundContextError: backgroundContextError,
              alertsSupported: widget.pushNotificationService.isSupported,
              alertsActive: alertsActive,
              alertsBusy: alertsBusy,
              alertsError: alertsError,
              onEnableLocation: enableLocationContext,
              onEnableBackgroundContext: enableBackgroundContext,
              onEnableAlerts: enableAlerts,
              onOpenLocationSettings: widget.locationService.openSettings,
              onShowQr: showTicketQr,
              onLeave: leaveQueue,
              onReportDelay: reportDelay,
              delayBusy: delayBusy,
              venueName: _venue?.name ?? 'UIT',
              venue: _venue,
              customerLocation: _lastLocation,
              onRouteCalculated: (roadDist, roadMins) {
                if (_roadDistance != roadDist || _roadTravelMinutes != roadMins) {
                  setState(() {
                    _roadDistance = roadDist;
                    _roadTravelMinutes = roadMins;
                    _refreshContext();
                  });
                }
              },
            ),
      HistoryScreen(
        key: ValueKey(historyRevision),
        repository: widget.repository,
      ),
      CustomerSettingsScreen(
        venue: _venue,
        locationActive: contextSnapshot != null,
        backgroundSupported: widget.backgroundGeofenceService.isSupported,
        backgroundActive: backgroundContextActive,
        alertsSupported: widget.pushNotificationService.isSupported,
        alertsActive: alertsActive,
        onOpenAppSettings: widget.locationService.openSettings,
        onEnableAlerts: enableAlerts,
        onSimulateFar: _simulateFarContext,
        onSimulateApproaching: _simulateApproachingContext,
        onSimulateNear: _simulateNearContext,
        onSimulateDeparture: _simulateDepartureContext,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: selectedTab.index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab.index,
        onDestinationSelected: (index) {
          final tab = CustomerTab.values[index];
          if (tab == CustomerTab.home) _refreshVenues();
          setState(() => selectedTab = tab);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'My queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
