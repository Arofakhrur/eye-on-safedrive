import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class MonitoringStatsBar extends StatelessWidget {
  final bool isDrowsy;
  final bool isAccident;
  final double currentSpeed;
  final Duration rideDuration;
  final double totalDistance;
  final double currentEAR;
  final double currentGForce;
  final String formattedDuration;

  const MonitoringStatsBar({
    super.key,
    required this.isDrowsy,
    required this.isAccident,
    required this.currentSpeed,
    required this.rideDuration,
    required this.totalDistance,
    required this.currentEAR,
    required this.currentGForce,
    required this.formattedDuration,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              // Row 1: Status & Primary Metrics
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDrowsy || isAccident
                          ? Colors.redAccent
                          : const Color(0xFFD7F454),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAccident
                          ? 'SOS ALERT'
                          : isDrowsy
                              ? 'DROWSY!'
                              : currentSpeed < 1.0
                                  ? 'STOPPED'
                                  : 'DRIVING',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _buildCompactMetric(Icons.access_time_rounded, formattedDuration),
                  const SizedBox(width: 12),
                  _buildCompactMetric(Icons.route_rounded, '${totalDistance.toStringAsFixed(1)}km'),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 10),
              // Row 2: Secondary Sensors
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCompactMetric(Icons.speed_rounded, '${currentSpeed.toStringAsFixed(0)} km/h'),
                  _buildCompactMetric(
                    Icons.visibility_rounded, 
                    'EAR: ${currentEAR.toStringAsFixed(2)}',
                    color: currentEAR < 0.25 ? Colors.redAccent : const Color(0xFFD7F454),
                  ),
                  _buildCompactMetric(
                    Icons.sensors_rounded, 
                    'G: ${currentGForce.toStringAsFixed(1)}',
                    color: isAccident ? Colors.redAccent : const Color(0xFFD7F454),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetric(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color?.withValues(alpha: 0.5) ?? Colors.white54, size: 12),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
