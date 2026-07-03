import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/core/utils/notification_helper.dart';
import 'package:eyeon/features/monitoring/views/monitoring_screen.dart';

class RideSetupController extends ChangeNotifier {
  LatLng? currentLatLng;
  String startAddressName = 'Mencari lokasi...';
  bool isLoadingLocation = true;

  LatLng? destination;
  String? destinationName;

  bool isMapReady = false;

  void setMapReady(bool ready) {
    isMapReady = ready;
    notifyListeners();
  }

  void setDestination(LatLng? dest, String? name) {
    destination = dest;
    destinationName = name;
    notifyListeners();
  }

  Future<void> fetchCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      currentLatLng = latLng;
      isLoadingLocation = false;
      notifyListeners();

      await reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      startAddressName = 'Lokasi tidak ditemukan';
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(AppUrls.nominatimReverseUrl(lat, lon));
      final response = await http.get(
        url,
        headers: {'User-Agent': AppUrls.userAgent},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] ?? '';
        final parts = displayName.toString().split(',');
        final shortName = parts.length >= 2
            ? '${parts[0].trim()}, ${parts[1].trim()}'
            : parts[0].trim();

        startAddressName = shortName.isNotEmpty ? shortName : 'Lokasi saat ini';
        notifyListeners();
      }
    } catch (_) {
      startAddressName = 'Lokasi saat ini';
      notifyListeners();
    }
  }

  void onMulai(BuildContext context) {
    if (destination == null || currentLatLng == null) {
      NotificationHelper.showTop(
        context,
        message: currentLatLng == null
            ? 'Menunggu lokasi GPS...'
            : 'Silakan tentukan titik akhir terlebih dahulu.',
        type: NotificationType.warning,
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MonitoringScreen(
          destination: destination,
          destinationName: destinationName,
        ),
      ),
    );
  }
}
