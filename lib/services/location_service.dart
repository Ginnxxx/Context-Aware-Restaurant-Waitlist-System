import 'package:geolocator/geolocator.dart';

import '../domain/context_snapshot.dart';

enum LocationFailureType {
  servicesDisabled,
  denied,
  deniedForever,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type, this.message);
  final LocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract interface class LocationService {
  Future<void> ensurePermission();
  Stream<DeviceLocation> watchPositions();
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        LocationFailureType.servicesDisabled,
        'Turn on device location services to use smart timing.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureType.deniedForever,
        'Location permission is blocked. Enable it in app settings.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationFailure(
        LocationFailureType.denied,
        'Location permission is needed for leave-now recommendations.',
      );
    }
  }

  @override
  Stream<DeviceLocation> watchPositions() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).map(
        (position) => DeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          recordedAt: position.timestamp,
        ),
      );

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
