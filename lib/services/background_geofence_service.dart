import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../domain/venue_context.dart';

const _outerPrefix = 'ql-outer-';
const _arrivalPrefix = 'ql-arrival-';

class BackgroundGeofenceService {
  const BackgroundGeofenceService();

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> registerForTicket({
    required String ticketId,
    required VenueContext venue,
  }) async {
    if (!isSupported) return;
    final manager = NativeGeofenceManager.instance;
    await manager.initialize();
    await _removeTicketGeofences(manager, ticketId);

    final location = Location(
      latitude: venue.latitude,
      longitude: venue.longitude,
    );
    await manager.createGeofence(
      _geofence(
        id: '$_outerPrefix$ticketId',
        location: location,
        radiusMeters: venue.outerGeofenceMeters.toDouble(),
        triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
      ),
      queueLessGeofenceTriggered,
    );
    await manager.createGeofence(
      _geofence(
        id: '$_arrivalPrefix$ticketId',
        location: location,
        radiusMeters: venue.arrivalGeofenceMeters.toDouble(),
        triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
      ),
      queueLessGeofenceTriggered,
    );
  }

  Future<void> removeForTicket(String ticketId) async {
    if (!isSupported) return;
    final manager = NativeGeofenceManager.instance;
    await manager.initialize();
    await _removeTicketGeofences(manager, ticketId);
  }

  Future<bool> isRegistered(String ticketId) async {
    if (!isSupported) return false;
    final manager = NativeGeofenceManager.instance;
    await manager.initialize();
    final ids = await manager.getRegisteredGeofenceIds();
    return ids.contains('$_outerPrefix$ticketId') &&
        ids.contains('$_arrivalPrefix$ticketId');
  }

  Geofence _geofence({
    required String id,
    required Location location,
    required double radiusMeters,
    required Set<GeofenceEvent> triggers,
  }) => Geofence(
    id: id,
    location: location,
    radiusMeters: radiusMeters,
    triggers: triggers,
    iosSettings: const IosGeofenceSettings(initialTrigger: true),
    androidSettings: AndroidGeofenceSettings(
      initialTriggers: triggers,
      expiration: const Duration(days: 30),
      notificationResponsiveness: const Duration(minutes: 1),
    ),
  );

  Future<void> _removeTicketGeofences(
    NativeGeofenceManager manager,
    String ticketId,
  ) async {
    final registered = await manager.getRegisteredGeofenceIds();
    for (final id in ['$_outerPrefix$ticketId', '$_arrivalPrefix$ticketId']) {
      if (registered.contains(id)) await manager.removeGeofenceById(id);
    }
  }
}

@pragma('vm:entry-point')
Future<void> queueLessGeofenceTriggered(GeofenceCallbackParams params) async {
  if (!AppConfig.hasSupabase) return;
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) return;

  for (final geofence in params.geofences) {
    final mapping = _eventMapping(geofence.id, params.event);
    if (mapping == null) continue;
    await client.rpc(
      'record_context_event',
      params: {
        'target_ticket': mapping.ticketId,
        'target_event_type': mapping.eventType,
        'target_distance_band': mapping.distanceBand,
      },
    );
  }
}

_ContextEventMapping? _eventMapping(String id, GeofenceEvent event) {
  if (id.startsWith(_arrivalPrefix)) {
    if (event == GeofenceEvent.enter) {
      return _ContextEventMapping(
        ticketId: id.substring(_arrivalPrefix.length),
        eventType: 'arrival_geofence_entered',
        distanceBand: 'near',
      );
    }
    if (event == GeofenceEvent.exit) {
      return _ContextEventMapping(
        ticketId: id.substring(_arrivalPrefix.length),
        eventType: 'arrival_geofence_exited',
        distanceBand: 'approaching',
      );
    }
  }
  if (!id.startsWith(_outerPrefix)) return null;
  if (event == GeofenceEvent.enter) {
    return _ContextEventMapping(
      ticketId: id.substring(_outerPrefix.length),
      eventType: 'outer_geofence_entered',
      distanceBand: 'approaching',
    );
  }
  if (event == GeofenceEvent.exit) {
    return _ContextEventMapping(
      ticketId: id.substring(_outerPrefix.length),
      eventType: 'outer_geofence_exited',
      distanceBand: 'far',
    );
  }
  return null;
}

class _ContextEventMapping {
  const _ContextEventMapping({
    required this.ticketId,
    required this.eventType,
    required this.distanceBand,
  });

  final String ticketId;
  final String eventType;
  final String distanceBand;
}
