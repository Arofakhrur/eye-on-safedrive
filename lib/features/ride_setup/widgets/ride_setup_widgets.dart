import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/constants/app_constants.dart';
import 'package:eyeon/features/monitoring/widgets/destination_search_sheet.dart';
import 'package:eyeon/features/ride_setup/logic/ride_setup_controller.dart';

class RideSetupMap extends StatelessWidget {
  final RideSetupController controller;
  final MapController mapController;

  const RideSetupMap({
    super.key,
    required this.controller,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.currentLatLng == null) {
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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: controller.currentLatLng!,
        initialZoom: 16.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          controller.setMapReady(true);
          mapController.move(controller.currentLatLng!, 16.0);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppUrls.osmTileUrl,
          userAgentPackageName: AppUrls.userAgent,
          maxZoom: 19,
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: controller.currentLatLng!,
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
                      border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.87), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (controller.destination != null)
              Marker(
                point: controller.destination!,
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
        if (controller.osrmRoute.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: controller.osrmRoute,
                color: AppColors.primary.withValues(alpha: 0.7),
                strokeWidth: 4.0,
              ),
            ],
          )
        else if (controller.destination != null && controller.currentLatLng != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [controller.currentLatLng!, controller.destination!],
                color: AppColors.primary.withValues(alpha: 0.7),
                strokeWidth: 4.0,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
      ],
    );
  }
}

class RideSetupBackButton extends StatelessWidget {
  const RideSetupBackButton({super.key});

  @override
  Widget build(BuildContext context) {
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
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 6),
            Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RideSetupBottomSheet extends StatelessWidget {
  final RideSetupController controller;
  final double bottomPadding;

  const RideSetupBottomSheet({
    super.key,
    required this.controller,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Mau kemana hari ini?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Lokasi Awal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textPrimary.withValues(alpha: 0.45),
              ),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LocationField(
              icon: Icons.my_location_rounded,
              text: controller.isLoadingLocation
                  ? 'Mencari lokasi...'
                  : controller.startAddressName,
              isLoading: controller.isLoadingLocation,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LocationField(
              icon: Icons.search_rounded,
              text: controller.destinationName ?? 'Pilih Tujuan',
              isPlaceholder: controller.destinationName == null,
              onTap: () {
                DestinationSearchSheet.show(
                  context,
                  onSelected: controller.setDestination,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
            child: MulaiButton(
              isReady: controller.destination != null && controller.currentLatLng != null,
              onTap: () => controller.onMulai(context),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationField extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLoading;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  const LocationField({
    super.key,
    required this.icon,
    required this.text,
    this.isLoading = false,
    this.isPlaceholder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon, color: AppColors.textPrimary.withValues(alpha: 0.87), size: 18),
            ),
            SizedBox(width: 12),
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
                            color: AppColors.textPrimary.withValues(alpha: 0.38),
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
                        color: isPlaceholder ? AppColors.textPrimary.withValues(alpha: 0.38) : AppColors.textPrimary.withValues(alpha: 0.87),
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
}

class MulaiButton extends StatelessWidget {
  final bool isReady;
  final VoidCallback onTap;

  const MulaiButton({
    super.key,
    required this.isReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                    offset: Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mulai Perjalanan',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
