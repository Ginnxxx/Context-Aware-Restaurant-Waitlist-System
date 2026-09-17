class VenueContext {
  const VenueContext({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.averageTurnoverMinutes,
    required this.outerGeofenceMeters,
    required this.arrivalGeofenceMeters,
    this.seatCapacity = 40,
    this.queueOpen = true,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int averageTurnoverMinutes;
  final int outerGeofenceMeters;
  final int arrivalGeofenceMeters;
  final int seatCapacity;
  final bool queueOpen;

  VenueContext copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? averageTurnoverMinutes,
    int? outerGeofenceMeters,
    int? arrivalGeofenceMeters,
    int? seatCapacity,
    bool? queueOpen,
  }) => VenueContext(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    averageTurnoverMinutes:
        averageTurnoverMinutes ?? this.averageTurnoverMinutes,
    outerGeofenceMeters: outerGeofenceMeters ?? this.outerGeofenceMeters,
    arrivalGeofenceMeters: arrivalGeofenceMeters ?? this.arrivalGeofenceMeters,
    seatCapacity: seatCapacity ?? this.seatCapacity,
    queueOpen: queueOpen ?? this.queueOpen,
  );

  factory VenueContext.fromMap(Map<String, dynamic> map) => VenueContext(
    id: map['id'] as String,
    name: map['name'] as String,
    address: map['address'] as String? ?? '',
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    averageTurnoverMinutes: (map['average_turnover_minutes'] as num).toInt(),
    outerGeofenceMeters: (map['outer_geofence_meters'] as num).toInt(),
    arrivalGeofenceMeters: (map['arrival_geofence_meters'] as num).toInt(),
    seatCapacity: (map['seat_capacity'] as num?)?.toInt() ?? 40,
    queueOpen: map['queue_open'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenueContext &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          address == other.address &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          averageTurnoverMinutes == other.averageTurnoverMinutes &&
          outerGeofenceMeters == other.outerGeofenceMeters &&
          arrivalGeofenceMeters == other.arrivalGeofenceMeters &&
          seatCapacity == other.seatCapacity &&
          queueOpen == other.queueOpen;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        address,
        latitude,
        longitude,
        averageTurnoverMinutes,
        outerGeofenceMeters,
        arrivalGeofenceMeters,
        seatCapacity,
        queueOpen,
      );
}
