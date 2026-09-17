import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../domain/queue_ticket.dart';
import '../domain/ticket_qr_payload.dart';
import '../domain/venue_context.dart';
import 'queue_repository.dart';

class SupabaseQueueRepository implements QueueRepository {
  SupabaseQueueRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isDemo => false;

  @override
  bool get isStaffSignedIn =>
      _client.auth.currentSession != null &&
      !(_client.auth.currentUser?.isAnonymous ?? true);

  @override
  Future<void> ensureCustomerSession() async {
    if (_client.auth.currentSession == null) {
      try {
        await _client.auth.signInAnonymously();
      } catch (_) {
        // Clear cached stale token from a different network/IP and retry
        try {
          await _client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
        await _client.auth.signInAnonymously();
      }
    }
  }

  @override
  Future<void> signInStaff({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<QueueTicket?> watchMyActiveTicket({String? venueId}) {
    final controller = StreamController<QueueTicket?>();
    Timer? pollTimer;

    Future<void> emitLatest() async {
      try {
        final ticket = await getMyActiveTicket(venueId: venueId);
        if (!controller.isClosed) controller.add(ticket);
      } catch (error) {
        if (!controller.isClosed) controller.addError(error);
      }
    }

    emitLatest();
    pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => emitLatest(),
    );

    controller.onCancel = () {
      pollTimer?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<QueueTicket?> getMyActiveTicket({String? venueId}) async {
    await ensureCustomerSession();
    
    // Path 1: Try RPC snapshot
    try {
      final params = venueId != null
          ? {'target_venue': venueId}
          : <String, dynamic>{};
      final response = await _client.rpc(
        'my_active_ticket_snapshot',
        params: params,
      );
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isNotEmpty) {
        return QueueTicket.fromMap(rows.first);
      }
    } catch (_) {
      // Fall through to direct table query
    }

    // Path 2: Direct table query fallback for maximum reliability
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      var query = _client
          .from('tickets')
          .select()
          .eq('owner_id', userId)
          .inFilter('status', ['waiting', 'called', 'approaching', 'arrived', 'seated']);

      if (venueId != null) {
        query = query.eq('venue_id', venueId);
      }

      final directRows = await query
          .order('joined_at', ascending: false)
          .limit(1);

      if (directRows.isNotEmpty) {
        final raw = Map<String, dynamic>.from(directRows.first);
        if (raw['status'] != 'seated' || raw['departed_at'] == null) {
          final isWaiting =
              raw['status'] == 'waiting' || raw['status'] == 'approaching';
          var pos = 0;
          if (isWaiting) {
            try {
              final aheadRows = await _client
                  .from('tickets')
                  .select('id')
                  .eq('venue_id', raw['venue_id'])
                  .lt('sequence', raw['sequence'])
                  .inFilter('status', ['waiting', 'approaching']);
              pos = 1 + (aheadRows as List).length;
            } catch (_) {
              pos = 1;
            }
          }
          return QueueTicket.fromMap(
            raw,
            position: pos,
            estimatedWaitMinutes: pos > 0 ? (pos - 1) * 5 : 0,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Stream<List<QueueTicket>> watchVenueTickets({String? venueId}) {
    final vId = venueId ?? AppConfig.venueId;
    return _client
        .from('tickets')
        .stream(primaryKey: ['id'])
        .eq('venue_id', vId)
        .order('sequence')
        .map((rows) {
          var position = 0;
          return rows
              .map((row) {
                final status = TicketStatus.values.firstWhere(
                  (value) => value.databaseValue == row['status'],
                );
                final active =
                    status == TicketStatus.waiting ||
                    status == TicketStatus.approaching;
                if (active) position++;
                return QueueTicket.fromMap(
                  row,
                  position: active ? position : 0,
                  estimatedWaitMinutes: active ? (position - 1) * 5 : 0,
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Future<int> getVenueWaitingCount({String? venueId}) async {
    final vId = venueId ?? AppConfig.venueId;
    try {
      final res = await _client.rpc('get_venue_waiting_count', params: {
        'target_venue': vId,
      });
      if (res is int) return res;
      if (res is num) return res.toInt();
    } catch (_) {}

    try {
      final rows = await _client
          .from('tickets')
          .select('id')
          .eq('venue_id', vId)
          .inFilter('status', ['waiting', 'approaching', 'called']);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<VenueContext> getVenueContext({String? venueId}) async {
    if (venueId != null) {
      final response = await _client
          .from('venues')
          .select(
            'id,name,address,latitude,longitude,average_turnover_minutes,'
            'outer_geofence_meters,arrival_geofence_meters,seat_capacity,'
            'queue_open',
          )
          .eq('id', venueId)
          .maybeSingle();
      if (response != null) {
        return VenueContext.fromMap(response);
      }
    }
    final all = await getAllVenues();
    if (all.isNotEmpty) return all.first;
    return const VenueContext(
      id: AppConfig.venueId,
      name: 'Default Venue',
      address: '',
      latitude: 16.85585,
      longitude: 96.13527,
      averageTurnoverMinutes: 5,
      outerGeofenceMeters: 800,
      arrivalGeofenceMeters: 100,
      seatCapacity: 40,
      queueOpen: true,
    );
  }

  @override
  Future<List<VenueContext>> getAllVenues() async {
    final response = await _client
        .from('venues')
        .select(
          'id,name,address,latitude,longitude,average_turnover_minutes,'
          'outer_geofence_meters,arrival_geofence_meters,seat_capacity,'
          'queue_open',
        )
        .order('name');
    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map((row) => VenueContext.fromMap(row)).toList();
  }

  @override
  Stream<List<VenueContext>> watchVenues() {
    final controller = StreamController<List<VenueContext>>.broadcast();
    Timer? pollTimer;
    StreamSubscription? streamSub;

    Future<void> emitLatest() async {
      try {
        final venues = await getAllVenues();
        if (!controller.isClosed) controller.add(venues);
      } catch (error) {
        if (!controller.isClosed) controller.addError(error);
      }
    }

    emitLatest();

    try {
      streamSub = _client
          .from('venues')
          .stream(primaryKey: ['id'])
          .listen((rows) {
            final venues = rows.map(VenueContext.fromMap).toList();
            if (!controller.isClosed) controller.add(venues);
          }, onError: (_) {});
    } catch (_) {}

    pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => emitLatest());

    controller.onCancel = () {
      pollTimer?.cancel();
      streamSub?.cancel();
    };

    return controller.stream;
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
    final response = await _client.rpc(
      'create_venue',
      params: {
        'venue_name': name.trim(),
        'venue_address': address.trim(),
        'venue_lat': latitude,
        'venue_lng': longitude,
        'turnover_mins': averageTurnoverMinutes,
        'outer_meters': outerGeofenceMeters,
        'arrival_meters': arrivalGeofenceMeters,
        'capacity': seatCapacity,
      },
    );
    return VenueContext.fromMap(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> recordContextEvent({
    required String ticketId,
    required String eventType,
    required String distanceBand,
  }) => _client.rpc(
    'record_context_event',
    params: {
      'target_ticket': ticketId,
      'target_event_type': eventType,
      'target_distance_band': distanceBand,
    },
  );

  @override
  Future<TicketQrPayload> getTicketQrPayload(String ticketId) async {
    final response = await _client
        .from('tickets')
        .select('id,venue_id,qr_nonce')
        .eq('id', ticketId)
        .single();
    return TicketQrPayload(
      ticketId: response['id'] as String,
      venueId: response['venue_id'] as String,
      nonce: response['qr_nonce'] as String,
    );
  }

  @override
  Future<void> registerDeviceInstallation({
    required String platform,
    required String fcmToken,
  }) async {
    await ensureCustomerSession();
    await _client.rpc(
      'register_device_installation',
      params: {'target_platform': platform, 'target_fcm_token': fcmToken},
    );
  }

  @override
  Future<QueueTicket> verifyTicketQr(String encodedPayload) async {
    final payload = TicketQrPayload.decode(encodedPayload);
    final response = await _client.rpc(
      'verify_ticket_qr',
      params: {
        'target_ticket': payload.ticketId,
        'supplied_nonce': payload.nonce,
      },
    );
    return QueueTicket.fromMap(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<QueueTicket> joinQueue({
    required String guestName,
    required int partySize,
    String? venueId,
  }) async {
    await ensureCustomerSession();
    String? vId = venueId;
    if (vId == null) {
      final venues = await getAllVenues();
      vId = venues.isNotEmpty ? venues.first.id : AppConfig.venueId;
    }
    final response = await _client.rpc(
      'join_queue',
      params: {
        'target_venue': vId,
        'customer_name': guestName,
        'customer_party_size': partySize,
      },
    );
    return QueueTicket.fromMap(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> cancelMyTicket(String ticketId) =>
      _client.rpc('cancel_my_ticket', params: {'target_ticket': ticketId});

  @override
  Future<void> callNextParty({String? venueId, bool force = false}) async {
    String? vId = venueId;
    if (vId == null) {
      final venues = await getAllVenues();
      vId = venues.isNotEmpty ? venues.first.id : AppConfig.venueId;
    }
    await _client.rpc(
      'call_next_party',
      params: {'target_venue': vId, 'force_call': force},
    );
  }

  @override
  Future<void> transitionTicket(
    String ticketId,
    TicketStatus status, {
    String? tableLabel,
  }) => _client.rpc(
    'staff_transition_ticket',
    params: {
      'target_ticket': ticketId,
      'next_status': status.databaseValue,
      'target_table_label': tableLabel,
    },
  );

  @override
  Future<void> releaseSeatedTicket(String ticketId) =>
      _client.rpc('release_seated_ticket', params: {'target_ticket': ticketId});

  @override
  Future<void> autoReleaseMyTicket(String ticketId, {String? reason}) =>
      _client.rpc(
        'auto_release_seated_ticket',
        params: {
          'target_ticket': ticketId,
          'reason': reason ?? 'self_checkout',
        },
      );

  @override
  Future<QueueTicket> reportTicketDelay(
    String ticketId, {
    int additionalMinutes = 5,
  }) async {
    await ensureCustomerSession();
    final response = await _client.rpc(
      'report_ticket_delay',
      params: {
        'target_ticket': ticketId,
        'additional_minutes': additionalMinutes,
      },
    );
    return QueueTicket.fromMap(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> setQueueOpen(bool open, {String? venueId}) async {
    String? vId = venueId;
    if (vId == null) {
      final venues = await getAllVenues();
      vId = venues.isNotEmpty ? venues.first.id : AppConfig.venueId;
    }
    try {
      await _client.rpc(
        'set_venue_queue_open',
        params: {
          'target_venue': vId,
          'is_open': open,
        },
      );
    } catch (_) {
      await _client
          .from('venues')
          .update({'queue_open': open})
          .eq('id', vId);
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
    String? vId = venueId;
    if (vId == null) {
      final venues = await getAllVenues();
      vId = venues.isNotEmpty ? venues.first.id : AppConfig.venueId;
    }
    try {
      final response = await _client.rpc(
        'update_venue_settings_v2',
        params: {
          'target_venue': vId,
          'venue_name': name.trim(),
          'venue_address': address.trim(),
          'venue_lat': latitude,
          'venue_lng': longitude,
          'turnover_mins': averageTurnoverMinutes,
          'outer_meters': outerGeofenceMeters,
          'arrival_meters': arrivalGeofenceMeters,
          'capacity': seatCapacity,
        },
      );
      return VenueContext.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (_) {
      final response = await _client
          .from('venues')
          .update({
            'name': name.trim(),
            'address': address.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'average_turnover_minutes': averageTurnoverMinutes,
            'outer_geofence_meters': outerGeofenceMeters,
            'arrival_geofence_meters': arrivalGeofenceMeters,
            'seat_capacity': seatCapacity,
          })
          .eq('id', vId)
          .select()
          .single();
      return VenueContext.fromMap(Map<String, dynamic>.from(response));
    }
  }

  @override
  Future<List<QueueTicket>> getMyTicketHistory() async {
    await ensureCustomerSession();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await _client
        .from('tickets')
        .select(
          'id, venue_id, guest_name, party_size, sequence, status, joined_at, '
          'called_at, departed_at, table_label, departure_reason, delay_minutes',
        )
        .eq('owner_id', userId)
        .order('joined_at', ascending: false)
        .limit(30);

    final rows = (response as List).cast<Map<String, dynamic>>();
    return rows.map((row) => QueueTicket.fromMap(row)).toList();
  }
}
