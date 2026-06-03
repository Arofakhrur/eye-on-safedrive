import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/core/services/safety_score_service.dart';

/// A premium circular progress card displaying the user's Safety Score.
///
/// Features:
/// - Animated gradient arc (red→yellow→green based on score)
/// - Count-up animation on first load
/// - Score breakdown labels
class SafetyScoreCard extends StatefulWidget {
  const SafetyScoreCard({super.key});

  @override
  State<SafetyScoreCard> createState() => _SafetyScoreCardState();
}

class _SafetyScoreCardState extends State<SafetyScoreCard>
    with SingleTickerProviderStateMixin {
  int _score = 0;
  String _label = '';
  Map<String, dynamic> _breakdown = {};
  bool _isLoading = true;

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _loadScore();
  }

  Future<void> _loadScore() async {
    try {
      final breakdown = await SafetyScoreService().getScoreBreakdown();
      if (mounted) {
        setState(() {
          _breakdown = breakdown;
          _score = breakdown['score'] as int;
          _label = SafetyScoreService.getScoreLabel(_score);
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _score = 100;
          _label = 'Sangat Aman';
          _isLoading = false;
        });
        _animController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFD7F454);
    if (score >= 40) return const Color(0xFFFFB74D);
    if (score >= 20) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(_score);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFD7F454)),
              ),
            )
          : Column(
              children: [
                // Score circle
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final animatedScore = (_score * _animation.value).toInt();
                    return SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: _ScoreArcPainter(
                          progress: _animation.value * (_score / 100.0),
                          color: scoreColor,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$animatedScore',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SAFETY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white38,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMiniStat(
                      '${_breakdown['totalRides'] ?? 0}',
                      'Perjalanan',
                      Icons.route_rounded,
                    ),
                    _buildMiniStat(
                      '${_breakdown['cleanRides'] ?? 0}',
                      'Aman',
                      Icons.check_circle_outline_rounded,
                    ),
                    _buildMiniStat(
                      '${_breakdown['totalMicrosleepAlerts'] ?? 0}',
                      'Peringatan',
                      Icons.warning_amber_rounded,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildMiniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white24, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: Colors.white38,
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
    final radius = size.width / 2 - 10;

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
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
        ..shader = SweepGradient(
          startAngle: -pi / 2 - pi * 0.75,
          endAngle: -pi / 2 + pi * 0.75,
          colors: [
            color.withValues(alpha: 0.4),
            color,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 - pi * 0.75,
        pi * 1.5 * progress,
        false,
        scorePaint,
      );

      // Glow dot at end
      final angle = -pi / 2 - pi * 0.75 + pi * 1.5 * progress;
      final dotCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawCircle(
        dotCenter,
        5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        dotCenter,
        10,
        Paint()..color = color.withValues(alpha: 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.progress != progress || old.color != color;
}
