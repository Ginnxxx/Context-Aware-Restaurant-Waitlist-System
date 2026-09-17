import 'dart:async';

import '../domain/queue_ticket.dart';
import '../domain/ticket_qr_payload.dart';
import '../domain/venue_context.dart';
import 'queue_repository.dart';

class DemoQueueRepository implements QueueRepository {
  DemoQueueRepository() {
    _venues = [
      const VenueContext(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'The Green Table (UIT Campus)',
        address: 'Parami Road, Hlaing Campus, Yangon',
        latitude: 16.85585,
        longitude: 96.13527,
        averageTurnoverMinutes: 5,
        outerGeofenceMeters: 800,
        arrivalGeofenceMeters: 100,
        seatCapacity: 40,
      ),
      const VenueContext(
        id: '00000000-0000-0000-0000-000000000002',
        name: 'The Green Table (Hledan Branch)',
        address: 'Insein Road, Kamayut Township, Yangon',
        latitude: 16.82860,
        longitude: 96.12870,
        averageTurnoverMinutes: 8,
        outerGeofenceMeters: 800,
        arrivalGeofenceMeters: 100,
        seatCapacity: 50,
      ),
      const VenueContext(
        id: '00000000-0000-0000-0000-000000000003',
        name: 'The Green Table (Downtown Bistro)',
        address: 'Sule Pagoda Road, Kyauktada, Yangon',
        latitude: 16.77940,
        longitude: 96.16030,
        averageTurnoverMinutes: 6,
        outerGeofenceMeters: 1000,
        arrivalGeofenceMeters: 120,
        seatCapacity: 60,
      ),
    ];

    _tickets = [
      QueueTicket(
        id: 'QL-1048',
        venueId: _venues[0].id,
        guestName: 'Maya Chen',
        partySize: 2,
        position: 1,
        estimatedWaitMinutes: 4,
        status: TicketStatus.waiting,
        joinedAt: DateTime.now(),
      ),
      QueueTicket(
        id: 'QL-1049',
        venueId: _venues[0].id,
        guestName: 'Noah Williams',
        partySize: 4,
        position: 2,
        estimatedWaitMinutes: 9,
        status: TicketStatus.approaching,
        joinedAt: DateTime.now(),
      ),
      QueueTicket(
        id: 'QL-1050',
        venueId: _venues[0].id,
        guestName: 'Sofia Patel',
        partySize: 3,
        position: 3,
        estimatedWaitMinutes: 14,
        status: TicketStatus.waiting,
        joinedAt: DateTime.now(),
      ),
      QueueTicket(
        id: 'QL-1051',
        venueId: _venues[0].id,
        guestName: 'Liam Jones',
        partySize: 2,
        position: 4,
        estimatedWaitMinutes: 18,
        status: TicketStatus.waiting,
        joinedAt: DateTime.now(),
      ),
      QueueTicket(
        id: 'QL-1046',
        venueId: _venues[0].id,
        guestName: 'Emma Davis',
        partySize: 5,
        position: 0,
        estimatedWaitMinutes: 0,
        status: TicketStatus.called,
        joinedAt: DateTime.now(),
      ),
    ];
  }

  late List<VenueContext> _venues;
  String _activeVenueId = '00000000-0000-0000-0000-000000000001';
  late List<QueueTicket> _tickets;
  QueueTicket? _mine;
  final List<QueueTicket> _history = [];
  final _venueController = StreamController<List<QueueTicket>>.broadcast();
  final _mineController = StreamController<QueueTicket?>.broadcast();
  final _venuesController = StreamController<List<VenueContext>>.broadcast();

  @override
  bool get isDemo => true;

  @override
  bool get isStaffSignedIn => true;

  @override
  Future<void> ensureCustomerSession() async {}

  @override
  Future<void> signInStaff({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<QueueTicket?> watchMyActiveTicket({String? venueId}) async* {
    yield _mine;
    yield* _mineController.stream;
  }

  @override
  Future<QueueTicket?> getMyActiveTicket({String? venueId}) async => _mine;

  @override
  Future<List<QueueTicket>> getMyTicketHistory() async =>
      List.unmodifiable(_history.reversed);

  @override
  Stream<List<QueueTicket>> watchVenueTickets({String? venueId}) async* {
    final vId = venueId ?? _activeVenueId;
    yield List.unmodifiable(_tickets.where((t) => t.venueId == vId));
    yield* _venueController.stream.map(
      (list) => list.where((t) => t.venueId == vId).toList(),
    );
  }

  @override
  Future<int> getVenueWaitingCount({String? venueId}) async {
    final vId = venueId ?? _activeVenueId;
    return _tickets
        .where((t) =>
            t.venueId == vId &&
            (t.status == TicketStatus.waiting ||
                t.status == TicketStatus.called ||
                t.status == TicketStatus.approaching))
        .length;
  }

  @override
  Future<VenueContext> getVenueContext({String? venueId}) async {
    final vId = venueId ?? _activeVenueId;
    return _venues.firstWhere(
      (v) => v.id == vId,
      orElse: () => _venues.first,
    );
  }

  @override
  Future<List<VenueContext>> getAllVenues() async => List.unmodifiable(_venues);

  @override
  Stream<List<VenueContext>> watchVenues() async* {
    yield List.unmodifiable(_venues);
    yield* _venuesController.stream;
  }

  void _emitVenues() {
    if (!_venuesController.isClosed) {
      _venuesController.add(List.unmodifiable(_venues));
    }
  }

  @override
  Future<VenueContext> createVenue({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    int averageTurnoverMinutes = 5,
    int outerGeofenceMeters = 800,
    int arrivalGeofenceMeters = 100,
    int seatCapacity = 40,
  }) async {
    final newVenue = VenueContext(
      id: '00000000-0000-0000-0000-00000000000${_venues.length + 1}',
      name: name.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      averageTurnoverMinutes: averageTurnoverMinutes,
      outerGeofenceMeters: outerGeofenceMeters,
      arrivalGeofenceMeters: arrivalGeofenceMeters,
      seatCapacity: seatCapacity,
    );
    _venues.add(newVenue);
    _activeVenueId = newVenue.id;
    _emitVenues();
    return newVenue;
  }

  @override
  Future<void> recordContextEvent({
    required String ticketId,
    required String eventType,
    required String distanceBand,
  }) async {
    if (eventType == 'outer_geofence_exited') {
      await autoReleaseMyTicket(ticketId, reason: 'geofence_exit');
    }
  }

  @override
  Future<TicketQrPayload> getTicketQrPayload(String ticketId) async =>
      TicketQrPayload(
        ticketId: ticketId,
        venueId: _activeVenueId,
        nonce: 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
      );

  @override
  Future<void> registerDeviceInstallation({
    required String platform,
    required String fcmToken,
  }) async {}

  @override
  Future<QueueTicket> verifyTicketQr(String encodedPayload) async {
    final payload = TicketQrPayload.decode(encodedPayload);
    final index = _tickets.indexWhere((ticket) => ticket.id == payload.ticketId);
    if (index < 0) throw StateError('Ticket not found in queue');
    final updated = _tickets[index].copyWith(status: TicketStatus.arrived);
    _tickets[index] = updated;
    if (_mine?.id == updated.id) _mine = updated;
    _emit();
    return updated;
  }

  @override
  Future<QueueTicket> joinQueue({
    required String guestName,
    required int partySize,
    String? venueId,
  }) async {
    final vId = venueId ?? _activeVenueId;
    final venue = await getVenueContext(venueId: vId);
    if (!venue.queueOpen) {
      throw StateError('The queue for ${venue.name} is currently paused.');
    }
    final venueTickets = _tickets.where((t) => t.venueId == vId).toList();
    final activeAhead = venueTickets
        .where(
          (t) =>
              t.status == TicketStatus.waiting ||
              t.status == TicketStatus.approaching,
        )
        .length;
    final ticket = QueueTicket(
      id: 'QL-${1052 + _tickets.length}',
      venueId: vId,
      guestName: guestName,
      partySize: partySize,
      position: activeAhead + 1,
      estimatedWaitMinutes: (activeAhead + 1) * venue.averageTurnoverMinutes,
      status: TicketStatus.waiting,
      joinedAt: DateTime.now(),
    );
    _tickets.add(ticket);
    _mine = ticket;
    _emit();
    return ticket;
  }

  @override
  Future<void> cancelMyTicket(String ticketId) async {
    _tickets.removeWhere((ticket) => ticket.id == ticketId);
    if (_mine?.id == ticketId) {
      _history.add(_mine!.copyWith(status: TicketStatus.cancelled));
      _mine = null;
    }
    _recalculatePositions();
    _emit();
  }

  @override
  Future<void> callNextParty({String? venueId, bool force = false}) async {
    final vId = venueId ?? _activeVenueId;
    final venue = _venues.firstWhere(
      (v) => v.id == vId,
      orElse: () => _venues.first,
    );

    // Calculate occupied (dining) seats
    final occupiedSeats = _tickets
        .where(
          (t) =>
              t.venueId == vId &&
              t.status == TicketStatus.seated &&
              t.departedAt == null,
        )
        .fold<int>(0, (sum, t) => sum + t.partySize);

    // Calculate reserved seats (called + arrived)
    final reservedSeats = _tickets
        .where(
          (t) =>
              t.venueId == vId &&
              (t.status == TicketStatus.called ||
                  t.status == TicketStatus.arrived),
        )
        .fold<int>(0, (sum, t) => sum + t.partySize);

    final committedSeats = occupiedSeats + reservedSeats;
    final availableSeats = (venue.seatCapacity - committedSeats).clamp(0, 9999);

    int targetIndex = -1;
    if (force) {
      targetIndex = _tickets.indexWhere(
        (t) =>
            t.venueId == vId &&
            (t.status == TicketStatus.waiting ||
                t.status == TicketStatus.approaching),
      );
    } else {
      // Smart Table-Fit: find first party whose size fits within available free seats
      targetIndex = _tickets.indexWhere(
        (t) =>
            t.venueId == vId &&
            (t.status == TicketStatus.waiting ||
                t.status == TicketStatus.approaching) &&
            t.partySize <= availableSeats,
      );

      if (targetIndex < 0) {
        final hasWaiting = _tickets.any(
          (t) =>
              t.venueId == vId &&
              (t.status == TicketStatus.waiting ||
                  t.status == TicketStatus.approaching),
        );
        if (hasWaiting) {
          throw StateError(
            'Not enough seats available ($availableSeats free of ${venue.seatCapacity} capacity). Wait for tables to clear or override.',
          );
        }
      }
    }

    if (targetIndex < 0) return;

    _tickets[targetIndex] = _tickets[targetIndex].copyWith(
      status: TicketStatus.called,
      position: 0,
      estimatedWaitMinutes: 0,
      calledAt: DateTime.now(),
    );
    if (_mine?.id == _tickets[targetIndex].id) {
      _mine = _tickets[targetIndex];
    }
    _recalculatePositions();
    _emit();
  }

  @override
  Future<void> transitionTicket(
    String ticketId,
    TicketStatus status, {
    String? tableLabel,
  }) async {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) return;
    final current = _tickets[index];
    final isInactive =
        status == TicketStatus.cancelled || status == TicketStatus.noShow;

    if (isInactive) {
      final removed = _tickets.removeAt(index);
      final archived = removed.copyWith(status: status);
      _history.add(archived);
      if (_mine?.id == ticketId) {
        _mine = null;
      }
    } else {
      _tickets[index] = current.copyWith(
        status: status,
        tableLabel: tableLabel ?? current.tableLabel,
        calledAt: status == TicketStatus.called
            ? (current.calledAt ?? DateTime.now())
            : current.calledAt,
        position: (status == TicketStatus.called ||
                status == TicketStatus.arrived ||
                status == TicketStatus.seated)
            ? 0
            : current.position,
        estimatedWaitMinutes: (status == TicketStatus.called ||
                status == TicketStatus.arrived ||
                status == TicketStatus.seated)
            ? 0
            : current.estimatedWaitMinutes,
      );
      if (_mine?.id == ticketId) {
        _mine = _tickets[index];
      }
    }

    _recalculatePositions();
    _emit();
  }

  @override
  Future<void> releaseSeatedTicket(String ticketId) async {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) return;
    _tickets[index] = _tickets[index].copyWith(
      status: TicketStatus.seated,
      departedAt: DateTime.now(),
      departureReason: 'staff_released',
    );
    _history.add(_tickets[index]);
    if (_mine?.id == ticketId) {
      _mine = null;
    }
    _emit();
  }

  @override
  Future<void> autoReleaseMyTicket(String ticketId, {String? reason}) async {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0 || _tickets[index].status != TicketStatus.seated) return;
    _tickets[index] = _tickets[index].copyWith(
      departedAt: DateTime.now(),
      departureReason: reason ?? 'self_checkout',
    );
    if (_mine?.id == ticketId) {
      _history.add(_tickets[index]);
      _mine = null;
    }
    _emit();
  }

  @override
  Future<QueueTicket> reportTicketDelay(
    String ticketId, {
    int additionalMinutes = 5,
  }) async {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) throw StateError('Ticket not found');
    final currentDelay = _tickets[index].delayMinutes;
    final newDelay = (currentDelay + additionalMinutes).clamp(0, 10);
    _tickets[index] = _tickets[index].copyWith(delayMinutes: newDelay);
    if (_mine?.id == ticketId) {
      _mine = _tickets[index];
    }
    _emit();
    return _tickets[index];
  }

  @override
  Future<void> setQueueOpen(bool open, {String? venueId}) async {
    final vId = venueId ?? _activeVenueId;
    final index = _venues.indexWhere((v) => v.id == vId);
    if (index >= 0) {
      _venues[index] = _venues[index].copyWith(queueOpen: open);
      _emitVenues();
    }
  }

  @override
  Future<VenueContext> updateVenueSettings({
    String? venueId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int averageTurnoverMinutes,
    required int outerGeofenceMeters,
    required int arrivalGeofenceMeters,
    required int seatCapacity,
  }) async {
    final vId = venueId ?? _activeVenueId;
    final index = _venues.indexWhere((v) => v.id == vId);
    final updated = VenueContext(
      id: vId,
      name: name.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      averageTurnoverMinutes: averageTurnoverMinutes,
      outerGeofenceMeters: outerGeofenceMeters,
      arrivalGeofenceMeters: arrivalGeofenceMeters,
      seatCapacity: seatCapacity,
      queueOpen: index >= 0 ? _venues[index].queueOpen : true,
    );
    if (index >= 0) {
      _venues[index] = updated;
    } else {
      _venues.add(updated);
    }
    _emitVenues();
    return updated;
  }

  void _recalculatePositions() {
    var position = 1;
    for (var i = 0; i < _tickets.length; i++) {
      if (_tickets[i].status == TicketStatus.waiting ||
          _tickets[i].status == TicketStatus.approaching) {
        _tickets[i] = _tickets[i].copyWith(
          position: position,
          estimatedWaitMinutes: position * 5,
        );
        if (_mine?.id == _tickets[i].id) {
          _mine = _tickets[i];
        }
        position++;
      }
    }
  }

  void _emit() {
    _venueController.add(List.unmodifiable(_tickets));
    _mineController.add(_mine);
  }
}
