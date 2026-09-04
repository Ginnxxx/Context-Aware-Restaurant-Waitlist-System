enum ProximityBand { far, approaching, near }

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
}

class ContextSnapshot {
  const ContextSnapshot({
    required this.distanceMeters,
    required this.estimatedTravelMinutes,
    required this.estimatedWaitMinutes,
    required this.safetyBufferMinutes,
    required this.proximity,
    required this.shouldLeaveNow,
    required this.recordedAt,
  });

  final double distanceMeters;
  final int estimatedTravelMinutes;
  final int estimatedWaitMinutes;
  final int safetyBufferMinutes;
  final ProximityBand proximity;
  final bool shouldLeaveNow;
  final DateTime recordedAt;

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
