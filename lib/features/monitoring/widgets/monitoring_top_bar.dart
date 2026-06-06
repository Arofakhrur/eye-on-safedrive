import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MonitoringTopBar extends StatelessWidget {
  final bool isDrowsy;
  final bool isAccident;
  final double currentSpeed;
  final String formattedDuration;
  final double totalDistance;

  const MonitoringTopBar({
    super.key,
    required this.isDrowsy,
    required this.isAccident,
    required this.currentSpeed,
    required this.formattedDuration,
    required this.totalDistance,
  });

  @override
  Widget build(BuildContext context) {
    bool isStopped = currentSpeed < 1.0;
    
    // Status text logic
    String statusText = 'DRIVING';
    Color statusColor = const Color(0xFFD7F454); // Neon green
    
    if (isAccident) {
      statusText = 'SOS ALERT';
      statusColor = Colors.redAccent;
    } else if (isDrowsy) {
      statusText = 'DROWSY!';
      statusColor = Colors.orangeAccent;
    } else if (isStopped) {
      statusText = 'STOPPED';
      statusColor = const Color(0xFFD7F454);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background capsule
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
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
          const SizedBox(width: 8),
          Text(
            statusText,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Timer
          _buildCompactMetric(Icons.access_time_rounded, formattedDuration),
          
          const SizedBox(width: 16),
          
          // Distance
          _buildCompactMetric(Icons.route_rounded, '${totalDistance.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
