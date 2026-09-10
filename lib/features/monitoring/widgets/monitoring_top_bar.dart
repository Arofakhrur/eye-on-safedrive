import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/features/monitoring/logic/monitoring_controller.dart';

class MonitoringTopBar extends StatelessWidget {
  final bool isDrowsy;
  final bool isAccident;
  final double currentSpeed;
  final String formattedDuration;
  final double totalDistance;
  final LandmarkMode landmarkMode;
  final VoidCallback onToggleFaceMesh;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;

  const MonitoringTopBar({
    super.key,
    required this.isDrowsy,
    required this.isAccident,
    required this.currentSpeed,
    required this.formattedDuration,
    required this.totalDistance,
    required this.landmarkMode,
    required this.onToggleFaceMesh,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    bool isStopped = currentSpeed < 1.0;
    
    // Status text logic
    String statusText = 'DRIVING';
    Color statusColor = AppColors.primary; // Neon green
    
    if (isAccident) {
      statusText = 'SOS ALERT';
      statusColor = Colors.redAccent;
    } else if (isDrowsy) {
      statusText = 'DROWSY!';
      statusColor = Colors.orangeAccent;
    } else if (isStopped) {
      statusText = 'STOPPED';
      statusColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background capsule
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Toggle Landmark Mode (3 States: Face Only -> Face + Eyes -> Off)
          GestureDetector(
            onTap: onToggleFaceMesh,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getLandmarkBgColor(),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getLandmarkIcon(),
                color: _getLandmarkColor(),
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 2. Information
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Text(
                statusText,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.background,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 16),
              _buildCompactMetric(Icons.access_time_rounded, formattedDuration),
              const SizedBox(width: 12),
              _buildCompactMetric(Icons.route_rounded, '${totalDistance.toStringAsFixed(1)} km'),
            ],
          ),
          
          const SizedBox(width: 12),

          // 3. Toggle Fullscreen
          GestureDetector(
            onTap: onToggleFullScreen,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFullScreen ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                color: AppColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textInverse.withValues(alpha: 0.5), size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.background,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  IconData _getLandmarkIcon() {
    switch (landmarkMode) {
      case LandmarkMode.off:
        return Icons.face_unlock_rounded;
      case LandmarkMode.faceOnly:
        return Icons.face_retouching_natural_rounded;
      case LandmarkMode.all:
        return Icons.remove_red_eye_rounded;
    }
  }

  Color _getLandmarkColor() {
    switch (landmarkMode) {
      case LandmarkMode.off:
        return AppColors.textInverse.withValues(alpha: 0.5);
      case LandmarkMode.faceOnly:
        return AppColors.primary; // Neon green
      case LandmarkMode.all:
        return const Color(0xFF00E5FF); // Bright cyan (matches eye landmark highlight)
    }
  }

  Color _getLandmarkBgColor() {
    switch (landmarkMode) {
      case LandmarkMode.off:
        return AppColors.background.withValues(alpha: 0.15);
      case LandmarkMode.faceOnly:
        return AppColors.primary.withValues(alpha: 0.2);
      case LandmarkMode.all:
        return const Color(0xFF00E5FF).withValues(alpha: 0.2);
    }
  }
}
