import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';

class MonitoringTopBar extends StatelessWidget {
  final bool isDrowsy;
  final bool isAccident;
  final double currentSpeed;
  final String formattedDuration;
  final double totalDistance;
  final bool showFaceMesh;
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
    required this.showFaceMesh,
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
          // 1. Toggle Face Mesh
          GestureDetector(
            onTap: onToggleFaceMesh,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showFaceMesh ? Icons.face_retouching_natural_rounded : Icons.face_unlock_rounded,
                color: showFaceMesh ? AppColors.primary : AppColors.textInverse.withValues(alpha: 0.5),
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
}
