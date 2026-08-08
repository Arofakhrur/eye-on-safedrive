import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import 'package:eyeon/research/pipeline_verification/models/pipeline_result_model.dart';
import 'package:eyeon/research/pipeline_verification/services/face_detector_service.dart';
import 'package:eyeon/research/pipeline_verification/services/ear_calculator.dart';

/// Progress snapshot emitted by [PipelineTestService] during verification.
class PipelineProgress {
  final int total;
  final int processed;
  final int successful;
  final int failedFace;
  final int failedLandmark;
  final String? currentFile;

  const PipelineProgress({
    required this.total,
    required this.processed,
    required this.successful,
    required this.failedFace,
    required this.failedLandmark,
    this.currentFile,
  });

  double get percentage => total == 0 ? 0.0 : processed / total;
  bool get isDone => processed >= total;
}

/// Orchestrates the full DDD pipeline verification process:
///
/// 1. Scans a root folder recursively for JPEG/PNG images.
/// 2. Parses subject + label from directory structure:
///    `<root>/<label>/<subject>/<image>` → label=drowsy|non_drowsy, subject=person_01
/// 3. Processes each image through ML Kit Face Mesh + EAR calculation.
/// 4. Computes per-subject baseline (max EAR) and relative EAR.
/// 5. Exports results as CSV via share_plus.
class PipelineTestService extends ChangeNotifier {
  final _progressController = StreamController<PipelineProgress>.broadcast();

  /// Stream of progress updates emitted during [runVerification].
  Stream<PipelineProgress> get progressStream => _progressController.stream;

  List<PipelineResultModel> _results = [];
  bool _isRunning = false;
  bool _isCancelled = false;
  String? _errorMessage;

  List<PipelineResultModel> get results => List.unmodifiable(_results);
  bool get isRunning => _isRunning;
  bool get isCancelled => _isCancelled;
  String? get errorMessage => _errorMessage;

  // ── Step 1: Scan folder ──────────────────────────────────────────────────

  /// Scans [rootPath] recursively and returns all image file paths.
  ///
  /// Expected folder structure (Driver Drowsiness Dataset):
  /// ```
  /// Driver Drowsiness Dataset (DDD)/
  ///   Drowsy/
  ///     Person1/ ... Person28/
  ///       A0001.png
  ///   Non Drowsy/
  ///     Person1/ ... Person27/
  ///       A0001.png
  /// ```
  Future<List<String>> scanImageFiles(String rootPath) async {
    final dir = Directory(rootPath);
    final exists = await dir.exists();
    debugPrint('🔍 scanImageFiles → root: $rootPath');
    debugPrint('🔍 Directory exists: $exists');

    if (!exists) return [];

    final files = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png'].contains(ext)) {
          files.add(entity.path);
        }
      }
    }
    files.sort(); // Consistent ordering
    debugPrint('🔍 Total images found: ${files.length}');
    if (files.isNotEmpty) {
      debugPrint('🔍 First file: ${files.first}');
      debugPrint('🔍 Last file:  ${files.last}');
    }
    return files;
  }

  /// Parses the label and subject from a file path relative to [rootPath].
  ///
  /// Handles real DDD folder naming:
  ///   - `Drowsy`       → label `drowsy`
  ///   - `Non Drowsy`   → label `non_drowsy`
  ///
  /// Subject is lowercased for consistent grouping (e.g. `Person1` → `person1`).
  Map<String, String> parsePathComponents(String filePath, String rootPath) {
    // Normalize separators
    final normalized = filePath.replaceAll('\\', '/');
    final rootNorm = rootPath.replaceAll('\\', '/');

    // Strip root prefix
    String relative = normalized;
    if (relative.startsWith(rootNorm)) {
      relative = relative.substring(rootNorm.length);
    }

    // Remove leading slash
    if (relative.startsWith('/')) relative = relative.substring(1);

    // Split: [label, subject, filename, ...]
    final parts = relative.split('/');

    // Normalize label: case-insensitive, handle 'Non Drowsy' with space
    String rawLabel = parts.isNotEmpty ? parts[0] : 'unknown';
    String label;
    final labelLower = rawLabel.toLowerCase().replaceAll(' ', '_');
    if (labelLower.contains('non')) {
      label = 'non_drowsy';
    } else if (labelLower.contains('drowsy')) {
      label = 'drowsy';
    } else {
      label = labelLower; // keep as-is for unexpected folder names
    }

    final subject = parts.length >= 2 ? parts[1].toLowerCase() : 'unknown';

    return {'label': label, 'subject': subject};
  }

  // ── Step 2: Run verification ─────────────────────────────────────────────

  /// Runs the full verification pipeline on all images found in [rootPath].
  ///
  /// Emits [PipelineProgress] updates via [progressStream].
  /// After completion, results are available via [results].
  Future<void> runVerification(String rootPath) async {
    if (_isRunning) return;

    _isRunning = true;
    _results = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final files = await scanImageFiles(rootPath);

      if (files.isEmpty) {
        _errorMessage =
            'Tidak ada file gambar ditemukan di folder ini.\n'
            'Pastikan struktur folder:\n'
            'DDD/Drowsy/Person1/*.png\n'
            'DDD/Non Drowsy/Person1/*.png';
        _isRunning = false;
        notifyListeners();
        return;
      }

      int processed = 0;
      int successful = 0;
      int failedFace = 0;
      int failedLandmark = 0;
      final total = files.length;

      for (final filePath in files) {
        final components = parsePathComponents(filePath, rootPath);
        final label = components['label']!;
        final subject = components['subject']!;
        final imageName = filePath.split('/').last.split('\\').last;

        // Emit progress before processing this file
        _progressController.add(
          PipelineProgress(
            total: total,
            processed: processed,
            successful: successful,
            failedFace: failedFace,
            failedLandmark: failedLandmark,
            currentFile: imageName,
          ),
        );

        PipelineResultModel result;

        try {
          // Run ML Kit face mesh detection
          final detection = await FaceDetectorService.instance.processFile(
            filePath,
          );

          if (detection == null) {
            // Face not detected
            failedFace++;
            result = PipelineResultModel(
              subject: subject,
              label: label,
              imageName: imageName,
              imagePath: filePath,
              ear: 0.0,
              baseline: 0.0,
              relativeEar: 0.0,
              faceDetected: false,
              landmarkFound: false,
              errorNote: 'face_not_detected',
            );
          } else {
            // Face detected — compute EAR
            final avgEar = EarCalculator.calculateAvgEar(detection.points);

            if (avgEar == null) {
              // Landmarks found but EAR calculation returned null
              failedLandmark++;
              result = PipelineResultModel(
                subject: subject,
                label: label,
                imageName: imageName,
                imagePath: filePath,
                ear: 0.0,
                baseline: 0.0,
                relativeEar: 0.0,
                faceDetected: true,
                landmarkFound: false,
                errorNote: 'landmark_ear_invalid',
              );
            } else {
              successful++;
              result = PipelineResultModel(
                subject: subject,
                label: label,
                imageName: imageName,
                imagePath: filePath,
                ear: avgEar,
                baseline: 0.0, // Will be filled in post-processing
                relativeEar: 0.0,
                faceDetected: true,
                landmarkFound: true,
              );
            }
          }
        } catch (e) {
          failedFace++;
          result = PipelineResultModel(
            subject: subject,
            label: label,
            imageName: imageName,
            imagePath: filePath,
            ear: 0.0,
            baseline: 0.0,
            relativeEar: 0.0,
            faceDetected: false,
            landmarkFound: false,
            errorNote: 'exception: $e',
          );
        }

        _results.add(result);
        processed++;

        // Small yield to keep UI responsive
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // ── Post-process: compute baselines and relative EAR ──────────────
      _results = _computeBaselines(_results);

      // Emit final completed progress
      _progressController.add(
        PipelineProgress(
          total: total,
          processed: total,
          successful: successful,
          failedFace: failedFace,
          failedLandmark: failedLandmark,
        ),
      );

      debugPrint(
        '✅ [PipelineTestService] Done: $total images | '
        '$successful ok | $failedFace no-face | $failedLandmark no-landmark',
      );
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      debugPrint('🔴 [PipelineTestService] Fatal error: $e');
    } finally {
      _isRunning = false;
      FaceDetectorService.instance.dispose();
      notifyListeners();
    }
  }

  /// Signals the verification loop to stop after the current image.
  /// Results collected so far are preserved for export.
  void cancelVerification() {
    if (_isRunning) {
      _isCancelled = true;
      debugPrint('🛑 [PipelineTestService] Cancel requested');
    }
  }

  // ── Step 3: Compute baselines ────────────────────────────────────────────

  /// For each unique subject+label group, find the maximum EAR (open-eye baseline),
  /// then compute relative EAR = ear / baseline for each result in that group.
  List<PipelineResultModel> _computeBaselines(List<PipelineResultModel> raw) {
    // Build baseline map: groupKey → max EAR of successful detections
    final Map<String, double> baselines = {};
    for (final r in raw) {
      if (r.faceDetected && r.landmarkFound && r.ear > 0) {
        final current = baselines[r.groupKey] ?? 0.0;
        if (r.ear > current) baselines[r.groupKey] = r.ear;
      }
    }

    // Apply baselines
    return raw.map((r) {
      final baseline = baselines[r.groupKey] ?? 0.0;
      return r.withBaseline(baseline);
    }).toList();
  }

  // ── Step 4: Export CSV ───────────────────────────────────────────────────

  /// Writes all results to a CSV file in the temp directory and shares it.
  ///
  /// File is named `eyeon_pipeline_verification_<timestamp>.csv`.
  Future<void> exportCsv() async {
    if (_results.isEmpty) return;

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-')
          .substring(0, 19);
      final file = File(
        p.join(dir.path, 'eyeon_pipeline_verification_$timestamp.csv'),
      );

      final buffer = StringBuffer();
      buffer.writeln(PipelineResultModel.csvHeader);
      for (final r in _results) {
        buffer.writeln(r.toCsvRow());
      }

      await file.writeAsString(buffer.toString());

      debugPrint('📤 [PipelineTestService] Exporting CSV: ${file.path}');

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'EYE-ON Pipeline Verification Results',
        text:
            'EAR pipeline verification — ${_results.length} images processed.',
      );
    } catch (e) {
      debugPrint('🔴 [PipelineTestService] CSV export error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
}
