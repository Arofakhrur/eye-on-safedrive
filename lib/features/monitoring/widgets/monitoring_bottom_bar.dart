import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/theme/app_theme.dart';
import 'package:eyeon/core/services/preference_service.dart';

class MonitoringBottomBar extends StatelessWidget {
  final double currentSpeed;
  final double currentEAR;
  final double currentGForce;
  final bool isAccident;

  const MonitoringBottomBar({
    super.key,
    required this.currentSpeed,
    required this.currentEAR,
    required this.currentGForce,
    required this.isAccident,
  });

  @override
  Widget build(BuildContext context) {
    final earThreshold = PreferenceService().earThreshold;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Deep dark background
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.background.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetric(
            Icons.speed_rounded, 
            '${currentSpeed.toStringAsFixed(0)} km/h',
            AppColors.background,
          ),
          _buildMetric(
            Icons.visibility_rounded, 
            'EAR: ${currentEAR.toStringAsFixed(2)}',
            currentEAR > 0 && currentEAR < earThreshold ? Colors.redAccent : AppColors.primary,
          ),
          _buildMetric(
            Icons.sensors_rounded, 
            '${currentGForce.toStringAsFixed(1)} m/s²',
            isAccident ? Colors.redAccent : AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, Color highlightColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: highlightColor.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: highlightColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
