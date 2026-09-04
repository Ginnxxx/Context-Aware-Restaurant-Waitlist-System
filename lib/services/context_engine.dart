import 'dart:math' as math;

import '../domain/context_snapshot.dart';
import '../domain/venue_context.dart';

class ContextEngine {
  const ContextEngine({
    this.travelMetersPerMinute = 80,
    this.safetyBufferMinutes = 5,
  });

  final double travelMetersPerMinute;
  final int safetyBufferMinutes;

  ContextSnapshot evaluate({
    required DeviceLocation location,
    required VenueContext venue,
    required int estimatedWaitMinutes,
    double? overrideDistanceMeters,
    int? overrideTravelMinutes,
  }) {
    final distance = overrideDistanceMeters ??
        distanceBetween(
          location.latitude,
          location.longitude,
          venue.latitude,
          venue.longitude,
        );
    final travelMinutes = overrideTravelMinutes ??
        math.max(
          1,
          (distance / travelMetersPerMinute).ceil(),
        );
    final proximity = distance <= venue.arrivalGeofenceMeters
        ? ProximityBand.near
        : distance <= venue.outerGeofenceMeters
        ? ProximityBand.approaching
        : ProximityBand.far;

    return ContextSnapshot(
      distanceMeters: distance,
      estimatedTravelMinutes: travelMinutes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      safetyBufferMinutes: safetyBufferMinutes,
      proximity: proximity,
      shouldLeaveNow:
          travelMinutes + safetyBufferMinutes >= estimatedWaitMinutes,
      recordedAt: location.recordedAt,
    );
  }

  static double distanceBetween(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _radians(latitude2 - latitude1);
    final longitudeDelta = _radians(longitude2 - longitude1);
    final firstLatitude = _radians(latitude1);
    final secondLatitude = _radians(latitude2);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(firstLatitude) *
            math.cos(secondLatitude) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
