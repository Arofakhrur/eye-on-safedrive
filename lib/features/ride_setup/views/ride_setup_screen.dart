import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/features/monitoring/views/monitoring_screen.dart';
import 'package:eyeon/features/monitoring/widgets/destination_search_sheet.dart';

class RideSetupScreen extends StatefulWidget {
  const RideSetupScreen({super.key});

  @override
  State<RideSetupScreen> createState() => _RideSetupScreenState();
}

class _RideSetupScreenState extends State<RideSetupScreen> {
  LatLng? _currentLatLng;
  String _startAddressName = 'Mencari lokasi...';
  bool _isLoadingLocation = true;

  LatLng? _destination;
  String? _destinationName;

  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLatLng = latLng;
          _isLoadingLocation = false;
        });

        if (_isMapReady) {
          _mapController.move(latLng, 16.0);
        }
      }

      // Reverse geocode to get address name
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        setState(() {
          _startAddressName = 'Lokasi tidak ditemukan';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EyeOnSafeDrive/1.0'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] ?? '';
        // Take first 2 parts for a concise name
        final parts = displayName.toString().split(',');
        final shortName = parts.length >= 2
            ? '${parts[0].trim()}, ${parts[1].trim()}'
            : parts[0].trim();

        setState(() {
          _startAddressName = shortName.isNotEmpty
              ? shortName
              : 'Lokasi saat ini';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _startAddressName = 'Lokasi saat ini');
      }
    }
  }

  void _openDestinationSearch() {
    DestinationSearchSheet.show(
      context,
      onSelected: (dest, name) {
        setState(() {
          _destination = dest;
          _destinationName = name;
        });
      },
    );
  }

  void _onMulai() {
    if (_destination == null || _currentLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentLatLng == null
                ? 'Menunggu lokasi GPS...'
                : 'Silakan tentukan titik akhir terlebih dahulu.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MonitoringScreen(
          destination: _destination,
          destinationName: _destinationName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Map Background ──
          Positioned.fill(child: _buildMap()),

          // ── Back Button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: _buildBackButton(),
          ),

          // ── Bottom Sheet ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(bottomPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_currentLatLng == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 12),
              Text(
                'Mencari lokasi GPS...',
                style: TextStyle(color: Colors.black54, fontSize: 13),
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
        ),
        MarkerLayer(
          markers: [
            // Current location marker
            Marker(
              point: _currentLatLng!,
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Destination marker
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 44,
                height: 44,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 44,
                ),
              ),
          ],
        ),
        // Route line
        if (_destination != null && _currentLatLng != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_currentLatLng!, _destination!],
                color: AppColors.primary.withValues(alpha: 0.7),
                strokeWidth: 4.0,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
            const SizedBox(width: 6),
            Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(double bottomPadding) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Setup Perjalanan mu dulu!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Lokasi awal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Titik Saat Ini ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildLocationField(
              icon: Icons.my_location_rounded,
              text: _isLoadingLocation
                  ? 'Mencari lokasi...'
                  : _startAddressName,
              isLoading: _isLoadingLocation,
              onTap: null, // read-only for now
            ),
          ),
          const SizedBox(height: 12),

          // ── Titik Akhir ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildLocationField(
              icon: Icons.search_rounded,
              text: _destinationName ?? 'Titik Akhir',
              isPlaceholder: _destinationName == null,
              onTap: _openDestinationSearch,
            ),
          ),
          const SizedBox(height: 24),

          // ── Tombol Mulai ──
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
            child: _buildMulaiButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required String text,
    bool isLoading = false,
    bool isPlaceholder = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isLoading
                  ? Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: isPlaceholder
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: isPlaceholder ? Colors.black38 : Colors.black87,
                      ),
                    ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMulaiButton() {
    final isReady = _destination != null && _currentLatLng != null;

    return GestureDetector(
      onTap: _onMulai,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isReady
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mulai',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
