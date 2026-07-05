import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/theme/app_theme.dart';

/// A widget that displays a live map using flutter_map and OpenStreetMap.
/// It tracks the user's current location from a Position stream.
class LiveMapWidget extends StatefulWidget {
  final Stream<Position> positionStream;
  final Position? initialPosition;
  final LatLng? destination;

  const LiveMapWidget({
    super.key,
    required this.positionStream,
    this.initialPosition,
    this.destination,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _currentLatLng;
  bool _isMapReady = false;
  final List<LatLng> _routeHistory = [];
  List<LatLng> _osrmRoute = [];
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentLatLng = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
      if (widget.destination != null && _currentLatLng != null) {
        _fetchRoute(_currentLatLng!, widget.destination!);
      }
    }
    
    _positionSub = widget.positionStream.listen((Position position) {
      if (!mounted) return;
      final newLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLatLng = newLatLng;
        _routeHistory.add(newLatLng);
      });
      if (_isMapReady) {
        _mapController.move(newLatLng, 16.0);
      }
    });
  }

  @override
  void didUpdateWidget(LiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination &&
        widget.destination != null &&
        _currentLatLng != null) {
      _fetchRoute(_currentLatLng!, widget.destination!);
    } else if (widget.destination == null) {
      setState(() {
        _osrmRoute = [];
      });
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng dest) async {
    if (_isFetchingRoute) return;
    setState(() => _isFetchingRoute = true);
    
    try {
      final url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          final List<LatLng> polylinePoints = coordinates
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();
              
          if (mounted) {
            setState(() {
              _osrmRoute = polylinePoints;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM route: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingRoute = false);
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLatLng == null) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Mencari sinyal GPS...',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLatLng!,
        initialZoom: 16.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _isMapReady = true;
          _mapController.move(_currentLatLng!, 16.0);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppUrls.osmTileUrl,
          userAgentPackageName: 'com.eyeon.safedrive',
          maxZoom: 19,
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLatLng!,
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.destination != null)
              Marker(
                point: widget.destination!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
          ],
        ),
        if (_routeHistory.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routeHistory,
                color: AppColors.primary,
                strokeWidth: 4.0,
              ),
            ],
          ),
        if (widget.destination != null && _osrmRoute.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _osrmRoute,
                color: Colors.blue.withValues(alpha: 0.7),
                strokeWidth: 4.0,
              ),
            ],
          )
        else if (widget.destination != null && _currentLatLng != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_currentLatLng!, widget.destination!],
                color: Colors.blue.withValues(alpha: 0.7),
                strokeWidth: 4.0,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
      ],
    );
  }
}
