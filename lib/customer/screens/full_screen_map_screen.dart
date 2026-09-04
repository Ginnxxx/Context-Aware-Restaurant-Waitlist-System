import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/app_theme.dart';
import '../../domain/context_snapshot.dart';
import '../../domain/venue_context.dart';

enum TravelMode {
  drive('driving', 'Drive', Icons.directions_car_rounded),
  walk('foot', 'Walk', Icons.directions_walk_rounded);

  const TravelMode(this.osrmProfile, this.label, this.icon);
  final String osrmProfile;
  final String label;
  final IconData icon;
}

class FullScreenMapScreen extends StatefulWidget {
  const FullScreenMapScreen({
    super.key,
    required this.venue,
    this.customerLocation,
    this.contextSnapshot,
    this.initialTravelMode = TravelMode.drive,
    this.onRouteCalculated,
    this.onShowQr,
  });

  final VenueContext venue;
  final DeviceLocation? customerLocation;
  final ContextSnapshot? contextSnapshot;
  final TravelMode initialTravelMode;
  final void Function(double roadDistanceMeters, int roadTravelMinutes)?
      onRouteCalculated;
  final VoidCallback? onShowQr;

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  final MapController _mapController = MapController();
  late TravelMode _travelMode;
  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _fetchingRoute = false;

  LatLng get _venueLatLng =>
      LatLng(widget.venue.latitude, widget.venue.longitude);

  LatLng? get _customerLatLng => widget.customerLocation != null
      ? LatLng(
          widget.customerLocation!.latitude,
          widget.customerLocation!.longitude,
        )
      : null;

  @override
  void initState() {
    super.initState();
    _travelMode = widget.initialTravelMode;
    _fetchRoadRoute();
  }

  Future<void> _fetchRoadRoute() async {
    final customer = _customerLatLng;
    if (customer == null) return;

    setState(() => _fetchingRoute = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${customer.longitude},${customer.latitude};'
        '${_venueLatLng.longitude},${_venueLatLng.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0] as Map<String, dynamic>;
          final coords =
              firstRoute['geometry']['coordinates'] as List<dynamic>;
          final distance = (firstRoute['distance'] as num?)?.toDouble();
          final rawDuration = (firstRoute['duration'] as num?)?.toDouble();

          // If walking, calculate pedestrian duration (80 m/min = 4.8 km/h)
          final duration = _travelMode == TravelMode.walk && distance != null
              ? (distance / 80.0) * 60.0
              : rawDuration;

          final parsedPoints = coords.map((c) {
            final pair = c as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList();

          if (mounted) {
            setState(() {
              _routePoints = parsedPoints;
              _routeDistanceMeters = distance;
              _routeDurationSeconds = duration;
              _fetchingRoute = false;
            });
            if (distance != null && duration != null) {
              widget.onRouteCalculated?.call(
                distance,
                (duration / 60).ceil(),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = [customer, _venueLatLng];
        _fetchingRoute = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
    }
  }

  void _recenter() {
    if (_customerLatLng != null) {
      final points = _routePoints.isNotEmpty
          ? [_venueLatLng, _customerLatLng!, ..._routePoints]
          : [_venueLatLng, _customerLatLng!];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 140),
          maxZoom: 16,
        ),
      );
    } else {
      _mapController.move(_venueLatLng, 15.0);
    }
  }

  String _formatRouteSummary() {
    if (_routeDistanceMeters != null && _routeDurationSeconds != null) {
      final km = (_routeDistanceMeters! / 1000).toStringAsFixed(1);
      final mins = (_routeDurationSeconds! / 60).ceil();
      final modeStr = _travelMode == TravelMode.drive ? 'drive' : 'walk';
      return '$km km • ~$mins min $modeStr';
    }
    return 'Turn-by-Turn Navigation';
  }

  @override
  Widget build(BuildContext context) {
    final customerPos = _customerLatLng;
    final outerRadius = widget.venue.outerGeofenceMeters.toDouble();
    final arrivalRadius = widget.venue.arrivalGeofenceMeters.toDouble();
    final activeRoute = _routePoints.isNotEmpty
        ? _routePoints
        : (customerPos != null ? [customerPos, _venueLatLng] : <LatLng>[]);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: customerPos ?? _venueLatLng,
              initialZoom: customerPos != null ? 14.5 : 15.0,
              minZoom: 9.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hpc8115.queueless',
              ),
              CircleLayer(
                circles: [
                  // Outer Geofence Ring (800m)
                  CircleMarker(
                    point: _venueLatLng,
                    radius: outerRadius,
                    useRadiusInMeter: true,
                    color: AppColors.amber.withValues(alpha: .12),
                    borderColor: AppColors.amber,
                    borderStrokeWidth: 2.0,
                  ),
                  // Arrival Geofence Ring (100m)
                  CircleMarker(
                    point: _venueLatLng,
                    radius: arrivalRadius,
                    useRadiusInMeter: true,
                    color: AppColors.mint.withValues(alpha: .45),
                    borderColor: AppColors.forest,
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),
              if (activeRoute.length >= 2)
                PolylineLayer(
                  polylines: [
                    // Glow / Road Shadow
                    Polyline(
                      points: activeRoute,
                      color: AppColors.forest.withValues(alpha: .24),
                      strokeWidth: 9.0,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    // Core Road Route
                    Polyline(
                      points: activeRoute,
                      color: AppColors.forest,
                      strokeWidth: 4.2,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                      pattern: _travelMode == TravelMode.walk
                          ? const StrokePattern.dotted(spacingFactor: 1.5)
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Venue Marker
                  Marker(
                    point: _venueLatLng,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.forest.withValues(alpha: .4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Customer Location Marker
                  if (customerPos != null)
                    Marker(
                      point: customerPos,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.coral.withValues(alpha: .5),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _travelMode == TravelMode.drive
                              ? Icons.directions_car_rounded
                              : Icons.directions_walk_rounded,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top Floating Navigation Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.cream,
                              foregroundColor: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.venue.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  _formatRouteSummary(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_fetchingRoute)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Walk / Drive Mode Selector
                      Row(
                        children: TravelMode.values.map((mode) {
                          final isSelected = _travelMode == mode;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      mode.icon,
                                      size: 16,
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.ink,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(mode.label),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.forest,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                backgroundColor: AppColors.cream,
                                showCheckmark: false,
                                onSelected: (val) {
                                  if (val && _travelMode != mode) {
                                    setState(() => _travelMode = mode);
                                    _fetchRoadRoute();
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Recenter FAB
          Positioned(
            bottom: 110,
            right: 18,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map_fab',
              onPressed: _recenter,
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.forest,
              elevation: 4,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // Bottom Radar Status Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: .1),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _legendItem(
                            color: AppColors.amber,
                            label: 'Approach: ${widget.venue.outerGeofenceMeters}m',
                          ),
                          const SizedBox(width: 14),
                          _legendItem(
                            color: AppColors.forest,
                            label: 'Arrival: ${widget.venue.arrivalGeofenceMeters}m',
                          ),
                        ],
                      ),
                      if (widget.onShowQr != null)
                        FilledButton.tonalIcon(
                          onPressed: widget.onShowQr,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mint,
                            foregroundColor: AppColors.forest,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text(
                            'QR',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}
