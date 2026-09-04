import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/domain/context_snapshot.dart';
import 'package:queueless/domain/venue_context.dart';
import 'package:queueless/services/context_engine.dart';

void main() {
  const venue = VenueContext(
    id: 'venue',
    name: 'Test venue',
    address: 'Test address',
    latitude: 16.8409,
    longitude: 96.1735,
    averageTurnoverMinutes: 5,
    outerGeofenceMeters: 800,
    arrivalGeofenceMeters: 100,
  );

  test('classifies a customer inside the arrival boundary as near', () {
    const engine = ContextEngine();
    final snapshot = engine.evaluate(
      location: DeviceLocation(
        latitude: 16.8409,
        longitude: 96.1735,
        accuracyMeters: 5,
        recordedAt: DateTime.utc(2026, 8, 14),
      ),
      venue: venue,
      estimatedWaitMinutes: 12,
    );

    expect(snapshot.proximity, ProximityBand.near);
    expect(snapshot.distanceMeters, lessThan(1));
  });

  test('recommends leaving when travel plus buffer reaches wait time', () {
    const engine = ContextEngine(
      travelMetersPerMinute: 80,
      safetyBufferMinutes: 5,
    );
    final snapshot = engine.evaluate(
      location: DeviceLocation(
        latitude: 16.8309,
        longitude: 96.1735,
        accuracyMeters: 10,
        recordedAt: DateTime.utc(2026, 8, 14),
      ),
      venue: venue,
      estimatedWaitMinutes: 15,
    );

    expect(snapshot.estimatedTravelMinutes, greaterThanOrEqualTo(13));
    expect(snapshot.shouldLeaveNow, isTrue);
    expect(snapshot.proximity, ProximityBand.far);
  });
}
