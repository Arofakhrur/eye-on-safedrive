import 'package:eyeon/core/theme/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/safety_score_service.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SafetyScoreCard extends StatelessWidget {
  const SafetyScoreCard({super.key});

  Color _getScoreColor(int score) {
    if (score == 0) return Colors.grey.shade400;
    if (score >= 80) return const Color(0xFF00FF00); // Bright Green
    return const Color(0xFFFF4040); // Red/Orange for 1-79
  }

  String _getScoreLabel(int score) {
    if (score == 0) return '-';
    if (score >= 80) return 'SANGAT AMAN';
    return 'AMAN';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: SafetyScoreService().streamScoreBreakdown(),
      builder: (context, snapshot) {
        final isLoading = !snapshot.hasData;
        final breakdown = isLoading 
            ? {'score': 85, 'totalRides': 10, 'cleanRides': 8, 'totalMicrosleepAlerts': 2} 
            : (snapshot.data ?? {});
        final int score = (breakdown['score'] ?? 0) as int;
        
        final scoreColor = _getScoreColor(score);
        final labelText = _getScoreLabel(score);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Skeletonizer(
            enabled: isLoading,
            child: Column(
              children: [
                    // Score circle with overlapping label
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: score.toDouble()),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final animatedScore = value.toInt();
                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: CustomPaint(
                                painter: _ScoreArcPainter(
                                  progress: value / 100.0,
                                  color: scoreColor,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        score == 0 ? '-' : '$animatedScore',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 64,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SAFETY',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary.withValues(alpha: 0.38),
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Overlapping pill label
                            Positioned(
                              bottom: -12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: scoreColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  labelText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 40),

                    // Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMiniStat(
                          '${breakdown['totalRides'] ?? 0}',
                          'Perjalanan',
                          Icons.sync_rounded,
                          Colors.orange,
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade200),
                        _buildMiniStat(
                          '${breakdown['cleanRides'] ?? 0}',
                          'Aman',
                          Icons.check_circle_outline_rounded,
                          Colors.grey.shade400,
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade200),
                        _buildMiniStat(
                          '${breakdown['totalMicrosleepAlerts'] ?? 0}',
                          'Peringatan',
                          Icons.warning_amber_rounded,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppColors.textPrimary.withValues(alpha: 0.38),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the score arc.
class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScoreArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background track (Grey)
    final trackPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 - pi * 0.75,
      pi * 1.5,
      false,
      trackPaint,
    );

    // Score arc
    if (progress > 0) {
      final scorePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 - pi * 0.75,
        pi * 1.5 * progress,
        false,
        scorePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.progress != progress || old.color != color;
}

