import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/app_theme.dart';
import '../../domain/context_snapshot.dart';
import '../../domain/venue_context.dart';
import '../screens/full_screen_map_screen.dart';

class GeofenceMapCard extends StatefulWidget {
  const GeofenceMapCard({
    super.key,
    required this.venue,
    this.customerLocation,
    this.contextSnapshot,
    this.onRouteCalculated,
    this.onShowQr,
  });

  final VenueContext venue;
  final DeviceLocation? customerLocation;
  final ContextSnapshot? contextSnapshot;
  final void Function(double roadDistanceMeters, int roadTravelMinutes)?
      onRouteCalculated;
  final VoidCallback? onShowQr;

  @override
  State<GeofenceMapCard> createState() => _GeofenceMapCardState();
}

class _GeofenceMapCardState extends State<GeofenceMapCard> {
  final MapController _mapController = MapController();
  TravelMode _travelMode = TravelMode.drive;
  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _fetchingRoute = false;
  LatLng? _lastFetchedPos;

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
    _fetchRoadRoute();
  }

  @override
  void didUpdateWidget(covariant GeofenceMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerLocation?.latitude !=
            widget.customerLocation?.latitude ||
        oldWidget.customerLocation?.longitude !=
            widget.customerLocation?.longitude ||
        oldWidget.venue.latitude != widget.venue.latitude ||
        oldWidget.venue.longitude != widget.venue.longitude) {
      _fetchRoadRoute();
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
    }
  }

  Future<void> _fetchRoadRoute() async {
    final customer = _customerLatLng;
    if (customer == null) return;

    if (_lastFetchedPos != null) {
      const distanceCalc = Distance();
      final moved =
          distanceCalc.as(LengthUnit.Meter, _lastFetchedPos!, customer);
      if (moved < 15 && _routePoints.isNotEmpty) return;
    }

    _lastFetchedPos = customer;
    _fetchingRoute = true;

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
          padding: const EdgeInsets.fromLTRB(30, 50, 30, 50),
          maxZoom: 16,
        ),
      );
    } else {
      _mapController.move(_venueLatLng, 15.0);
    }
  }

  void _openFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenMapScreen(
          venue: widget.venue,
          customerLocation: widget.customerLocation,
          contextSnapshot: widget.contextSnapshot,
          initialTravelMode: _travelMode,
          onRouteCalculated: widget.onRouteCalculated,
          onShowQr: widget.onShowQr,
        ),
      ),
    );
  }

  String _formatRouteSummary() {
    if (_routeDistanceMeters != null && _routeDurationSeconds != null) {
      final km = (_routeDistanceMeters! / 1000).toStringAsFixed(1);
      final mins = (_routeDurationSeconds! / 60).ceil();
      final modeStr = _travelMode == TravelMode.drive ? 'drive' : 'walk';
      return '$km km • ~$mins min $modeStr';
    }
    return 'Live Route Radar';
  }

  @override
  Widget build(BuildContext context) {
    final customerPos = _customerLatLng;
    final outerRadius = widget.venue.outerGeofenceMeters.toDouble();
    final arrivalRadius = widget.venue.arrivalGeofenceMeters.toDouble();

    final activeRoute = _routePoints.isNotEmpty
        ? _routePoints
        : (customerPos != null ? [customerPos, _venueLatLng] : <LatLng>[]);

    return Container(
      height: 310,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
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
                    CircleMarker(
                      point: _venueLatLng,
                      radius: outerRadius,
                      useRadiusInMeter: true,
                      color: AppColors.amber.withValues(alpha: .12),
                      borderColor: AppColors.amber,
                      borderStrokeWidth: 1.8,
                    ),
                    CircleMarker(
                      point: _venueLatLng,
                      radius: arrivalRadius,
                      useRadiusInMeter: true,
                      color: AppColors.mint.withValues(alpha: .4),
                      borderColor: AppColors.forest,
                      borderStrokeWidth: 2.2,
                    ),
                  ],
                ),
                if (activeRoute.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: activeRoute,
                        color: AppColors.forest.withValues(alpha: .22),
                        strokeWidth: 8.0,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: activeRoute,
                        color: AppColors.forest,
                        strokeWidth: 3.8,
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
                    Marker(
                      point: _venueLatLng,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.forest.withValues(alpha: .4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: AppColors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    if (customerPos != null)
                      Marker(
                        point: customerPos,
                        width: 42,
                        height: 42,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.coral.withValues(alpha: .5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _travelMode == TravelMode.drive
                                ? Icons.directions_car_rounded
                                : Icons.directions_walk_rounded,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Top Header: Route summary & Walk/Drive toggle + Expand button
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: .08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _travelMode == TravelMode.drive
                                ? Icons.directions_car_rounded
                                : Icons.directions_walk_rounded,
                            color: AppColors.forest,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatRouteSummary(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (_fetchingRoute)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Travel Mode Selector (Drive / Walk)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: .08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modeIconBtn(TravelMode.drive),
                        _modeIconBtn(TravelMode.walk),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand Full Screen Button
                  Material(
                    color: AppColors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(14),
                    elevation: 1,
                    child: InkWell(
                      onTap: _openFullScreenMap,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.fullscreen_rounded,
                          color: AppColors.forest,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recenter Control Button
            Positioned(
              bottom: 48,
              right: 12,
              child: Material(
                color: AppColors.white.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(12),
                elevation: 2,
                child: InkWell(
                  onTap: _recenter,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Legend Bar
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.line.withValues(alpha: .6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendDot(
                      color: AppColors.amber,
                      label: 'Approach: ${widget.venue.outerGeofenceMeters}m',
                    ),
                    Container(height: 12, width: 1, color: AppColors.line),
                    _legendDot(
                      color: AppColors.forest,
                      label: 'Arrival: ${widget.venue.arrivalGeofenceMeters}m',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeIconBtn(TravelMode mode) {
    final isSelected = _travelMode == mode;
    return InkWell(
      onTap: () {
        if (_travelMode != mode) {
          setState(() {
            _travelMode = mode;
            _lastFetchedPos = null; // force re-query
          });
          _fetchRoadRoute();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          mode.icon,
          size: 16,
          color: isSelected ? AppColors.white : AppColors.ink,
        ),
      ),
    );
  }

  Widget _legendDot({required Color color, required String label}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}
