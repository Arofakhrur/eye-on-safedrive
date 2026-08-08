import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:eyeon/research/realtime_logger/models/research_event_model.dart';
import 'package:eyeon/core/services/supabase_service.dart';

/// Service untuk export data penelitian ke CSV dan PDF.
/// Bisa dipanggil dari Activity Screen maupun History Screen.
class ResearchExportService {
  static final ResearchExportService _instance =
      ResearchExportService._internal();
  factory ResearchExportService() => _instance;
  ResearchExportService._internal();

  // ── Export CSV ─────────────────────────────────────────────────────────────

  /// Export semua research events untuk satu ride ke CSV.
  Future<void> exportCsvForRide({
    required String rideId,
    required Map<String, dynamic> rideInfo,
    List<ResearchEventModel>? cachedEvents,
  }) async {
    final events = cachedEvents ??
        await SupabaseService().getResearchEventsForRide(rideId);
    final metrics = await SupabaseService().getEvaluationMetricsForRide(rideId);

    // Jika benar-benar tidak ada data sama sekali → tolak
    if (events.isEmpty && metrics == null) {
      debugPrint('⚠️ [ResearchExport] No research data for ride: $rideId');
      throw Exception(
        'Belum ada data penelitian untuk sesi ini.\n'
        'Pastikan sesi monitoring sudah dijalankan dan tombol Stop ditekan.',
      );
    }

    final buffer = StringBuffer();

    // Header info
    buffer.writeln('# EYE-ON Research Logger — Laporan Evaluasi');
    buffer.writeln('# Ride ID: $rideId');
    buffer.writeln(
        '# Tanggal: ${_formatDate(DateTime.tryParse(rideInfo['start_time']?.toString() ?? '') ?? DateTime.now())}');
    buffer.writeln(
        '# Durasi: ${_formatDuration(rideInfo['start_time']?.toString(), rideInfo['end_time']?.toString())}');
    buffer.writeln(
        '# Jarak: ${((rideInfo['distance'] ?? 0.0) as num).toStringAsFixed(2)} km');
    buffer.writeln('#');

    // Metrics summary (jika tersedia)
    if (metrics != null) {
      buffer.writeln('# === METRIK EVALUASI ===');
      buffer.writeln('# TP,FP,TN,FN,Precision,Recall,F1,Accuracy');
      buffer.writeln(
          '# ${metrics['tp']},${metrics['fp']},${metrics['tn']},${metrics['fn']},'
          '${_pct(metrics['precision_val'])},${_pct(metrics['recall_val'])},'
          '${_pct(metrics['f1_score'])},${_pct(metrics['accuracy'])}');
      buffer.writeln('#');
    } else {
      buffer.writeln('# === METRIK EVALUASI: belum tersedia ===');
      buffer.writeln('#');
    }

    // Events table
    if (events.isNotEmpty) {
      buffer.writeln(ResearchEventModel.csvHeader);
      for (final event in events) {
        buffer.writeln(event.toCsvRow());
      }
    } else {
      buffer.writeln('# Belum ada event log yang tercatat untuk sesi ini.');
    }

    await _shareAsFile(
      content: buffer.toString(),
      fileName:
          'eyeon_research_${rideId.substring(0, 8)}_${_fileTimestamp()}.csv',
      mimeType: 'text/csv',
      subject: 'EYE-ON Research Log — CSV',
    );
  }

  /// Export semua research events untuk semua ride dalam periode tertentu ke CSV.
  Future<void> exportCsvForPeriod({
    required List<Map<String, dynamic>> rideLogs,
    required String periodLabel,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('# EYE-ON Research Logger — Export Periodik: $periodLabel');
    buffer.writeln('# Digenerate: ${_formatDate(DateTime.now())}');
    buffer.writeln('#');

    buffer.writeln(
        'ride_id,tanggal,durasi,jarak_km,TP,FP,TN,FN,Precision,Recall,F1,Accuracy');

    for (final ride in rideLogs) {
      final rideId = ride['id']?.toString() ?? '';
      if (rideId.isEmpty) continue;

      try {
        final metrics =
            await SupabaseService().getEvaluationMetricsForRide(rideId);
        if (metrics == null) continue;

        buffer.writeln([
          rideId,
          _formatDate(DateTime.tryParse(ride['start_time'] ?? '') ?? DateTime.now()),
          _formatDuration(ride['start_time'], ride['end_time']),
          ((ride['distance'] ?? 0.0) as num).toStringAsFixed(2),
          metrics['tp'],
          metrics['fp'],
          metrics['tn'],
          metrics['fn'],
          _pct(metrics['precision_val']),
          _pct(metrics['recall_val']),
          _pct(metrics['f1_score']),
          _pct(metrics['accuracy']),
        ].join(','));
      } catch (_) {
        continue;
      }
    }

    await _shareAsFile(
      content: buffer.toString(),
      fileName: 'eyeon_research_period_${_fileTimestamp()}.csv',
      mimeType: 'text/csv',
      subject: 'EYE-ON Research Log — Periode $periodLabel',
    );
  }

  // ── Export PDF ─────────────────────────────────────────────────────────────

  /// Export laporan PDF untuk satu ride.
  Future<void> exportPdfForRide({
    required String rideId,
    required Map<String, dynamic> rideInfo,
    List<ResearchEventModel>? cachedEvents,
  }) async {
    final events = cachedEvents ??
        await SupabaseService().getResearchEventsForRide(rideId);
    final metrics = await SupabaseService().getEvaluationMetricsForRide(rideId);

    if (events.isEmpty && metrics == null) {
      throw Exception(
        'Belum ada data penelitian untuk sesi ini.\n'
        'Pastikan sesi monitoring sudah dijalankan dan tombol Stop ditekan.',
      );
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(rideId, rideInfo),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          if (metrics != null) ...[
            _buildPdfMetricsSection(metrics),
            pw.SizedBox(height: 20),
          ],
          _buildPdfEventTable(events),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _shareAsFileBytes(
      bytes: bytes,
      fileName:
          'eyeon_research_${rideId.substring(0, 8)}_${_fileTimestamp()}.pdf',
      mimeType: 'application/pdf',
      subject: 'EYE-ON Research Report',
    );
  }

  // ── PDF Builders ───────────────────────────────────────────────────────────

  pw.Widget _buildPdfHeader(
      String rideId, Map<String, dynamic> rideInfo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'EYE-ON! Research Logger',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Laporan Evaluasi Deteksi Microsleep',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            _pdfInfoCell('Tanggal',
                _formatDate(DateTime.tryParse(rideInfo['start_time'] ?? '') ?? DateTime.now())),
            _pdfInfoCell('Durasi',
                _formatDuration(rideInfo['start_time'], rideInfo['end_time'])),
            _pdfInfoCell('Jarak',
                '${((rideInfo['distance'] ?? 0.0) as num).toStringAsFixed(2)} km'),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _pdfInfoCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMetricsSection(Map<String, dynamic> metrics) {
    final cells = <(String, String, PdfColor)>[
      ('TP', '${metrics['tp']}', PdfColors.green800),
      ('FP', '${metrics['fp']}', PdfColors.red800),
      ('TN', '${metrics['tn']}', PdfColors.blue800),
      ('FN', '${metrics['fn']}', PdfColors.orange800),
      ('Precision', _pct(metrics['precision_val']), PdfColors.purple800),
      ('Recall', _pct(metrics['recall_val']), PdfColors.teal800),
      ('F1 Score', _pct(metrics['f1_score']), PdfColors.indigo800),
      ('Accuracy', _pct(metrics['accuracy']), PdfColors.cyan800),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Metrik Evaluasi',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cells.map((c) => _pdfMetricCard(c.$1, c.$2, c.$3)).toList(),
        ),
      ],
    );
  }

  pw.Widget _pdfMetricCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 80,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfEventTable(List<ResearchEventModel> events) {
    const headers = [
      'No',
      'Waktu (s)',
      'Event',
      'Klasifikasi',
      'Latency (ms)',
      'Catatan',
    ];

    final rows = events.asMap().entries.map((e) {
      final ev = e.value;
      return [
        '${e.key + 1}',
        (ev.videoTimestampMs / 1000.0).toStringAsFixed(2),
        ev.eventType.label,
        ev.classifiedAs.label,
        ev.alarmLatencyMs?.toString() ?? '-',
        ev.note ?? '-',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detail Event Log (${events.length} events)',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FixedColumnWidth(48),
            2: const pw.FixedColumnWidth(90),
            3: const pw.FixedColumnWidth(65),
            4: const pw.FixedColumnWidth(60),
            5: const pw.FlexColumnWidth(),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: headers
                  .map(
                    (h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  )
                  .toList(),
            ),
            // Data rows
            ...rows.map(
              (row) => pw.TableRow(
                children: row
                    .map(
                      (cell) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        child: pw.Text(cell,
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'EYE-ON! SafeDrive Research Tool — Digenerate ${_formatDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          'Halaman ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM yyyy HH:mm', 'id').format(dt.toLocal());

  String _formatDuration(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return '-';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final diff = end.difference(start);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return '-';
    }
  }

  String _pct(dynamic val) {
    if (val == null) return '0.00%';
    return '${((val as num) * 100).toStringAsFixed(2)}%';
  }

  String _fileTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }

  Future<void> _shareAsFile({
    required String content,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: subject,
    );
  }

  Future<void> _shareAsFileBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: subject,
    );
  }
}
