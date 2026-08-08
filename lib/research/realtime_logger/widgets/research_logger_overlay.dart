import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eyeon/research/realtime_logger/services/research_logger_service.dart';
import 'package:eyeon/research/realtime_logger/models/research_event_model.dart';

/// Floating read-only scoreboard yang tampil di atas [MonitoringScreen] saat ride aktif.
///
/// Menampilkan klasifikasi TP/FP/TN/FN secara real-time berdasarkan
/// deteksi EAR otomatis — TANPA interaksi manual dari pengemudi.
///
/// - Blink normal (EAR < threshold < 500ms) → TN otomatis
/// - Sustained close (EAR < threshold ≥ 500ms) → drowsy candidate
/// - Alarm saat sustained close → TP
/// - Alarm tanpa sustained close → FP (false alarm)
/// - Sustained close tanpa alarm → FN
class ResearchLoggerOverlay extends StatelessWidget {
  final ResearchLoggerService logger;

  const ResearchLoggerOverlay({super.key, required this.logger});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: logger,
      builder: (context, _) {
        return Positioned(
          bottom: 185, // di atas monitoring bottom bar & stop button
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildScoreboard(),
              if (logger.events.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildRecentEventsFeed(),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Scoreboard ─────────────────────────────────────────────────────────────

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Label
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🔬 AUTO LOG',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${logger.totalBlinks} kedip',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white30,
                  fontSize: 8,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const _VerticalDivider(),
          const SizedBox(width: 12),
          // TP/FP/TN/FN
          _ScoreChip(label: 'TP', value: logger.tp, color: const Color(0xFF4CAF50)),
          const SizedBox(width: 10),
          _ScoreChip(label: 'FP', value: logger.fp, color: const Color(0xFFEF5350)),
          const SizedBox(width: 10),
          _ScoreChip(label: 'TN', value: logger.tn, color: const Color(0xFF42A5F5)),
          const SizedBox(width: 10),
          _ScoreChip(label: 'FN', value: logger.fn, color: const Color(0xFFFF9800)),
          const Spacer(),
          const _VerticalDivider(),
          const SizedBox(width: 8),
          // Precision / Recall / F1
          _MetricBadge(
            label: 'P',
            value: '${(logger.precision * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(width: 5),
          _MetricBadge(
            label: 'R',
            value: '${(logger.recall * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(width: 5),
          _MetricBadge(
            label: 'F1',
            value: '${(logger.f1Score * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }

  // ── Recent Events Feed ─────────────────────────────────────────────────────

  Widget _buildRecentEventsFeed() {
    final recent = logger.events.reversed.take(4).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVENT TERBARU',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white24,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          ...recent.map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

// ── Sub-Widgets ────────────────────────────────────────────────────────────────

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white12,
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScoreChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: color.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final ResearchEventModel event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = _colorForOutcome(event.classifiedAs);
    final timeSec = (event.videoTimestampMs / 1000.0).toStringAsFixed(1);
    final isAlarm = event.eventType == ResearchEventType.alarmTriggered;
    final isBlink = event.eventType == ResearchEventType.normalBlink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          // Waktu relatif
          SizedBox(
            width: 38,
            child: Text(
              '${timeSec}s',
              style: GoogleFonts.sourceCodePro(
                color: Colors.white30,
                fontSize: 9,
              ),
            ),
          ),
          // Icon singkat
          Text(
            isBlink ? '👁️' : isAlarm ? '🔔' : '💤',
            style: const TextStyle(fontSize: 9),
          ),
          const SizedBox(width: 4),
          // Label event
          Expanded(
            child: Text(
              _eventLabel(event),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white60,
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge klasifikasi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.classifiedAs.label,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
            ),
          ),
          // Latency alarm jika ada
          if (event.alarmLatencyMs != null) ...[
            const SizedBox(width: 4),
            Text(
              '${event.alarmLatencyMs}ms',
              style: GoogleFonts.sourceCodePro(
                color: Colors.white24,
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _eventLabel(ResearchEventModel event) {
    switch (event.eventType) {
      case ResearchEventType.normalBlink:
        return 'Kedip normal${event.note != null ? " (${event.note})" : ""}';
      case ResearchEventType.eyeCloseStart:
        return 'Mata tutup (drowsy)';
      case ResearchEventType.eyeOpen:
        return 'Mata buka';
      case ResearchEventType.alarmTriggered:
        return 'Alarm berbunyi';
      case ResearchEventType.alarmStopped:
        return 'Alarm berhenti';
      case ResearchEventType.speedGateRejected:
        return 'Speed-Gate: bukan kecelakaan';
    }
  }

  Color _colorForOutcome(OutcomeClass outcome) {
    switch (outcome) {
      case OutcomeClass.tp:
        return const Color(0xFF4CAF50);
      case OutcomeClass.fp:
        return const Color(0xFFEF5350);
      case OutcomeClass.tn:
        return const Color(0xFF42A5F5);
      case OutcomeClass.fn:
        return const Color(0xFFFF9800);
      case OutcomeClass.pending:
        return Colors.yellow;
      case OutcomeClass.notApplicable:
        return Colors.white30;
    }
  }
}
